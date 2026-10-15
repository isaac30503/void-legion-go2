#!/bin/bash
# GRUB on the Legion (recipe docs/recipe/step-08-grub.md, step 8): entry for the Windows on the XS1000,
# without the ISO's kernel, silent boot and the void-xterm theme.   sudo bash legion/grub-root.sh
# Previous name: grub-root.sh (unchanged). Log: ~/grub-root.log.
# The UUID of the XS1000's EFI partition (sda1 "SYSTEM") is XS1000_EFI_UUID in local.env.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
need_env XS1000_EFI_UUID
exec > >(tee -a "$TARGET_HOME/grub-root.log") 2>&1
B="$REPO_ROOT/common"
UUID_WIN=$XS1000_EFI_UUID          # sda1 "SYSTEM": EFI partition of the XS1000's Windows
t "=== %s start" "$(date)"

t "--- 1. Windows loader on the XS1000's EFI (read-only)"
M=$(mktemp -d); WIN=0
if mount -o ro "/dev/disk/by-uuid/$UUID_WIN" "$M" 2>/dev/null; then
    [ -f "$M/EFI/Microsoft/Boot/bootmgfw.efi" ] && WIN=1 && ls -l "$M/EFI/Microsoft/Boot/bootmgfw.efi"
    umount "$M"
else t "   the XS1000 is not connected (UUID %s)" "$UUID_WIN"; fi
rmdir "$M"

t "--- 2. Windows entry in /boot/grub/custom.cfg"
if [ $WIN = 1 ]; then
    [ -e /boot/grub/custom.cfg ] && cp /boot/grub/custom.cfg /boot/grub/custom.cfg.bak
    TITLE=$(t "Windows (external disk Kingston XS1000)")     # the menu title, in the system's language
    cat > /boot/grub/custom.cfg <<CFG
# Windows on the external Kingston XS1000 SSD (Legion recipe, step 8). The Legion boots the
# XS1000 from its firmware, so GRUB sees it and jumping to its loader is enough (the IdeaPad, on
# the other hand, needs the UEFI shell with OpenCore drivers). Loaded by 41_custom: it survives
# grub-mkconfig. BEFORE choosing it: unmount Common. In Windows, shut down with Shift + Shut down.
menuentry "$TITLE" {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root $UUID_WIN
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
CFG
    grub-script-check /boot/grub/custom.cfg && t "   syntax: fine"
else t "   the entry is NOT added: %s was not found" '\EFI\Microsoft\Boot\bootmgfw.efi'; fi

t "--- 3. the ISO's kernel (6.12.11): 6.12.111 stays as the fallback"
vkpurge list
vkpurge rm 6.12.11_1 || true

t "--- 4. silent boot"
sh "$B/boot/silent-boot.sh"

t "--- 5. GRUB theme (regenerates the menu)"
bash "$B/grub-theme/install-theme.sh"
grep -n "^GRUB_" /etc/default/grub
t "=== %s DONE OK. Unmount Common before trying Windows: udisksctl unmount -b /dev/sda4" "$(date)"
