#!/bin/bash
# tests/run.sh — automated tests of the pieces that can run anywhere (no root, no network, no Void):
# render.sh, the parsing and display helpers of void-update and the translation helper t.
# Run by GitHub Actions (.github/workflows/ci.yml) and by hand: bash tests/run.sh   (exit 1 if a test fails)
# shellcheck disable=SC2034,SC2154  # void-update's configuration and colors: set and read by its libraries (base.sh)
set -uo pipefail
REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; failed=0
check() {   # check NAME EXPECTED ACTUAL
    if [ "$2" = "$3" ]; then pass=$((pass + 1))
    else failed=$((failed + 1)); printf '!! FAIL %s\n   expected: %q\n   got:      %q\n' "$1" "$2" "$3"; fi
}

# ---- render.sh: a copy of the tracked files with local.env = local.env.example ---------------------------
test_render() {
    local W=$TMP/clone H=$TMP/home f known left
    mkdir -p "$W" "$H"
    (cd "$REPO" && git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf -) | tar -xf - -C "$W"
    cp "$W/local.env.example" "$W/local.env"
    HOME=$H bash "$W/install/render.sh" >/dev/null 2>&1; check "render: exit" 0 $?
    check "render: build/ exists" yes "$([ -d "$W/build" ] && echo yes)"
    # no known placeholder is left in a text file of build/
    known=$(sed -nE 's/^\s*#?\s*([A-Z0-9_]+)=.*/\1/p' "$W/local.env.example" | paste -sd'|')
    left=$(grep -rIlE "@($known|TARGET_HOME|TARGET_USER)@" "$W/build" | grep -v '/build/local.env' | head -3)
    check "render: no placeholder left" "" "$left"
    # a file with @WIFI_SSID@ gets the value; @TARGET_HOME@ gets $HOME; executables stay executable
    f=$(cd "$W" && grep -rlF '@WIFI_SSID@' --exclude-dir=build --exclude=local.env.example . | grep -v '^./docs/' | head -1)
    check "render: WIFI_SSID filled ($f)" yes "$(grep -qF MyHomeWiFi "$W/build/$f" && echo yes)"
    f=$(cd "$W" && grep -rlF '@TARGET_HOME@' --exclude-dir=build common legion | head -1)
    check "render: TARGET_HOME filled ($f)" yes "$(grep -qF "$H" "$W/build/$f" && echo yes)"
    check "render: mode kept" yes "$([ -x "$W/build/install/install.sh" ] && echo yes)"
    HOME=$H bash "$W/install/render.sh" --check >/dev/null 2>&1; check "render --check: complete" 0 $?
    sed -i '/^WIFI_SSID=/d' "$W/local.env"
    HOME=$H bash "$W/install/render.sh" --check >/dev/null 2>&1; check "render --check: a value missing" 1 $?
}

# ---- void-update ------------------------------------------------------------------------------------------
test_void_update() (
    export XDG_STATE_HOME=$TMP/state XDG_CONFIG_HOME=$TMP/config XDG_RUNTIME_DIR=$TMP
    mkdir -p "$XDG_CONFIG_HOME/void-update"
    cat > "$XDG_CONFIG_HOME/void-update/void-update.conf" <<'CONF'
# comment
check_timeout = 30   # seconds
news="false"
tray_icon_style=purple
notifications=$(touch "$XDG_RUNTIME_DIR/PWNED")
unknown_key=1
check_interval_hours=abc
CONF
    t() { local f=$1; shift; printf "$f\n" "$@"; }   # messages untranslated
    L=$REPO/common/void-update/lib
    . "$L/base.sh"; . "$L/check.sh"; . "$L/list.sh"
    check "config: number with spaces and comment" 30 "$check_timeout"
    check "config: quoted boolean" false "$news"
    check "config: invalid value ignored" light "$tray_icon_style"
    check "config: invalid number ignored" 6 "$check_interval_hours"
    check "config: never run as code" "true no" "$notifications $([ -e "$TMP/PWNED" ] && echo yes || echo no)"
    check "pkgname" "xdg-desktop-portal-wlr" "$(echo xdg-desktop-portal-wlr-0.8.0_2 | vu_pkgname)"
    xbps-query() { printf 'ii %s desc\n' foo-1.2.10_1 xdg-desktop-portal-wlr-0.7.1_1 linux6.18-6.18.55_1; }
    printf '%s\n' 'foo-1.2.11_1 update x86_64 https://repo 100 50' \
        'xdg-desktop-portal-wlr-0.8.0_2 update x86_64 https://repo 100 50' 'newpkg-0.1_1 install x86_64 https://repo 1 1' > "$TMP/raw"
    vu_write_pending "$TMP/raw"
    check "pending list" "foo 1.2.10_1 -> 1.2.11_1
xdg-desktop-portal-wlr 0.7.1_1 -> 0.8.0_2
newpkg (new) -> 0.1_1" "$(cat "$VU_STATE/packages")"
    check "raw output kept" yes "$([ -s "$VU_STATE/xbps-raw" ] && [ ! -e "$TMP/raw" ] && echo yes)"
    check "count" 3 "$(vu_count "$VU_STATE/packages")"
    check "count of an empty file" 0 "$(: > "$TMP/empty"; vu_count "$TMP/empty")"
    check "versions without colors" "foo 1.2.10_1 -> 1.2.11_1" "$(echo 'foo 1.2.10_1 -> 1.2.11_1' | vu_color_versions)"
    c_bold='<b>'; c_red='<r>'; c_green='<g>'; c_off='</>'
    check "versions: whole changed part colored" "<b>foo</> 1.2.<r><b>10_1</> -> 1.2.<g><b>11_1</>" \
        "$(echo 'foo 1.2.10_1 -> 1.2.11_1' | vu_color_versions)"
    check "versions: only the revision" "<b>bar</> 2.0_<r><b>1</> -> 2.0_<g><b>2</>" "$(echo 'bar 2.0_1 -> 2.0_2' | vu_color_versions)"
    check "versions: new package" "newpkg (new) -> 0.1_1" "$(echo 'newpkg (new) -> 0.1_1' | vu_color_versions)"
    echo "$pass $failed" > "$TMP/vu-result"
)

# ---- t: translation through the catalog -------------------------------------------------------------------
test_i18n() {
    local id str
    # the first msgid without format directives or escapes, and its translation
    read -r id str < <(python3 -I - "$REPO/locale/es/messages.po" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
for i, t in re.findall(r'^msgid "(.*)"\nmsgstr "(.*)"$', s, re.M):
    if i and t and "%" not in i and "\\" not in i + t and "\t" not in i + t:
        print(i.replace(" ", "\x01") + " " + t.replace(" ", "\x01")); break
PY
)
    id=${id//$'\x01'/ }; str=${str//$'\x01'/ }
    run_t() { env -i HOME="$TMP" PATH="$PATH" LANGUAGE="$1" bash -c 'R=$1; . "$R/lib/common.sh"; shift 2; t "$@"' _ "$REPO" "$@"; }
    check "t: Spanish" "$str" "$(run_t es "$id")"
    check "t: English" "$id" "$(run_t C "$id")"
    check "t: unknown language falls back to English" "$id" "$(run_t xx "$id")"
    check "t: a message not in the catalog" "no such message 7" "$(run_t es 'no such message %s' 7)"
}

test_render
test_void_update
read -r p f < "$TMP/vu-result"; pass=$((pass + p)); failed=$((failed + f))
test_i18n
printf '%s passed, %s failed\n' "$pass" "$failed"
[ "$failed" = 0 ]
