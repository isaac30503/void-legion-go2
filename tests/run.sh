#!/bin/bash
# tests/run.sh — automated tests of the pieces that can run anywhere (no root, no network, no Void):
# render.sh, the parsing and display helpers of void-update and the translation helper t.
# Run by GitHub Actions (.github/workflows/ci.yml) and by hand: bash tests/run.sh   (exit 1 if a test fails)
# shellcheck disable=SC2034,SC2154  # void-update's configuration and colors: set and read by its libraries (base.sh)
set -uo pipefail
# The scripts refuse root on purpose (need_user): as root half of these would fail for that reason, not for a bug
[ "$(id -u)" = 0 ] && { echo "tests/run.sh: run it as your normal user, not as root" >&2; exit 2; }
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
    # a MAC also as @NAME_UNDERSCORED@ (PipeWire's Bluetooth outputs), in render.sh and in common.sh's render
    check "render: MAC with underscores" yes \
        "$(grep -qF 'bluez_output.02_00_00_00_00_20.1' "$W/build/legion/wireplumber/51-audio-priority.conf" && echo yes)"
    check "render: MAC with colons kept" yes \
        "$(grep -qF 'bluez_input.02:00:00:00:00:20"' "$W/build/legion/wireplumber/51-audio-priority.conf" && echo yes)"
    printf 'a=@HEADPHONES_BT_MAC_UNDERSCORED@ b=@HEADPHONES_BT_MAC@\n' > "$TMP/tpl"
    HOME=$H bash -c 'R=$1; . "$R/lib/common.sh"; render "$2" "$3"' _ "$W" "$TMP/tpl" "$TMP/out" >/dev/null 2>&1
    check "common.sh render: both MAC forms" "a=02_00_00_00_00_20 b=02:00:00:00:00:20" "$(cat "$TMP/out" 2>/dev/null)"
    HOME=$H bash "$W/install/render.sh" --check >/dev/null 2>&1; check "render --check: complete" 0 $?
    sed -i '/^WIFI_SSID=/d' "$W/local.env"
    HOME=$H bash "$W/install/render.sh" --check >/dev/null 2>&1; check "render --check: a value missing" 1 $?
    # as root (a user namespace) with a TARGET_USER that does not exist: a message, not a silent exit
    if unshare -r true 2>/dev/null; then
        out=$(LANGUAGE=C HOME=$H unshare -r bash "$W/install/render.sh" 2>&1); check "render as root, unknown user: exit" 1 $?
        check "render as root, unknown user: message" "!! The user me does not exist (TARGET_USER in $W/local.env)." "$out"
    else
        echo "   (skipped: no user namespaces here) render as root, unknown user"
    fi
}

# ---- install/catalog.py: a new message without translation and an entry nobody uses are both caught -----------
test_catalog() {
    local W=$TMP/catalog out
    mkdir -p "$W"
    (cd "$REPO" && git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf -) | tar -xf - -C "$W"
    (cd "$W" && git init -q && git add -A) >/dev/null 2>&1
    python3 "$W/install/catalog.py" check >/dev/null 2>&1; check "catalog: in step" 0 $?
    printf '\nt "a brand new message %%s" x\n' >> "$W/common/steam/install-steam.sh"
    printf '\nmsgid "nobody says this"\nmsgstr "nadie dice esto"\n' >> "$W/locale/es/messages.po"
    (cd "$W" && git add -A)
    out=$(python3 "$W/install/catalog.py" check 2>&1); check "catalog: out of step" 1 $?
    check "catalog: the new message" yes "$(grep -q 'no translation: a brand new message %s' <<< "$out" && echo yes)"
    check "catalog: the unused entry" yes "$(grep -q 'unused entry: nobody says this' <<< "$out" && echo yes)"
}

# ---- void-update ------------------------------------------------------------------------------------------
test_void_update() (
    pass=0; failed=0   # a subshell: it counts its own and reports them through a file
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

# ---- systemd-compat: answers and exit codes of systemd, runit through a fake sv, real session units ----------
test_systemd_compat() {
    local S=$TMP/sc C=$REPO/common/systemd-compat out t0 tok1 tok2 pid s
    mkdir -p "$S/etc/units.d" "$S/sv" "$S/service" "$S/run" "$S/xdg" "$S/log/decky"; chmod 700 "$S/xdg"
    cat > "$S/etc/units.d/50-test.conf" <<EOF
plugin_loader  system  runit  decky  log=$S/log/decky/current
hhd@*          system  deny
filter-chain   user    exec   sleep 300
EOF
    for s in decky inputplumber steamos-manager; do mkdir -p "$S/sv/$s"; printf '#!/bin/sh\nexec sleep 1\n' > "$S/sv/$s/run"; chmod +x "$S/sv/$s/run"; done
    for s in decky inputplumber; do mkdir -p "$S/service/$s/supervise"; echo run > "$S/service/$s/supervise/stat"; echo 1 > "$S/service/$s/supervise/pid"; done
    printf '#!/bin/sh\necho "sv $*" >> %s/sv-calls\n' "$S" > "$S/sv-fake"; chmod +x "$S/sv-fake"
    printf '2001-01-01_00:00:00.00001 before this boot\n%s Decky Started\n' "$(date -u +%Y-%m-%d_%H:%M:%S.00001)" > "$S/log/decky/current"
    sc() { c=$1; shift; env SYSTEMD_COMPAT_LIB="$C" SYSTEMD_COMPAT_ETC="$S/etc" SYSTEMD_COMPAT_SV_DIR="$S/sv" SYSTEMD_COMPAT_SERVICE_DIR="$S/service" \
              SYSTEMD_COMPAT_RUN="$S/run" SYSTEMD_COMPAT_SV="$S/sv-fake" XDG_RUNTIME_DIR="$S/xdg" sh "$C/$c" "$@"; }

    # system units: a runit service by its name, an alias of units.d, deny, a unit that does not exist
    out=$(sc systemctl is-active inputplumber.service); check "sc: runit service by name" "active 0" "$out $?"
    out=$(sc systemctl is-active plugin_loader); check "sc: alias of units.d (plugin_loader → decky)" "active 0" "$out $?"
    out=$(sc systemctl is-active steamos-manager); check "sc: service not linked in /var/service" "inactive 3" "$out $?"
    out=$(sc systemctl is-active hhd@0.service); check "sc: deny" "inactive 3" "$out $?"
    out=$(sc systemctl is-active 'hhd@*.service'); check "sc: pattern of deny" "inactive 3" "$out $?"
    out=$(sc systemctl is-active 'foo@*.service'); check "sc: pattern without matches" "inactive 3" "$out $?"
    out=$(sc systemctl start nope 2>&1); check "sc: start of a unit not found (systemd's text, exit 5)" "Failed to start nope.service: Unit nope.service not found. 5" "$out $?"
    out=$(sc systemctl show nope -p LoadState --value); check "sc: show of a unit not found" "not-found" "$out"
    out=$(sc systemctl restart plugin_loader 2>&1); check "sc: control without root" "Failed to restart plugin_loader.service: Interactive authentication required. 4" "$out $?"
    out=$(sc systemctl list-units --type=service --state=active --no-legend --plain | awk '{print $1}' | sort | paste -sd' ')
    check "sc: list-units with the alias" "inputplumber.service plugin_loader.service" "$out"
    out=$(sc systemctl is-system-running); check "sc: is-system-running (not booted with systemd)" "offline 1" "$out $?"
    sc systemctl --user list-jobs >/dev/null 2>&1; check "sc: --user list-jobs fails (Xfce's xinitrc)" 1 $?
    sc systemctl daemon-reload; check "sc: daemon-reload" 0 $?
    check "sc: requests.log has the unit not found" yes "$(grep -q $'\tnot-found\tstart nope\t' "$S/xdg/systemd-compat/requests.log" && echo yes)"
    check "sc: the session probe is not logged" "" "$(grep 'list-jobs' "$S/xdg/systemd-compat/requests.log")"
    check "sc: a unit of deny is not logged (name and pattern)" "" "$(grep 'hhd' "$S/xdg/systemd-compat/requests.log")"

    # as root (a user namespace): sv is called, and detached when the caller runs inside the service
    if unshare -r true 2>/dev/null; then
        : > "$S/sv-calls"
        unshare -r sh -c "$(declare -f sc); C='$C'; S='$S'; sc systemctl restart plugin_loader" >/dev/null 2>&1
        check "sc: restart as root calls sv" "sv restart $S/service/decky" "$(cat "$S/sv-calls")"
        : > "$S/sv-calls"
        out=$(unshare -r sh -c "echo \$\$ > '$S/service/decky/supervise/pid'; $(declare -f sc); C='$C'; S='$S'; sc systemctl restart plugin_loader; echo \$?; true")
        for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$S/sv-calls" ] && break; sleep 0.1; done
        check "sc: restart from inside the service: detached, returns at once" "0|sv restart $S/service/decky" "$out|$(cat "$S/sv-calls")"
    else
        echo "   (skipped: no user namespaces here) systemd-compat as root"
    fi

    # a user exec unit (Panel de Control's equalizer): the token it compares before and after restarting
    tok1=$(sc systemctl --user show filter-chain.service --property=InvocationID --property=MainPID --value | paste -sd' ')
    check "sc: exec unit not started: empty invocation, MainPID 0" " 0" "$tok1"
    sc systemctl --user restart filter-chain.service; check "sc: restart of an exec unit" 0 $?
    out=$(sc systemctl --user is-active filter-chain.service); check "sc: exec unit active" active "$out"
    tok1=$(sc systemctl --user show filter-chain.service --property=InvocationID --property=MainPID --value | paste -sd' ')
    sc systemctl --user restart filter-chain.service
    tok2=$(sc systemctl --user show filter-chain.service --property=InvocationID --property=MainPID --value | paste -sd' ')
    check "sc: the token changes on restart" yes "$([ -n "${tok1% *}" ] && [ "$tok1" != "$tok2" ] && echo yes)"
    pid=${tok2#* }
    sc systemctl --user stop filter-chain.service
    out=$(sc systemctl --user is-active filter-chain.service); check "sc: stopped exec unit" inactive "$out"
    # gone, or a zombie waiting for a parent that does not reap (some containers): not running either way
    s=$(cat "/proc/$pid/stat" 2>/dev/null); s=${s##*) }; s=${s%% *}   # after "(comm)", which may have spaces
    check "sc: its process is gone" gone "$(case ${s:-Z} in Z|X) echo gone ;; *) echo "alive ($s)" ;; esac)"

    # a transient unit (the kiosk): nice, --setenv kept out of the log, its output through journalctl --since
    t0=$(date +%s)
    sc systemd-run --user --unit=kiosk --collect --quiet --nice=10 --property=CPUWeight=20 --setenv=URL=secret \
        sh -c 'echo "url=$URL nice=$(cut -d" " -f19 /proc/self/stat)"; exec sleep 300'
    check "sc: systemd-run" 0 $?
    sleep 0.3
    out=$(sc systemctl --user is-active kiosk); check "sc: transient unit active" active "$out"
    out=$(sc journalctl --user _SYSTEMD_USER_UNIT=kiosk.service --since=@"$t0" --lines=2 --output=cat --no-pager)
    check "sc: its output (environment and nice applied)" "url=secret nice=10" "$out"
    check "sc: the value of --setenv is hidden in requests.log" "" "$(grep -F secret "$S/xdg/systemd-compat/requests.log")"
    sc systemctl --user stop --no-block kiosk; sleep 0.3
    out=$(sc systemctl --user is-active kiosk); check "sc: transient unit stopped" inactive "$out"
    out=$(echo hi | sc systemd-run --user --pipe --quiet sh -c 'read x; echo "got $x"'); check "sc: systemd-run --pipe" "got hi" "$out"

    # journalctl: the svlogd log of a runit service, this boot only, smart-case grep, a boot that is not kept
    out=$(sc journalctl -b -u plugin_loader -o cat --no-pager); check "sc: journalctl -b -u (svlogd)" "Decky Started" "$out"
    out=$(sc journalctl -u plugin_loader -o cat | head -1); check "sc: journalctl without -b: older lines too" "before this boot" "$out"
    out=$(sc journalctl -u plugin_loader -o cat --grep 'decky'); check "sc: --grep lowercase = case-insensitive" "Decky Started" "$out"
    out=$(sc journalctl -u plugin_loader -o cat --grep 'DECKY'); check "sc: --grep with a capital = case-sensitive" "-- No entries --" "$out"
    sc journalctl -b -1 -k >/dev/null 2>&1; check "sc: journalctl -b -1 (previous boots are not kept)" 1 $?
}

# ---- install/pieces.py: a file without piece and an installer missing from the reinstall are both caught ----------
test_pieces() {
    local W=$TMP/pieces out
    mkdir -p "$W"
    (cd "$REPO" && git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf -) | tar -xf - -C "$W"
    (cd "$W" && git init -q && git add -A) >/dev/null 2>&1
    python3 -I "$W/install/pieces.py" >/dev/null; check "pieces: the clone is in order" 0 $?
    echo 'echo hi' > "$W/common/stray.sh"; (cd "$W" && git add common/stray.sh)
    out=$(python3 -I "$W/install/pieces.py"); check "pieces: a file without piece" "common/stray.sh: belongs to no piece of install/pieces.tsv" "$out"
    rm "$W/common/stray.sh"; (cd "$W" && git rm -q --cached common/stray.sh)
    printf 'dup\tL\t15\troot\tlegion/udev-net.sh\tdocs/reinstall.md\tlegion/udev-net.sh\t/x\t--remove\n' >> "$W/install/pieces.tsv"
    out=$(python3 -I "$W/install/pieces.py"); check "pieces: a file with two owners" yes "$(grep -q 'legion/udev-net.sh: belongs to several pieces (dup, udev-net)' <<< "$out" && echo yes)"
    sed -i '$d' "$W/install/pieces.tsv"
    sed -i 's#^\(grub-hidden\t\([^\t]*\t\)\{6\}\)[^\t]*#\1-#' "$W/install/pieces.tsv"
    out=$(python3 -I "$W/install/pieces.py"); check "pieces: an installed piece without installs" yes "$(grep -q '(grub-hidden): an installed piece says what proves it is there' <<< "$out" && echo yes)"
    git -C "$W" checkout -q -- install/pieces.tsv
    sed -i '/install-systemd-compat.sh/d' "$W/install/install.sh"
    out=$(python3 -I "$W/install/pieces.py"); check "pieces: an installer missing from install.sh" yes "$(grep -q 'install-systemd-compat.sh is not in install/install.sh' <<< "$out" && echo yes)"
}

test_render
test_pieces
test_catalog
test_void_update
read -r p f < "$TMP/vu-result"; pass=$((pass + p)); failed=$((failed + f))
test_systemd_compat
test_i18n
printf '%s passed, %s failed\n' "$pass" "$failed"
[ "$failed" = 0 ]
