#!/bin/sh
# install-power-button.sh — the power button in both modes (2026-10-14): a press opens the power menu, held ~3 s
# it suspends (power-button explains why it is not the Deck's way on the Legion Go 2).
#   /usr/local/bin/power-button                          the program (Python, started by each session)
#   /etc/udev/rules.d/70-power-button.rules              the button's devices: marked and readable by the session
#   /etc/elogind/logind.conf.d/50-power-button.conf      elogind ignores the key (its default powers off)
#   /etc/xdg/autostart/power-button.desktop              desktop: started with Xfce (X11 and Wayland)
# Game Mode starts it from its launcher (install-game-mode.sh; repeat that one after installing this).
# Reloads udev and elogind: valid at once for the next login, or after a reboot.
# Usage: sudo sh common/power-button/install-power-button.sh [--remove]
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
H=$(dirname "$(readlink -f "$0")")
BIN=/usr/local/bin/power-button
RULE=/etc/udev/rules.d/70-power-button.rules
CONF=/etc/elogind/logind.conf.d/50-power-button.conf
AUTO=/etc/xdg/autostart/power-button.desktop
reload() {
    udevadm control --reload
    udevadm trigger --subsystem-match=input --action=change
    pkill -HUP -x elogind-daemon || true   # elogind rereads its configuration (no session is touched)
}
if is_remove "${1:-}"; then
    rm -f "$BIN" "$RULE" "$CONF" "$AUTO"
    pkill -x power-button || true
    reload
    t "removed (elogind powers off with the button again: its default)"
    exit 0
fi
python3 -c 'import os; os.timerfd_create' 2>/dev/null || { t "!! needs Python >= 3.13 (os.timerfd_create)"; exit 1; }
install -m 755 "$H/power-button" "$BIN.tmp" && mv "$BIN.tmp" "$BIN"
mkdir -p "${RULE%/*}" && install -m 644 "$H/70-power-button.rules" "$RULE"   # the folder may not exist (Legion)
mkdir -p "${CONF%/*}" && install -m 644 "$H/50-power-button.conf" "$CONF"
install -m 644 "$H/power-button.desktop" "$AUTO"
reload
ls -l "$BIN" "$RULE" "$CONF" "$AUTO"
t "== check"
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey
for f in /run/udev/data/c13:*; do grep -q '^E:POWER_BUTTON=1$' "$f" && t "   marked: %s" "$(grep '^N:' "$f" | cut -c3-)"; done
t "Log out and back in (or reboot) so that the session starts it; log: ~/.local/state/power-button.log"
