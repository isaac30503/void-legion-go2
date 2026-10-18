#!/bin/bash
# patch-still-needed — is one of our own patches still needed in the new code? (2026-10-09)
#
# It tests the patches against the real code, without assuming anything from the version: it downloads the code (the
# distfile of Void's template, with its checksum verified, or a tag/branch of a git repository),
# applies to it first the patches of Void's own template (the ones the Void package carries) and then
# tests ours, in order, with git apply --check (and --reverse --check if they do not apply):
#   STILL_NEEDED      the patch applies: the new code does not bring the change (rebuild with it)
#   ALREADY_INCLUDED  the patch applies IN REVERSE: the code already brings that change (one can go back to Void's)
#   CONFLICT          neither one nor the other: upstream rewrote that part (review the patch by hand)
# With several patches, each one is tested on the code with the previous ones already applied (those that are
# needed), and the overall result is STILL_NEEDED / ALREADY_INCLUDED (all the same), PARTIAL (some included and
# others not: remove the included ones and rebuild with the rest) or CONFLICT (some in conflict).
# Without network, or if something cannot be downloaded or verified: UNCHECKED (and it exits with 0: it does not break whoever calls it).
#
# Usage (without root):
#   patch-still-needed void <package> <patch>...          current template of void-packages (master)
#   patch-still-needed git <url> <ref> <name> <patch>...  tag or branch of upstream
#   --no-cache (before the mode): do not read the cache
#   --version <version_revision> (before "void"): if the cache already has that version, it answers without network
#     (void-update passes it the one that Void's repository publishes; the template may be ahead)
# Output: one line "PATCH <file> <state>" per patch and, at the end, always one line
#   "RESULT <name> <tested version> <state> <detail>"
# The words PATCH, RESULT and the states are fixed (void-update reads them); <detail> is for a person and
# follows the system's language (lib/i18n.sh).
# Cache: ~/.cache/void-update/patches/<name>-<version>-<hash of the patches and the language>.txt (UNCHECKED
# is not saved). For Void, the version is the template's (version_revision); for git, the ref and its commit.
#
# What is downloaded is treated as data: it goes to a new, empty directory that is deleted at the end; from the
# template only variable assignments are read (pkgname, version, revision, distfiles, checksum,
# patch_args and those that start with _), and if any carries $( or ` it is not used (UNCHECKED).
# Only the FIRST distfile is tested (the program's code; gamescope also brings subprojects, which
# our own patches do not touch).
# In this repository: common/patch-test/patch-still-needed.sh; installed in ~/.local/bin/patch-still-needed by
# install-patch-test.sh (docs/8-maintenance/2-own-patches.md).
# Previous (Spanish) name: parche-sigue-haciendo-falta (states HACE_FALTA, YA_INCLUIDO, PARCIAL, CONFLICTO,
# SIN_COMPROBAR and lines PARCHE/RESULTADO; cache in ~/.cache/update-system/parches).
set -uo pipefail

# Translations: from the repository (lib/i18n.sh next to it) or from the installed copy
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/i18n.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
if [ -f "$R/lib/i18n.sh" ]; then I18N_REPO_DIR=$R; . "$R/lib/i18n.sh"
elif [ -r "$HOME/.local/share/void-legion/lib/i18n.sh" ]; then . "$HOME/.local/share/void-legion/lib/i18n.sh"
elif [ -r /usr/local/lib/void-legion/i18n.sh ]; then . /usr/local/lib/void-legion/i18n.sh
else t() { _f=$1; shift; printf -- "$_f\n" "$@"; }; fi
# tr_ FORMAT ARGS: the translated text, to put it inside a line with $(…)
tr_() { t "$@"; }

CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/void-update/patches
VP_URL=https://github.com/void-linux/void-packages.git
USE_CACHE=1; HINT=
while :; do
    case "${1:-}" in
        --no-cache) USE_CACHE=0; shift ;;
        --version)              HINT=${2:-}; shift 2 ;;
        *) break ;;
    esac
done

mode=${1:-}
case "$mode" in
    void) [ $# -ge 3 ] || mode=; NAME=${2:-}; shift 2 ;;
    git)  [ $# -ge 5 ] || mode=; URL=${2:-}; REF=${3:-}; NAME=${4:-}; shift 4 ;;
    *)    mode= ;;
esac
if [ -z "$mode" ]; then
    {   # the help of the header, through the translation catalog
        t "Usage (without root):"
        printf '  %-52s %s\n' "patch-still-needed void <package> <patch>..." "$(t "current template of void-packages (master)")"
        printf '  %-52s %s\n' "patch-still-needed git <url> <ref> <name> <patch>..." "$(t "tag or branch of upstream")"
        printf '  %-52s %s\n' "--no-cache" "$(t "(before the mode) do not read the cache")"
        printf '  %-52s %s\n' "--version <version_revision>" "$(t "(before \"void\") if the cache already has that version, it answers without network")"
        t "Output: one line \"PATCH <file> <state>\" per patch and, at the end, always one line"
        t "  \"RESULT <name> <tested version> <state> <detail>\""
    } >&2
    exit 2
fi
PATCHES=()
for p in "$@"; do
    [ -f "$p" ] || { echo "RESULT $NAME ? UNCHECKED $(tr_ "the patch %s does not exist" "$p")"; exit 0; }
    PATCHES+=("$(readlink -f "$p")")
done

T=$(mktemp -d "${TMPDIR:-/tmp}/patch-test.XXXXXX") || exit 1
trap 'rm -rf "${T:?}"' EXIT
unchecked() { echo "RESULT $NAME ${VERSION:-?} UNCHECKED $*"; exit 0; }

# "test-2": changes if the way of testing changes; the language, because the cache keeps the <detail> text
HASH=$( { echo test-2; _i18n_lang 2>/dev/null; cat "${PATCHES[@]}"; } | sha256sum | cut -c1-12)
look_cache() {
    F="$CACHE/$NAME-${1//\//_}-$HASH.txt"
    if [ "$USE_CACHE" = 1 ] && [ -s "$F" ]; then
        sed "/^RESULT /s/\$/ ($(tr_ "cache"))/" "$F"
        exit 0
    fi
}

# ---- get the code --------------------------------------------------------------------------------
[ "$mode" = void ] && [ -n "$HINT" ] && look_cache "$HINT"
mkdir "$T/code"
if [ "$mode" = void ]; then
    { git clone -q --depth 1 --filter=blob:none --sparse "$VP_URL" "$T/vp" 2>/dev/null \
        && git -C "$T/vp" sparse-checkout set "srcpkgs/$NAME" 2>/dev/null; } \
        || unchecked "$(tr_ "without network or without access to void-packages")"
    PL="$T/vp/srcpkgs/$NAME/template"
    [ -f "$PL" ] || unchecked "$(tr_ "void-packages has no srcpkgs/%s/template" "$NAME")"
    # Top-level assignments (they can take several lines between quotes), only the ones of interest
    ASSIGN=$(python3 -I - "$PL" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().split("\n")
want = re.compile(r'^(pkgname|version|revision|distfiles|checksum|patch_args|_[A-Za-z0-9_]*)=')
out, i = [], 0
while i < len(lines):
    m = want.match(lines[i])
    if not m:
        i += 1; continue
    stmt = lines[i]
    while (stmt.count('"') - stmt.count('\\"')) % 2 == 1 and i + 1 < len(lines):
        i += 1; stmt += "\n" + lines[i]
    out.append(stmt); i += 1
text = "\n".join(out)
if "$(" in text or "`" in text:
    sys.exit(3)
print(text)
PY
) || unchecked "$(tr_ "the template of %s cannot be read without running code" "$NAME")"
    mapfile -t V < <(env -i bash --noprofile --norc -c "$ASSIGN"'
        set -f; d=($distfiles); c=($checksum)
        printf "%s\n" "$version" "$revision" "${d[0]%%>*}" "${c[0]}" "${patch_args:--Np1}"')
    VERSION="${V[0]:-}_${V[1]:-}"; DIST=${V[2]:-}; SUM=${V[3]:-}; PARGS=${V[4]:-}
    [ -n "${V[0]:-}" ] && [ -n "$DIST" ] && [ -n "$SUM" ] || unchecked "$(tr_ "template without version/distfiles/checksum")"
    look_cache "$VERSION"
    mkdir "$T/dist"
    ARCH="$T/dist/${DIST##*/}"
    curl -fsSL --max-time 600 -o "$ARCH" "$DIST" 2>/dev/null || unchecked "$(tr_ "%s could not be downloaded" "$DIST")"
    [ "$(sha256sum "$ARCH" | cut -d' ' -f1)" = "$SUM" ] || unchecked "$(tr_ "the checksum of %s does not match the template" "$DIST")"
    tar -xf "$ARCH" -C "$T/code" 2>/dev/null || unchecked "$(tr_ "%s could not be unpacked" "${DIST##*/}")"
    mapfile -t DIRS < <(find "$T/code" -mindepth 1 -maxdepth 1)
    if [ ${#DIRS[@]} = 1 ] && [ -d "${DIRS[0]}" ]; then SRC=${DIRS[0]}; else SRC=$T/code; fi
    # The patches that Void's package already carries, in the order in which xbps-src applies them
    PLEVEL=$(grep -o -- '-p[0-9]' <<<"$PARGS" | head -1); PLEVEL=${PLEVEL:--p1}
    if [ -d "$T/vp/srcpkgs/$NAME/patches" ]; then
        for vp in $(find "$T/vp/srcpkgs/$NAME/patches" -maxdepth 1 -type f \( -name '*.patch' -o -name '*.diff' \) | sort); do
            ( cd "$SRC" && git apply "$PLEVEL" "$vp" 2>/dev/null ) \
                || ( cd "$SRC" && git apply -C1 "$PLEVEL" "$vp" 2>/dev/null ) \
                || unchecked "$(tr_ "the patch of Void's template %s does not apply" "${vp##*/}")"
        done
    fi
else
    LINE=$(git ls-remote "$URL" "$REF" "refs/tags/$REF^{}" 2>/dev/null | sort -k2 | tail -1) \
        || unchecked "$(tr_ "without network or without access to %s" "$URL")"
    COMMIT=${LINE%%[[:space:]]*}
    [ -n "$COMMIT" ] || unchecked "$(tr_ "%s does not have %s" "$URL" "$REF")"
    VERSION="$REF@${COMMIT:0:12}"
    look_cache "$VERSION"
    git clone -q --depth 1 --branch "$REF" -c advice.detachedHead=false "$URL" "$T/code/src" 2>/dev/null \
        || unchecked "$(tr_ "%s could not be cloned (%s)" "$URL" "$REF")"
    SRC=$T/code/src
fi

# ---- test our own patches, in order --------------------------------------------------------------
# try [--reverse]: 0 if the patch $p applies; writes ",reduced_context" if only with -C1
try() {
    ( cd "$SRC" && git apply --check ${1:+"$1"} "$p" 2>/dev/null ) && return 0
    ( cd "$SRC" && git apply --check -C1 ${1:+"$1"} "$p" 2>/dev/null ) && { echo ",reduced_context"; return 0; }
    return 1
}
OUT=(); n_needed=0; n_incl=0; n_conf=0; needed=(); incl=(); conf=()
for p in "${PATCHES[@]}"; do
    b=${p##*/}
    # First with all the context (3 lines); if not, with 1 (like GNU patch's "fuzz" 2, which is what
    # xbps-src uses: a patch like that is also applied when building). It is said when it was needed.
    if C=$(try ""); then
        e=STILL_NEEDED$C; n_needed=$((n_needed+1)); needed+=("$b")
        ( cd "$SRC" && git apply ${C:+-C1} "$p" 2>/dev/null )   # the following ones are tested on top of this one
    elif C=$(try --reverse); then
        e=ALREADY_INCLUDED$C; n_incl=$((n_incl+1)); incl+=("$b")
    else
        e=CONFLICT; n_conf=$((n_conf+1)); conf+=("$b")
    fi
    OUT+=("PATCH $b $e")
done
total=${#PATCHES[@]}
if [ $n_conf -gt 0 ]; then
    RES="CONFLICT $(tr_ "applies neither forwards nor in reverse: %s (upstream rewrote that part: review by hand)" "${conf[*]}")"
elif [ $n_incl = "$total" ]; then
    RES="ALREADY_INCLUDED $(tr_ "the code already brings all the patches: one can go back to Void's")"
elif [ $n_needed = "$total" ]; then
    RES="STILL_NEEDED $(tr_ "the code brings none: rebuild with the patches")"
else
    RES="PARTIAL $(tr_ "already included: %s; still needed: %s (remove the included ones and rebuild with the rest)" "${incl[*]}" "${needed[*]}")"
fi
OUT+=("RESULT $NAME $VERSION $RES")
printf '%s\n' "${OUT[@]}"
mkdir -p "$CACHE" && printf '%s\n' "${OUT[@]}" > "$CACHE/$NAME-${VERSION//\//_}-$HASH.txt"
exit 0
