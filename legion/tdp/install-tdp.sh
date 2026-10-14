#!/bin/bash
# Legion Go 2: fine TDP. Builds with DKMS the modules lenovo-wmi-gamezone and lenovo-wmi-other (plus
# helpers, events and capdata01), which are in the normal 6.18 kernel but Void does not enable. They give
# the "custom" profile of platform_profile and /sys/class/firmware-attributes/lenovo-wmi-other-0 (power
# limits ppt_*), which is what steamos-manager uses. DKMS rebuilds them for every new 6.18 kernel.
# Previous (Spanish) name: instalar-tdp.sh.
# Usage: sudo bash legion/tdp/install-tdp.sh [--remove]   (with the lenovo-wmi-tdp/ folder next to it)
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
N=lenovo-wmi-tdp; V=6.18.55
SRC="$(dirname "$(readlink -f "$0")")/$N"
MODS="lenovo-wmi-gamezone lenovo-wmi-other lenovo-wmi-capdata01 lenovo-wmi-events lenovo-wmi-helpers"

if is_remove "${1:-}"; then
    modprobe -r $MODS || true
    dkms remove -m $N -v $V --all || true
    rm -rf "/usr/src/$N-$V"
    t "removed (dkms and the headers stay)"; exit 0
fi

[ -f "$SRC/dkms.conf" ] || { t "missing %s" "$SRC"; exit 1; }
K=$(uname -r)
case "$K" in 6.18.*) ;; *) t "boot the 6.18 kernel first (now: %s)" "$K"; exit 1;; esac

# 1. DKMS and the headers of the running kernel
xbps-install -Sy dkms "linux${K%.*}-headers"      # 6.18.55_1 → linux6.18-headers

# 2. Sources in /usr/src and build (if they were already there, they are redone)
dkms remove -m $N -v $V --all >/dev/null 2>&1 || true
rm -rf "/usr/src/$N-$V"; cp -r "$SRC" "/usr/src/$N-$V"
dkms install -m $N -v $V -k "$K"

# 3. Load (at boot they load by themselves: they go by the firmware's WMI GUIDs)
modprobe lenovo-wmi-other
modprobe lenovo-wmi-gamezone
sleep 1

# 4. Check
dkms status -m $N
lsmod | grep -E '^lenovo_wmi' || true
for p in /sys/class/platform-profile/*; do echo "$(cat "$p"/name): $(cat "$p"/choices) → $(cat "$p"/profile)"; done
A=/sys/class/firmware-attributes/lenovo-wmi-other-0/attributes
if [ -d $A ]; then
    for a in $A/*/; do a=${a%/}; printf '%-16s %-8s min %-4s max %-4s (%s)\n' "${a##*/}" \
        "$(cat "$a"/current_value 2>/dev/null)" "$(cat "$a"/min_value 2>/dev/null)" "$(cat "$a"/max_value 2>/dev/null)" \
        "$(cat "$a"/display_name 2>/dev/null)"; done
else
    t "there is NO %s" "$A"; dmesg | grep -iE 'lenovo|wmi' | tail -20
fi
