#!/bin/sh
# greeter-without-atspi.sh — at-spi-enabled=false in /etc/lightdm/lightdm-gtk-greeter.conf.
# The login screen starts the accessibility bus (at-spi) and, when closing, waits for it: if that
# bus is left with a dead dbus, the greeter does not die with lightdm's SIGTERM (2026-10-03: one
# took 88 s, another was still alive after 13 min). With Xfce it is not noticed; with the Game Mode session
# (Wayland), when it finally dies, lightdm sees "Active display server stopped", launches another login
# screen and LOCKS the gamescope session, which then cannot be unlocked.
# No screen reader (Orca) is used. docs/4-sessions/1-login-and-modes.md and 14.
# Previous (Spanish) name: greeter-sin-atspi.sh.
#   sudo sh common/steam/greeter-without-atspi.sh            turns it off (leaves .bak)
#   sudo sh common/steam/greeter-without-atspi.sh --remove   turns it back on
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
C=/etc/lightdm/lightdm-gtk-greeter.conf
cp "$C" "$C.bak"
sed -i '/^at-spi-enabled[[:space:]]*=/d' "$C"
is_remove "${1:-}" || sed -i '/^\[greeter\]/a at-spi-enabled = false' "$C"
t "== differences:"; diff "$C.bak" "$C" || true
t "== Reboot so that no old login screen is left hanging (there is one from before)."
