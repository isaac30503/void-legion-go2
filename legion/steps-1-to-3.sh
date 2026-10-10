#!/bin/bash
# steps-1-to-3.sh — steps 1–3 of the Legion recipe (docs/void-legion-go2.md, "2–3. System up to date,
# keyboard and SSH"): xbps first and then the whole system, the keyboard (X and console) and SSH + mDNS.
# Previous (Spanish) name: pasos-1-a-3.sh.
#   sudo bash legion/steps-1-to-3.sh        then reboot (it ends with "DONE OK")
# Keyboard: KEYBOARD_LAYOUT / KEYBOARD_VARIANT / CONSOLE_KEYMAP of local.env (on the Legion: us,
# intl and us-acentos; local.env.example has them). Log: ~/steps-1-to-3.log of the user who ran sudo.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
need_env KEYBOARD_LAYOUT CONSOLE_KEYMAP
exec > >(tee -a "$TARGET_HOME/steps-1-to-3.log") 2>&1
t "=== %s start" "$(date)"
t "--- 1. mirror: %s" "$(xbps-query -L | grep -o "https[^ ]*" | head -1)"
xbps-install -Syu xbps
xbps-install -Syu -y
t "--- 2. keyboard: %s%s (X) and %s (console)" "$KEYBOARD_LAYOUT" "${KEYBOARD_VARIANT:++$KEYBOARD_VARIANT}" "$CONSOLE_KEYMAP"
mkdir -p /etc/X11/xorg.conf.d
{
    printf '%s\n' 'Section "InputClass"' '    Identifier "system-keyboard"' '    MatchIsKeyboard "on"'
    printf '    Option "XkbLayout" "%s"\n' "$KEYBOARD_LAYOUT"
    [ -n "${KEYBOARD_VARIANT:-}" ] && printf '    Option "XkbVariant" "%s"\n' "$KEYBOARD_VARIANT"
    printf '%s\n' 'EndSection'
} > /etc/X11/xorg.conf.d/00-keyboard.conf
cat /etc/X11/xorg.conf.d/00-keyboard.conf
cp /etc/rc.conf /etc/rc.conf.bak
sed -i "s/^KEYMAP=.*/KEYMAP=$CONSOLE_KEYMAP/" /etc/rc.conf
grep ^KEYMAP /etc/rc.conf
t "--- 3. ssh + mDNS"
xbps-install -Sy openssh avahi nss-mdns
ln -sf /etc/sv/dbus /var/service/
ln -sf /etc/sv/sshd /var/service/
ln -sf /etc/sv/avahi-daemon /var/service/
# (no "sv status" here: runit takes up to 5 s to see a new service and, with set -e, the
#  "unable to open supervise/ok" cut the script. It is checked after the reboot.)
t "--- .new-* of /etc (do NOT apply):"; ls /etc/*.new-* /etc/default/*.new-* 2>/dev/null || t "none"
t "=== %s DONE OK. Reboot: sudo reboot" "$(date)"
