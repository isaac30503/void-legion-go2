#!/bin/sh
# install-passwordless-switch.sh — switch between Game Mode and Xfce without a login screen or
# password, like SteamOS: its "Switch to Desktop" changes the session manager's autologin session
# and restarts it, which logs back into the new one by itself. Here:
#   - /etc/xdg/lightdm/lightdm.conf.d/60-steam-mode.conf: autologin of the user in the chosen
#     mode (steam-game-mode-direct or xfce-wayland/xfce). lightdm reads that folder BEFORE lightdm.conf, so
#     the autologin-user/autologin-session lines that the ISO brought are commented out in lightdm.conf;
#   - /usr/local/bin/switch-mode-root game|desktop|desktop-x11 (root): changes that session
#     and restarts lightdm (desktop = Xfce on Wayland/labwc, step 15; desktop-x11 = Xfce X11);
#   - /etc/sudoers.d/zz-switch-mode: the user can run ONLY that script without password (the script
#     only accepts those arguments); it is validated with visudo before being put in place. The name starts
#     with "zz" on purpose: sudoers.d is read in alphabetical order and the LAST matching rule wins;
#     with "cambiar-modo" (its first name), the "wheel" one (which asks for a password) was read later and overrode it.
# steamos-session-select (install-game-mode.sh) uses it if it is there; otherwise, the old way.
# As there is never a login screen in between, the direct Wayland session works in both
# directions (the boot's login screen was what broke it, see recipe step 14).
# CAREFUL: a password is never asked to log in; at power-on it enters the last mode used.
# Needs test-direct-session.sh (the session steam-game-mode-direct). Void recipe, step 14.
# Previous (Spanish) name: instalar-cambio-sin-contrasena.sh. The pieces it installed had Spanish names
# (cambiar-modo-root juego|escritorio|escritorio-x11 --puede, 60-modo-steam.conf, zz-cambiar-modo,
# 05-cerrar-steam.sh, /usr/local/lib/cambiar-modo/reiniciar-lightdm, service cambio-modo,
# /run/cambiar-modo.log, /run/apagando-sistema): installing replaces them and keeps the chosen mode;
# switch-mode-root still accepts the Spanish arguments.
#   sudo sh common/steam/install-passwordless-switch.sh            installs (valid on reboot)
#   sudo sh common/steam/install-passwordless-switch.sh --remove   removes it (the login screen comes back)
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
U=$TARGET_USER
[ -n "$U" ] || { t "Run it with sudo from the user's account (or set TARGET_USER in local.env)."; exit 1; }
CONF=/etc/lightdm/lightdm.conf
DROP=/etc/xdg/lightdm/lightdm.conf.d/60-steam-mode.conf
HELP=/usr/local/bin/switch-mode-root
SUDO=/etc/sudoers.d/zz-switch-mode
SHUTDOWN=/etc/runit/shutdown.d/05-close-steam.sh   # close Steam cleanly at power-off (2026-10-04)
SESSION_WRAPPER=/usr/local/bin/xfce4-session        # close Steam cleanly when leaving Xfce (2026-10-04)
RESTART=/usr/local/lib/switch-mode/restart-lightdm  # lightdm restart without a race with elogind
SV_SWITCH=/etc/sv/mode-switch   # one-shot runit service that launches it (sv once)
# The old Spanish-named pieces (and the first sudoers name, which did not work).
OLD_DROP=/etc/xdg/lightdm/lightdm.conf.d/60-modo-steam.conf
OLD_FILES="/usr/local/bin/cambiar-modo-root /etc/sudoers.d/zz-cambiar-modo /etc/sudoers.d/cambiar-modo
           /etc/runit/shutdown.d/05-cerrar-steam.sh"

remove_old() {
    rm -f /var/service/cambio-modo
    for f in $OLD_FILES; do rm -f "$f"; done
    rm -rf /usr/local/lib/cambiar-modo /etc/sv/cambio-modo
}

cp "$CONF" "$CONF.bak"
if is_remove "${1:-}"; then
    rm -f "$DROP" "$OLD_DROP" "$HELP" "$SUDO" "$SHUTDOWN" "$SESSION_WRAPPER"
    rm -f /var/service/mode-switch; rm -rf "${RESTART%/*}" "$SV_SWITCH"
    remove_old
    # The ISO's two lines, as they came (nonexistent user: no autologin).
    sed -i 's/^#*autologin-user=.*/autologin-user=anon/; s/^#*autologin-session=.*/autologin-session=xfce/' "$CONF"
    t "== removed; differences in %s:" "$CONF"; diff "$CONF.bak" "$CONF" || true
    t "== Reboot: the login screen with password comes back."
    exit 0
fi
[ -f /usr/share/wayland-sessions/steam-game-mode-direct.desktop ] || {
    t "!! The direct session is missing: run test-direct-session.sh first"; exit 1; }
grep -q 'switch-mode-root' /usr/local/bin/steamos-session-select 2>/dev/null || {
    t "!! steamos-session-select is an old one: run install-game-mode.sh first"; exit 1; }

t "== 1. lightdm.conf: comment out autologin-user/autologin-session (the separate file sets them)"
sed -i 's/^autologin-user=/#autologin-user=/; s/^autologin-session=/#autologin-session=/' "$CONF"
diff "$CONF.bak" "$CONF" || true

# The first time it starts in Game Mode, like SteamOS; if it already existed, it keeps the chosen mode
# (before, running this script again always sent it back to Game Mode). The old Spanish-named file
# counts too, with its session name translated.
# (If the file does not exist yet —new installation—, sed fails: with set -e that cut the script
#  silently here; it happened on the Legion on 2026-10-03. Hence the "|| true".)
SESSION=$(sed -n 's/^autologin-session=//p' "$DROP" 2>/dev/null || true)
[ -n "$SESSION" ] || SESSION=$(sed -n 's/^autologin-session=//p' "$OLD_DROP" 2>/dev/null || true)
[ "$SESSION" = steam-modo-juego-directo ] && SESSION=steam-game-mode-direct
[ "$SESSION" = steam-modo-juego ] && SESSION=steam-game-mode
SESSION=${SESSION:-steam-game-mode-direct}
t "== 2. %s (session: %s)" "$DROP" "$SESSION"
mkdir -p "${DROP%/*}"
cat > "$DROP" <<EOF
# Autologin according to the chosen mode (changed by $HELP; set by
# common/steam/install-passwordless-switch.sh; Void recipe, step 14).
[Seat:*]
autologin-user=$U
autologin-user-timeout=0
autologin-session=$SESSION
EOF
rm -f "$OLD_DROP"

t "== 3. %s" "$HELP"
cat > "$HELP" <<EOF
#!/bin/sh
# switch-mode-root game|desktop|desktop-x11 — changes lightdm's autologin session and
# restarts it, which logs into it by itself (like SteamOS's "Switch to Desktop"). It runs as root:
# $U can run it without password (/etc/sudoers.d/zz-switch-mode), and that is why it only accepts these
# arguments. "--check" only checks that it is installed. Void recipe, step 14.
# Previous (Spanish) name: cambiar-modo-root (its Spanish arguments were removed on 2026-10-13).
D=$DROP
# During power-off (05-close-steam.sh leaves /run/system-shutting-down) nothing is changed: when Steam
# closes in Game Mode, the launcher takes it as "Switch to Desktop" and would get here.
[ -e /run/system-shutting-down ] && exit 0
case "\$1" in
    --check)            [ -f "\$D" ]; exit \$? ;;
    game)               s=steam-game-mode-direct ;;
    # The desktop is Xfce on Wayland (labwc, step 15) since 2026-10-03; X11 stays as the
    # fallback.
    desktop)            s=xfce-wayland ;;
    desktop-x11)        s=xfce ;;
    *) echo "usage: switch-mode-root game|desktop|desktop-x11" >&2; exit 2 ;;
esac
[ -f "\$D" ] || exit 1
sed -i "s/^autologin-session=.*/autologin-session=\$s/" "\$D"
# Steam open ("X11 Desktop"/"Wayland Desktop" launchers from the desktop): restarting
# lightdm takes the session with Steam inside and on start it did the full verification. It is
# closed cleanly first, as in 05-close-steam.sh (steam -shutdown as its user, with the process's
# own environment; event-driven wait, 20 s cap). From Game Mode Steam has already ended
# when it gets here (steamos-session-select / the launcher): there is nothing to close. (2026-10-04)
if pgrep -x steam >/dev/null 2>&1; then
    for _u in \$(ps -o user= -C steam | sort -u); do
        _p=\$(pgrep -u "\$_u" -x steam | head -1)
        _e=\$(tr '\0' '\n' < /proc/\$_p/environ 2>/dev/null | grep -E '^(HOME|USER|LOGNAME|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | tr '\n' ' ')
        chpst -u "\$_u" env -i PATH=/usr/bin:/bin \$_e /usr/bin/steam -shutdown </dev/null >/dev/null 2>&1 &
    done
    timeout 20 pidwait -x steam 2>/dev/null
fi
# Restarting lightdm closes the current session (and this script with it): runit does it, with the
# one-shot service $SV_SWITCH ("sv once"), which does not die with the session. Launched from here
# with setsid, the helper stopped lightdm and died with the session without starting it again: screen
# off (Legion, 2026-10-04). Not "sv restart" at once: see $RESTART (race with elogind).
sv once mode-switch
EOF
chown root:root "$HELP"; chmod 755 "$HELP"

t "== 3a. %s" "$RESTART"
mkdir -p "${RESTART%/*}"
cat > "$RESTART.tmp" <<'RESTART_EOF'
#!/bin/sh
# restart-lightdm UID — restarts lightdm to switch mode (called by switch-mode-root; installed by
# common/steam/install-passwordless-switch.sh, Void recipe, step 14) WITHOUT a race with elogind:
# with "sv restart lightdm" the new session started while elogind was still cleaning the old one; when
# the user was left without sessions, elogind deletes /run/user/UID and took with it the wayland-0 socket
# just created by the new labwc: xfce4-session and the panel fell back to X11 (Xwayland), the panel
# flickered (labwc: "view has no last placement info" ~60/s) and looked different (Legion, 2026-10-04).
# Here: stop lightdm, wait EVENT-DRIVEN (inotifywait on elogind's state files in
# /run/systemd) for the graphical session (seat0) to close and, if the user was left without sessions,
# for elogind to delete /run/user/UID; then start lightdm. If another session remains (SSH), elogind does not
# delete anything and it does not wait. Caps: 10 s + 5 s. Log (English): /run/switch-mode.log.
# Previous (Spanish) name: /usr/local/lib/cambiar-modo/reiniciar-lightdm (log /run/cambiar-modo.log).
U=${1:?usage: restart-lightdm UID}
F=/run/systemd/users/$U
R=/run/user/$U
L=/run/switch-mode.log
t0=$(date +%s.%N)
log() { echo "$(date +%T.%N | cut -c1-12) $*" >> "$L"; }
graphical() {   # does the user still have any session on seat0?
    for s in $(sed -n 's/^SESSIONS=//p' "$F" 2>/dev/null); do
        grep -q '^SEAT=seat0' "/run/systemd/sessions/$s" 2>/dev/null && return 0
    done
    return 1
}
log "stop lightdm"
sv stop lightdm >/dev/null 2>&1
end=$(( $(date +%s) + 10 ))
while [ -e "$F" ]; do
    if ! graphical; then
        grep -q '^SESSIONS=.' "$F" 2>/dev/null && { log "another session remains: no cleanup"; break; }
    fi
    r=$(( end - $(date +%s) )); [ "$r" -gt 0 ] || { log "10 s cap waiting for elogind"; break; }
    inotifywait -qq -t "$r" -e close_write -e moved_to -e delete /run/systemd/users /run/systemd/sessions 2>/dev/null
done
if [ ! -e "$F" ] && [ -d "$R" ]; then
    log "user closed; waiting for elogind to delete $R"
    timeout 5 inotifywait -qq -e delete_self "$R" 2>/dev/null
fi
log "start lightdm ($(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}') s)"
exec sv start lightdm >/dev/null 2>&1
RESTART_EOF
chmod 755 "$RESTART.tmp"; mv "$RESTART.tmp" "$RESTART"; ls -l "$RESTART"
# runit service that runs it: "down" = it does not start at power-on; "sv once" runs it once and
# runsv does not repeat it when it ends. It is linked in /var/service so that runsvdir supervises it.
mkdir -p "$SV_SWITCH"
printf '#!/bin/sh\n# Installed by common/steam/install-passwordless-switch.sh; launched by switch-mode-root (sv once mode-switch).\nexec %s %s\n' "$RESTART" "$(id -u "$U")" > "$SV_SWITCH/run.tmp"
chmod 755 "$SV_SWITCH/run.tmp"; mv "$SV_SWITCH/run.tmp" "$SV_SWITCH/run"; : > "$SV_SWITCH/down"
[ -L /var/service/mode-switch ] || ln -s "$SV_SWITCH" /var/service/
cat "$SV_SWITCH/run"

t "== 3b. %s" "$SHUTDOWN"
cat > "$SHUTDOWN" <<'SHUTDOWN_EOF'
# 05-close-steam.sh — at power-off or reboot, close Steam CLEANLY (steam -shutdown) before
# 10-sv-stop.sh stops lightdm and takes the session with Steam inside. Steam asks for the reboot from its
# menu directly to elogind (D-Bus login1 Reboot) without closing itself; then runit ended it with everything
# else, and on start Steam saw that it "did not close properly" and did the full verification.
# Valid for Steam's menu and sudo reboot; when leaving Xfce, only together with the wrapper
# /usr/local/bin/xfce4-session (3c), which keeps the session alive until here. Loaded by /etc/runit/3 (with
# ".", without a subshell: no exit). It leaves /run/system-shutting-down so that switch-mode-root does not change the
# mode when Game Mode's launcher sees Steam end. Event-driven wait (pidwait), 20 s
# cap. Installed by common/steam/install-passwordless-switch.sh (Void recipe, step 14).
# Previous (Spanish) name: 05-cerrar-steam.sh (marker /run/apagando-sistema).
if pgrep -x steam >/dev/null 2>&1; then
    : > /run/system-shutting-down
    for _u in $(ps -o user= -C steam | sort -u); do
        _p=$(pgrep -u "$_u" -x steam | head -1)
        _e=$(tr '\0' '\n' < /proc/$_p/environ 2>/dev/null | grep -E '^(HOME|USER|LOGNAME|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | tr '\n' ' ')
        chpst -u "$_u" env -i PATH=/usr/bin:/bin $_e /usr/bin/steam -shutdown </dev/null >/dev/null 2>&1 &
    done
    timeout 20 pidwait -x steam 2>/dev/null
    unset _u _p _e
fi
SHUTDOWN_EOF
chmod 644 "$SHUTDOWN"; ls -l "$SHUTDOWN"

t "== 3c. %s" "$SESSION_WRAPPER"
cat > "$SESSION_WRAPPER.tmp" <<'SESSION_EOF'
#!/bin/sh
# xfce4-session wrapper (installed by common/steam/install-passwordless-switch.sh; Void recipe, step 14).
# When leaving Xfce (exit button, Super+Escape, Ctrl+Alt+Del: log out, reboot or
# power off), xfce4-session ends and the session with it: labwc --session xfce4-session (Wayland) or the
# xinitrc (X11) close, and Steam died with Xwayland/X ("X connection to :0 broken") before the
# power-off reached 05-close-steam.sh; on start, full verification (2026-10-04, both
# machines). Here, when xfce4-session ends, Steam is closed cleanly (steam -shutdown, like
# steamos-session-select) and it waits event-driven (pidwait, 20 s cap) with the session still alive; on
# reboot, 05-close-steam.sh also finds it alive. /usr/local/bin goes before /usr/bin in
# the session's PATH. With arguments (--help…) it does nothing else.
[ $# -gt 0 ] && exec /usr/bin/xfce4-session "$@"
/usr/bin/xfce4-session; rc=$?
if pgrep -u "$(id -u)" -x steam >/dev/null 2>&1; then
    steam -shutdown </dev/null >/dev/null 2>&1 &
    timeout 20 pidwait -u "$(id -u)" -x steam 2>/dev/null
fi
exit $rc
SESSION_EOF
chmod 755 "$SESSION_WRAPPER.tmp"; mv "$SESSION_WRAPPER.tmp" "$SESSION_WRAPPER"; ls -l "$SESSION_WRAPPER"

t "== 4. %s (validated with visudo)" "$SUDO"
T=$(mktemp)
echo "$U ALL=(root) NOPASSWD: $HELP" > "$T"
if visudo -cf "$T" >/dev/null; then
    install -m 440 -o root -g root "$T" "$SUDO"; rm -f "$T"; cat "$SUDO"
else
    rm -f "$T"; t "!! the sudoers rule is not valid: it is not installed"; exit 1
fi
remove_old

t "== check"
if sudo -n -u "$U" sudo -n "$HELP" --check; then
    t "   %s can use %s without password" "$U" "$HELP"
else
    t "!! %s can NOT use %s without password: the switch will ask for it again" "$U" "$HELP"; exit 1
fi
grep -n 'autologin' "$DROP"
# The message says the mode it will really start in (the kept one; before, it always said Game Mode)
case "$SESSION" in
    steam-game-mode*) t "== Reboot: it enters Game Mode by itself. 'Switch to Desktop' → Xfce without password;" ;;
    xfce-wayland)     t "== Reboot: it enters the desktop (Xfce on Wayland) by itself, the chosen mode. 'Switch to Desktop' → Xfce without password;" ;;
    *)                t "== Reboot: it enters the desktop (Xfce X11) by itself, the chosen mode. 'Switch to Desktop' → Xfce without password;" ;;
esac
t "   from Xfce, the 'Game Mode' launcher → Game Mode without password."
