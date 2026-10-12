# shellcheck shell=bash
# services.sh — runit services that still run old code after an update (the equivalent of cachy-update's
# "checkservices", which is systemd's): a process whose executable or some library it has mapped was replaced
# by the update shows it as "(deleted)" in /proc/<pid>/maps. Each of those processes is followed up to its
# "runsv <service>" parent; those services are offered for restart ("sv restart"). Reading the maps of root's
# processes needs root (sudo). runit restarts nothing on update (sshd is restarted by itself in the update when
# OpenSSH changes).
# Never offered: lightdm (it would close the graphical session and Game Mode), dbus (the session would break),
# and the agetty consoles; they apply with the next reboot.

VU_SERVICES_SKIP='^(lightdm|dbus|agetty-.*)$'

# vu_stale_services: names of the services with old code, one per line (needs sudo)
vu_stale_services() {
    sudo bash -c '
        for p in /proc/[0-9]*; do
            grep -qE "\.so[^ ]* \(deleted\)$|/(s?bin|libexec)/[^ ]+ \(deleted\)$" "$p/maps" 2>/dev/null || continue
            q=${p#/proc/}
            while [ -n "$q" ] && [ "$q" -gt 1 ] 2>/dev/null; do
                c=$(tr "\0" " " < /proc/$q/cmdline 2>/dev/null)
                case "$c" in "runsv "*) set -- $c; echo "$2"; break ;; esac
                q=$(sed "s/.*) //" /proc/$q/stat 2>/dev/null | cut -d" " -f2)   # parent pid (the name may have spaces)
            done
        done' 2>/dev/null | sort -u | grep -vE "$VU_SERVICES_SKIP"
}

# vu_services [--ask]: lists them; with --ask, offers to restart (numbers, 0 = all, Enter = none)
vu_services() {
    local svcs n i ans s fail=
    mapfile -t svcs < <(vu_stale_services)
    n=${#svcs[@]}
    if [ "$n" = 0 ]; then ok "No service needs a restart after the update"; return 0; fi
    if [ "$n" = 1 ]; then step "This service runs old code and needs a restart to use the update:"
    else step "These services run old code and need a restart to use the update:"; fi
    for i in "${!svcs[@]}"; do echo "  $((i+1)) - ${svcs[$i]}"; done
    [ "${1:-}" = --ask ] || return 0
    while :; do
        read -r -p "$(t "Services to restart (e.g. 1 3), 0 = all, Enter = none: ")" -a ans || ans=()
        local bad=; for s in "${ans[@]}"; do [[ "$s" =~ ^[0-9]+$ ]] && [ "$s" -le "$n" ] || bad=1; done
        [ -z "$bad" ] && break
        warn "Invalid answer"
    done
    [ ${#ans[@]} -gt 0 ] || { warn "Not restarted: the services keep the old code until they are restarted or the machine reboots"; return 0; }
    local pick=()
    if [ "${ans[0]}" = 0 ]; then pick=("${svcs[@]}"); else for s in "${ans[@]}"; do pick+=("${svcs[$((s-1))]}"); done; fi
    for s in $(printf '%s\n' "${pick[@]}" | sort -u); do
        if sudo sv restart "$s" >/dev/null; then ok "Restarted: %s" "$s"; else err "Could not restart %s" "$s"; fail=1; fi
    done
    [ -z "$fail" ]
}
