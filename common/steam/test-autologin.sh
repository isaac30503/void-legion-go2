#!/bin/sh
# test-autologin.sh — TEST: at power-on, lightdm logs in by itself (without login screen or
# password) into "Steam (Game Mode, direct screen)", like SteamOS. That way there is no boot login
# screen that has to die: the cause of the Wayland session losing the console after
# ~22 s (2026-10-03: that login screen does not die with lightdm's SIGTERM, and when it half closes
# it takes the console away from gamescope).
# When leaving ("Switch to Desktop") lightdm shows the login screen, as always, and from there
# Xfce. Autologin only happens at power-on. (Superseded by install-passwordless-switch.sh, which is
# what the recipe uses; kept as part of the history.)
# CAREFUL: whoever turns on the machine enters the user's session without password.
# It changes two lines that /etc/lightdm/lightdm.conf already brought from the ISO (autologin-user=anon, a
# user that does not exist, and autologin-session=xfce); --remove puts them back as they were. Leaves .bak.
# Needs test-direct-session.sh (the session steam-game-mode-direct). Void recipe, step 14.
# Previous (Spanish) name: probar-inicio-automatico.sh.
#   sudo sh common/steam/test-autologin.sh            enables (valid on reboot)
#   sudo sh common/steam/test-autologin.sh --remove   leaves it as it came (--quitar also works)
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
CONF=/etc/lightdm/lightdm.conf
U=$TARGET_USER
cp "$CONF" "$CONF.bak"
if is_remove "${1:-}"; then
    sed -i 's/^autologin-user=.*/autologin-user=anon/; s/^autologin-session=.*/autologin-session=xfce/' "$CONF"
else
    [ -f /usr/share/wayland-sessions/steam-game-mode-direct.desktop ] || {
        t "!! The direct session is missing: run test-direct-session.sh first"; exit 1; }
    sed -i "s/^autologin-user=.*/autologin-user=$U/; s/^autologin-session=.*/autologin-session=steam-game-mode-direct/" "$CONF"
fi
t "== differences in %s:" "$CONF"; diff "$CONF.bak" "$CONF" || true
grep -n '^autologin' "$CONF"
t "== Reboot to test it."
