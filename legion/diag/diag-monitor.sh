#!/bin/sh
# Legion Go 2: diagnosis of "I boot with the monitor connected and no image comes out until I disconnect and
# connect the cable" (2026-10-04). Run it AT THAT MOMENT, without touching the cable, from another machine:
#   ssh lego   and then   sudo sh <repo>/legion/diag/diag-monitor.sh
# It leaves everything in ~/diag-monitor.log (of the user who called sudo). The report is in English.
# Previous name: diag-monitor.sh (unchanged).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
U=$TARGET_USER; H=$TARGET_HOME; OUT="$H/diag-monitor.log"
{
echo "== $(date '+%F %T')  uptime: $(cut -d' ' -f1 /proc/uptime) s"
echo "== kernel: $(cat /proc/cmdline)"
echo "== connectors (status / enabled / dpms / current mode)"
for c in /sys/class/drm/card*-*; do
    [ -e "$c/status" ] || continue
    printf '%s: %s / %s / %s / %s\n' "${c##*/}" "$(cat "$c"/status)" "$(cat "$c"/enabled 2>/dev/null)" \
        "$(cat "$c"/dpms 2>/dev/null)" "$(head -1 "$c"/modes 2>/dev/null)"
done
echo "== GPU busy: $(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null)%"
echo "== profile: $(cat /sys/firmware/acpi/platform_profile 2>/dev/null)"
echo "== processes that use the most CPU"
top -b -n 2 -d 1 | awk '/^top -/{n++} n==2' | sed -n '7,22p'
echo "== graphical sessions"
pgrep -a -f 'gamescope|labwc|Xorg|steam ' | cut -c1-150
echo "== amdgpu state (screens)"
for f in /sys/kernel/debug/dri/0/DP-1/link_settings /sys/kernel/debug/dri/0/DP-1/output_bpc \
         /sys/kernel/debug/dri/0/state; do
    [ -r "$f" ] && { echo "-- $f"; head -60 "$f"; }
done
echo "== kernel: amdgpu, drm, DP, usb-c (the whole boot)"
dmesg -T | grep -i -E 'amdgpu|\[drm|drm:|dp-?[0-9]|displayport|typec|ucsi|mst|link train|hpd|edid|thunderbolt|usb4' | tail -150
echo "== last lines of Game Mode"
tail -n 60 "$H/.local/state/steam-game-mode.log" | sed 's/\x1b\[[0-9;]*m//g' | grep -v -E 'brightness|mod.rt'
} > "$OUT" 2>&1
chown "$U": "$OUT"; t "done: %s" "$OUT"
