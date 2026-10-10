#!/bin/sh
# bluetooth-at-boot.sh — unblocks Bluetooth (rfkill) at every boot.
# bluetoothd already starts with runit, but the laptop may boot with Bluetooth blocked
# by software: the ideapad_bluetooth block is kept by the firmware (persistent=1) and on
# 2026-10-02, after a reboot, it came back blocked (ideapad_bluetooth and hci0). A block marked with
# "rfkill unblock bluetooth" is added to /etc/rc.local (runit runs it in stage 2, before the services; it is
# a configuration file: it survives updates).
# Turning it off by hand (blueman) still works; on reboot it comes back on.
# The Legion does NOT need it (it does not come with Bluetooth blocked: Legion recipe, steps 5–12); kept in
# case it ever comes back blocked after a reboot.
# Previous (Spanish) name: bluetooth/bluetooth-al-arrancar.sh (block "# >>> bluetooth al arrancar": applying or
# --remove also removes the old block).
#   sudo sh common/bluetooth/bluetooth-at-boot.sh            adds it (leaves /etc/rc.local.bak)
#   sudo sh common/bluetooth/bluetooth-at-boot.sh --remove   removes it (--quitar also works)
# Void recipe, step 9 (Bluetooth).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
RC=/etc/rc.local
BEGIN='# >>> bluetooth at boot'; END='# <<< bluetooth at boot'
BEGIN_OLD='# >>> bluetooth al arrancar'; END_OLD='# <<< bluetooth al arrancar'
cp "$RC" "$RC.bak"
sed -i "/^$BEGIN/,/^$END/d; /^$BEGIN_OLD/,/^$END_OLD/d" "$RC"
if ! is_remove "${1:-}"; then
    cat >> "$RC" <<EOS
$BEGIN (recipe, step 9; remove: sudo sh common/bluetooth/bluetooth-at-boot.sh --remove)
rfkill unblock bluetooth 2>/dev/null || true
$END
EOS
    rfkill unblock bluetooth     # right now too
fi
sh -n "$RC" && t "== syntax of %s: fine" "$RC"
t "== differences:"; diff "$RC.bak" "$RC" || true
t "== state:"; rfkill
