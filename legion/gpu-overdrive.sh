#!/bin/sh
# Legion Go 2: amdgpu overdrive, for Steam's "Manual GPU Clock" (steamos-manager writes to
# pp_od_clk_voltage, which without bit 0x4000 of ppfeaturemask gives "Invalid argument").
# Factory 0xfff7bfff → 0xfff7ffff (only that bit is added). The kernel marks the system as
# "tainted" (overdrive): it is a warning, it changes nothing by itself.
# It goes with the [gpu_performance] section of steamos-manager's profile
# (common/steam/steamos-manager/install-steamos-manager.sh leaves it as it comes). With the manual clock
# DISABLED in Steam, steamos-manager's log shows "Error setting manual GPU clock: Invalid argument" unless
# the set_clocks patch is installed (recipe, Troubleshooting "Performance"). 2026-10-08: it was removed
# due to a misunderstanding and put back.
# It goes in modprobe.d (amdgpu is a module) and not in GRUB: common/boot/silent-boot.sh rewrites the whole
# kernel line. dracut copies /etc/modprobe.d into the initramfs: the one of ALL installed kernels is
# rebuilt (2026-10-08: before, only that of the running kernel, and the 6.12 fallback, rebuilt later
# with the .conf in place, kept it).
# Previous name: gpu-overdrive.sh (unchanged).
# Usage: sudo sh legion/gpu-overdrive.sh [--remove]   and reboot     
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
F=/etc/modprobe.d/amdgpu-overdrive.conf
if is_remove "${1:-}"; then
    rm -f "$F"
else
    echo 'options amdgpu ppfeaturemask=0xfff7ffff' > "$F.tmp" && mv "$F.tmp" "$F"
fi
for v in /boot/vmlinuz-*; do
    K=${v#/boot/vmlinuz-}
    [ -d "/usr/lib/modules/$K" ] || continue
    t "== initramfs of %s" "$K"
    dracut --force "/boot/initramfs-$K.img" "$K"
    if lsinitrd "/boot/initramfs-$K.img" | grep -q 'etc/modprobe.d/amdgpu-overdrive.conf'; then
        t "   it carries amdgpu-overdrive.conf"
    else
        t "   without amdgpu-overdrive.conf"
    fi
done
t "done; reboot. Check: cat /sys/module/amdgpu/parameters/ppfeaturemask"
t "  → 0xfff7bfff (factory, no overdrive) or 0xfff7ffff (with overdrive)"
