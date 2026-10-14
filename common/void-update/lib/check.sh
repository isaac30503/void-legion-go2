# shellcheck shell=bash
# check.sh — void-update --check: looks for pending updates WITHOUT root and without touching the system.
# xbps: "xbps-install -Mun" fetches the repositories' index into memory (-M), so it needs neither root nor a
# previous "xbps-install -S" (that one writes /var/db/xbps and needs root). Flatpak: "remote-ls --updates".
# It writes the state files (base.sh), sets the tray's state and, if the list changed and notifications
# are on, sends a desktop notification with a "Run void-update" button.

# vu_installed_versions: "name version" of every installed package (one xbps-query for all)
vu_installed_versions() { xbps-query -l 2>/dev/null | awk '{p=$2; n=p; sub(/-[^-]*$/,"",n); v=substr(p,length(n)+2); print n, v}'; }

# vu_write_pending RAW: from the output of xbps-install -un/-Mun ("pkgver action arch repo isize dsize"), the
# state file "packages" ("name old -> new", in the order of xbps) and "xbps-raw" (moves RAW there)
vu_write_pending() {
    awk 'NR==FNR {v[$1]=$2; next}
         {p=$1; n=p; sub(/-[^-]*$/,"",n); nv=substr(p,length(n)+2); ov=(n in v) ? v[n] : "(new)"; print n, ov, "->", nv}' \
        <(vu_installed_versions) "$1" > "$VU_STATE/packages.new"
    mv -f "$1" "$VU_STATE/xbps-raw"; mv -f "$VU_STATE/packages.new" "$VU_STATE/packages"
}

# vu_check [--quiet]: 0 = done (with or without updates), 1 = the check failed (state "error")
vu_check() {
    local quiet= raw err rc
    [ "${1:-}" = --quiet ] && quiet=1
    exec {lock}> "$VU_RUN/void-update-check.lock"
    if ! flock -n "$lock"; then [ -n "$quiet" ] || info "A check is already running"; return 0; fi
    vu_set_state checking
    raw=$(mktemp); err=$(mktemp)
    timeout "$check_timeout" xbps-install -Mun > "$raw" 2> "$err"; rc=$?
    if [ $rc -ne 0 ] && grep -q "must be updated" "$err"; then
        # With an old xbps, xbps-install refuses everything until xbps itself is updated: that IS the update
        echo "xbps update x86_64 - 0 0" > "$raw"; rc=0
    fi
    if [ $rc -ne 0 ]; then
        if [ $rc = 124 ]; then t "timeout after %s s" "$check_timeout" > "$VU_STATE/error"
        else { head -3 "$err"; echo "(xbps-install -Mun: $rc)"; } > "$VU_STATE/error"; fi
        rm -f "$raw" "$err"
        vu_set_state error
        [ -n "$quiet" ] || err "The check failed: %s" "$(head -1 "$VU_STATE/error")"
        return 1
    fi
    rm -f "$err" "$VU_STATE/error"
    vu_write_pending "$raw"
    : > "$VU_STATE/flatpak.new"
    if [ "$flatpak" = true ] && command -v flatpak >/dev/null; then
        timeout "$check_timeout" flatpak remote-ls --updates --columns=name,version 2>/dev/null | tr -s '\t' ' ' \
            | sed '/^[[:space:]]*$/d' > "$VU_STATE/flatpak.new" || true
    fi
    mv -f "$VU_STATE/flatpak.new" "$VU_STATE/flatpak"
    cat "$VU_STATE/packages" "$VU_STATE/flatpak" > "$VU_STATE/all"
    date +%s > "$VU_STATE/last-check"
    local n; n=$(vu_count "$VU_STATE/all")
    if [ "$n" -gt 0 ]; then
        vu_set_state available
        if [ "$notifications" = true ] && ! cmp -s "$VU_STATE/all" "$VU_STATE/notified"; then
            cp "$VU_STATE/all" "$VU_STATE/notified"
            vu_notify "$n"
        fi
        [ -n "$quiet" ] || { [ "$n" = 1 ] && info "1 update available" || info "%s updates available" "$n"; }
    else
        vu_set_state up-to-date
        : > "$VU_STATE/notified"
        [ -n "$quiet" ] || ok "System is up to date"
    fi
    return 0
}

# vu_notify N: the notification, detached (it waits for the click without holding the check). Clicking
# "Run void-update" opens void-update in a terminal through its .desktop (the same as the tray). Without a
# graphical session (no DBUS_SESSION_BUS_ADDRESS) or without notify-send, nothing.
vu_notify() {
    command -v notify-send >/dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 0
    local body run close id
    if [ "$1" = 1 ]; then body=$(t "1 update available"); else body=$(t "%s updates available" "$1"); fi
    run=$(t "Run void-update"); close=$(t "Close")
    id=$(cat "$VU_STATE/notification-id" 2>/dev/null)
    local icon="$HOME/.local/share/icons/hicolor/scalable/apps/void-update.svg"
    [ -f "$icon" ] || icon=software-update-available
    ID="$id" ICON="$icon" setsid -f bash -c '
        st=$1; shift
        out=$(notify-send -p ${ID:+-r "$ID"} -a void-update -i "$ICON" "$@")
        printf "%s\n" "$out" | sed -n 1p > "$st/notification-id"
        [ "$(printf "%s\n" "$out" | sed -n 2p)" = run ] && exec void-update --open-terminal
        exit 0' _ "$VU_STATE" "void-update" "$body" -A "run=$run" -A "close=$close" \
        </dev/null >/dev/null 2>&1
}
