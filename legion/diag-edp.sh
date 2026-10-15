#!/bin/sh
# Legion Go 2: state of the internal screen (eDP-1) according to amdgpu, to compare "black" against
# "fine" when going from Game Mode to the desktop (2026-10-04). Read-only (mounts debugfs if missing).
#   sudo sh legion/diag-edp.sh black      (with the internal screen black)
#   sudo sh legion/diag-edp.sh fine       (after switching workspace)
# Leaves ~/diag-edp-<label>.txt. Previous name: diag-edp.sh (unchanged; its labels were negra|bien, and
# the two results of 2026-10-04 are archived with those names in the private repository, archive/2026-10-14/logs/legion-diagnostics-2026-10-04/).
# The report is written in English (it is a data file).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
U=$TARGET_USER; H=$TARGET_HOME; OUT="$H/diag-edp-${1:-x}.txt"
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug
E=/sys/kernel/debug/dri/0000:c2:00.0/eDP-1
{
date '+%F %T'
for f in "$E"/*; do
    case "${f##*/}" in trigger_hotplug|test_pattern|edid_override|force|sdp_message) continue;; esac
    [ -r "$f" ] || continue
    echo "== ${f##*/}: $(cat "$f" 2>&1 | tr '\n' ' ' | cut -c1-300)"
done
for b in /sys/class/backlight/*; do
    echo "== backlight ${b##*/}: brightness=$(cat "$b"/brightness) actual=$(cat "$b"/actual_brightness) bl_power=$(cat "$b"/bl_power)"
done
C=/sys/class/drm/card0-eDP-1
echo "== sysfs eDP-1: status=$(cat $C/status) enabled=$(cat $C/enabled) dpms=$(cat $C/dpms)"
echo "== dmesg (last 40 of amdgpu/drm)"
dmesg | grep -i -E 'amdgpu|drm' | tail -40
} > "$OUT" 2>&1
chown "$U": "$OUT"; t "done: %s" "$OUT"
