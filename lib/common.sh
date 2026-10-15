# shellcheck shell=sh
# lib/common.sh — helpers shared by the scripts of this repository (POSIX sh: sh/dash and bash).
# Every script starts with these two lines, which find the repository root from the script's own
# location (so a script works from any clone, wherever it is):
#
#   R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
#   . "$R/lib/common.sh"
#
# If the script was copied out of the clone (e.g. to /tmp), set VOID_LEGION_REPO=<clone> first.
#
# What it gives:
#   REPO_ROOT                  the root of the clone
#   t FORMAT [ARG...]          translated message (lib/i18n.sh)
#   need_root / need_user      stop unless running as root (sudo) / as a normal user
#   TARGET_USER, TARGET_HOME   the person the installation is for: the user who called sudo, or the
#                              current user if it is not root; from a root shell (no sudo), the
#                              TARGET_USER of local.env
#   load_local_env             reads local.env (the real values of the @PLACEHOLDERS@; git-ignored)
#   need_env NAME...           stops if one of those values is missing in local.env
#   render SRC DST             copies SRC to DST replacing every @NAME@ with its value from local.env,
#                              and @TARGET_HOME@ / @TARGET_USER@ with the target user's home and name
#   is_remove ARG              true for --remove
#   install_i18n_system        (root) copies lib/i18n.sh, lib/void_legion_i18n.py and locale/ to
#                              /usr/local/{lib,share}/void-legion/, for the scripts the installers write
#                              into the system (they look for the catalogs there)
#   install_i18n_user          the same for the user: ~/.local/share/void-legion/{lib,locale}

if [ -z "${REPO_ROOT:-}" ]; then
    if [ -n "${VOID_LEGION_REPO:-}" ]; then REPO_ROOT=$VOID_LEGION_REPO
    else REPO_ROOT=${R:-$(cd "$(dirname "$0")" && pwd)}; fi
fi
export REPO_ROOT
# No __pycache__ in the clone: a script run with sudo would leave it owned by root (and build/ could not be
# remade without root). Python's caches are not needed here.
export PYTHONDONTWRITEBYTECODE=1

I18N_REPO_DIR=$REPO_ROOT
. "$REPO_ROOT/lib/i18n.sh"

need_root() {
    [ "$(id -u)" = 0 ] || { t "Run it with sudo."; exit 1; }
}

need_user() {
    [ "$(id -u)" != 0 ] || { t "Run it without sudo, as your normal user."; exit 1; }
}

load_local_env() {
    if [ -r "$REPO_ROOT/local.env" ]; then
        # shellcheck disable=SC1091
        . "$REPO_ROOT/local.env"
    fi
}

need_env() {
    load_local_env
    for _n in "$@"; do
        eval "_v=\${$_n:-}"
        if [ -z "$_v" ]; then
            t "Missing %s in %s (copy local.env.example to local.env and fill it in)." "$_n" "$REPO_ROOT/local.env" >&2
            exit 1
        fi
    done
}

render() {
    load_local_env
    _src=$1; _dst=$2
    cp "$_src" "$_dst.tmp"
    sed -i "s|@TARGET_HOME@|$TARGET_HOME|g; s|@TARGET_USER@|$TARGET_USER|g" "$_dst.tmp"
    if [ -r "$REPO_ROOT/local.env" ]; then
        for _n in $(sed -n "s/^\([A-Z0-9_]*\)=.*/\1/p" "$REPO_ROOT/local.env"); do
            eval "_v=\${$_n:-}"
            # Values are MACs, UUIDs, names, numbers: escape only what sed's replacement needs.
            _e=$(printf '%s' "$_v" | sed 's/[\\&|]/\\&/g')
            sed -i "s|@$_n@|$_e|g" "$_dst.tmp"
        done
    fi
    if grep -q '@[A-Z][A-Z0-9_]*@' "$_dst.tmp"; then
        t "Placeholders without a value in local.env, in %s:" "$_src" >&2
        grep -o '@[A-Z][A-Z0-9_]*@' "$_dst.tmp" | sort -u >&2
        rm -f "$_dst.tmp"; return 1
    fi
    mv "$_dst.tmp" "$_dst"
}

_copy_i18n() {   # $1 = share dir, $2 = dir for i18n.sh
    mkdir -p "$1/lib" "$2"
    install -m 644 "$REPO_ROOT/lib/void_legion_i18n.py" "$1/lib/void_legion_i18n.py"
    install -m 644 "$REPO_ROOT/lib/i18n.sh" "$2/i18n.sh"
    rm -rf "$1/locale.tmp"; cp -r "$REPO_ROOT/locale" "$1/locale.tmp"
    rm -rf "$1/locale"; mv "$1/locale.tmp" "$1/locale"
}
install_i18n_system() { _copy_i18n /usr/local/share/void-legion /usr/local/lib/void-legion; }
install_i18n_user() { _copy_i18n "$HOME/.local/share/void-legion" "$HOME/.local/share/void-legion/lib"; }

is_remove() {
    case "${1:-}" in --remove) return 0 ;; *) return 1 ;; esac
}

load_local_env
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    TARGET_USER=$SUDO_USER
elif [ "$(id -u)" != 0 ]; then
    TARGET_USER=$(id -un)
fi  # otherwise (root shell without sudo): TARGET_USER from local.env, if it is there
TARGET_USER=${TARGET_USER:-}
if [ -n "$TARGET_USER" ]; then
    # A user that does not exist (a root shell with TARGET_USER of local.env wrong or still the example's) has
    # to stop with a message: otherwise getent fails and scripts with set -e end silently
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6) || TARGET_HOME=""
    [ -n "$TARGET_HOME" ] || { t "!! The user %s does not exist (TARGET_USER in %s)." "$TARGET_USER" "$REPO_ROOT/local.env" >&2; exit 1; }
else
    TARGET_HOME=""
fi
export TARGET_USER TARGET_HOME
