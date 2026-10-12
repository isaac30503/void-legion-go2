# shellcheck shell=bash
# base.sh — shared by void-update's libraries: paths, configuration, messages and small helpers.
# Sourced by void-update (bash); not run alone.

VU_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/void-update"
VU_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/void-update/void-update.conf"
VU_RUN="${XDG_RUNTIME_DIR:-/tmp}"
# State files (the tray applet watches $VU_STATE/state and reads the rest):
#   state            up-to-date | available | checking | error   (what the icon shows)
#   packages         pending xbps updates, one per line: "name old -> new"
#   flatpak          pending Flatpak updates, one per line: "name version"
#   all              packages + flatpak (what the notification counts)
#   xbps-raw         raw output of xbps-install -Mun (sizes)
#   last-check       epoch of the last check that finished
#   last-update      epoch of the last full update that ended fine (fastfetch's "Updated" line)
#   notified         the list that was last notified (a notification only when it changes)
#   notification-id  id of the last notification (it is replaced, not stacked)
#   error            the reason of the last failed check
mkdir -p "$VU_STATE"

# ---- configuration ---------------------------------------------------------------------------------
# Defaults; ~/.config/void-update/void-update.conf (KEY=value, one per line) overrides them. Only these keys
# are read, and the file is never run as code.
check_interval_hours=6       # the tray checks when the network connects and then every N hours (0 = only on connect)
check_timeout=120            # seconds for each query (xbps index, Flatpak, news)
notifications=true           # desktop notification when the list of pending updates changes
flatpak=true                 # include Flatpak (if installed)
news=true                    # show Void's news before updating (https://voidlinux.org/atom.xml)
news_count=5                 # how many news --news shows by default
hide_tray_when_up_to_date=false
tray_updates_per_page=30     # entries per submenu page in the tray
vu_load_config() {
    [ -r "$VU_CONF" ] || return 0
    local k v
    while IFS='=' read -r k v; do
        k=${k//[[:space:]]/}; v=${v%%#*}; v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
        v=${v#\"}; v=${v%\"}; v=${v#\'}; v=${v%\'}
        case "$k" in
            check_interval_hours|check_timeout|news_count|tray_updates_per_page)
                [[ "$v" =~ ^[0-9]+$ ]] && printf -v "$k" '%s' "$v" ;;
            notifications|flatpak|news|hide_tray_when_up_to_date)
                case "$v" in true|false) printf -v "$k" '%s' "$v" ;; esac ;;
        esac
    done < <(grep -v '^[[:space:]]*#' "$VU_CONF")
}
vu_load_config

# ---- messages (colors only on a terminal) ----------------------------------------------------------
if [ -t 1 ]; then
    c_bold=$'\e[1m'; c_red=$'\e[31m'; c_green=$'\e[32m'; c_yellow=$'\e[33m'; c_cyan=$'\e[36m'; c_blue=$'\e[34m'; c_off=$'\e[0m'
else
    c_bold=; c_red=; c_green=; c_yellow=; c_cyan=; c_blue=; c_off=
fi
step()  { echo "${c_blue}==>${c_off}${c_bold} $(t "$@")${c_off}"; }     # a step:   ==> Syncing repositories
ok()    { echo "${c_green}✓${c_off} $(t "$@")"; }
info()  { echo "ℹ $(t "$@")"; }
warn()  { echo "${c_yellow}⚠ $(t "$@")${c_off}"; }
err()   { echo "${c_red}✗ $(t "$@")${c_off}" >&2; }
# ask DEFAULT FORMAT ARGS…: a [Y/n] or [y/N] question; returns 0 for yes. Any answer starting with
# n/N is no, with y/Y/s/S (sí) is yes; empty = DEFAULT (y or n).
ask() {
    local def=$1 ans; shift
    read -r -p "$(t "$@")" ans || ans=
    case "$ans" in [nN]*) return 1 ;; [yYsS]*) return 0 ;; *) [ "$def" = y ] ;; esac
}

# ---- small helpers ----------------------------------------------------------------------------------
vu_set_state() { printf '%s\n' "$1" > "$VU_STATE/state.new" && mv -f "$VU_STATE/state.new" "$VU_STATE/state"; }
vu_count() { [ -s "$1" ] && grep -c . "$1" || echo 0; }
# Name of a package from its pkgver (what goes before the last "-")
vu_pkgname() { sed -E 's/-[^-]*$//'; }
