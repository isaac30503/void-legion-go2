#!/bin/sh
# ideapad-bfq.sh — IdeaPad only: the BFQ I/O scheduler for internal rotating disks (its WD10JPCX, by SATA).
# BFQ shares the mechanical disk between processes and favours the interactive ones: with mq-deadline a big read or
# write could stall the desktop. Only disks behind the internal SATA controller (DRIVERS=="ahci"): the XS1000 by USB
# also says rotational=1 (its adapter does) and BFQ only costs CPU on an SSD (rule corrected on 2026-10-09). Not
# ENV{ID_BUS}: 60-persistent-storage.rules sets it, and udev reads it after this file (alphabetical order).
# The Legion has an NVMe disk: nothing to do there (docs/2-base-system/3-storage.md).
#   sudo sh common/disk/ideapad-bfq.sh            writes /etc/udev/rules.d/60-ideapad-ioscheduler.rules, applies it now
#   sudo sh common/disk/ideapad-bfq.sh --remove   removes it; the internal disks go back to mq-deadline (the kernel's)
# The IdeaPad's ideapad-al-dia.sh --disco (its recipe in Common, step 16) wrote the same rule before.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
F=/etc/udev/rules.d/60-ideapad-ioscheduler.rules
if is_remove "${1:-}"; then
    rm -f "$F"
    for q in /sys/block/sd*/queue/scheduler; do
        [ -e "$q" ] || continue
        case "$(cat "$q")" in *"[bfq]"*) echo mq-deadline > "$q" ;; esac
    done
    t "removed: the disks use mq-deadline"
else
    [ -f "$F" ] && cp "$F" "$F.bak"
    cat > "$F.tmp" <<'EOR'
# common/disk/ideapad-bfq.sh (void-legion-go2): BFQ only for INTERNAL rotating disks (SATA by AHCI: the WD10JPCX).
# USB disks (the XS1000 says rotational=1 because of its adapter), SSDs and NVMe keep the default.
# Remove: sudo sh common/disk/ideapad-bfq.sh --remove
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", DRIVERS=="ahci", ATTR{queue/scheduler}="bfq"
EOR
    mv "$F.tmp" "$F"
    udevadm control --reload
    udevadm trigger --action=change --subsystem-match=block --sysname-match='sd[a-z]'
    udevadm settle -t 30
fi
t "== state:"; grep -H . /sys/block/sd*/queue/scheduler 2>/dev/null || true
