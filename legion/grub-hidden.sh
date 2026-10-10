#!/bin/sh
# grub-hidden.sh — boot straight into the newest kernel, without the GRUB menu or a wait and without GRUB
# turning off the firmware logo (Legion recipe, step 8; the user's decision, 2026-10-04):
#   - GRUB_TIMEOUT=0 + GRUB_TIMEOUT_STYLE=hidden: no menu; the first entry is the newest kernel;
#   - GRUB_TERMINAL_OUTPUT=console: GRUB does not change the video mode for the theme (with the menu
#     hidden it is not needed) → the firmware logo does not go off;
#   - GRUB_GFXPAYLOAD_LINUX=keep: the kernel boots in the mode the firmware left;
#   (amdgpu.seamless=1 was tried on 2026-10-04 against a Plymouth flicker and removed when going back to
#    a boot without Plymouth: this script deletes it if it finds it.)
# It does not touch the firmware. Without a menu: for the fallback kernel, "--remove" from the system; the
# Windows on the XS1000, from the Legion's firmware boot menu.
# Previous (Spanish) name: grub-oculto.sh.
#   sudo sh legion/grub-hidden.sh            applies
#   sudo sh legion/grub-hidden.sh --remove   back to the menu with the theme, 5 s (--quitar also works)
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
C=/etc/default/grub
cp "$C" "$C.bak"
sed -i '/^GRUB_TIMEOUT_STYLE=/d; /^GRUB_TERMINAL_OUTPUT=/d; /^GRUB_GFXPAYLOAD_LINUX=/d' "$C"
sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\) amdgpu.seamless=1/\1/' "$C"
if is_remove "${1:-}"; then
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' "$C"
else
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$C"
    sed -i '/^GRUB_TIMEOUT=/a GRUB_TIMEOUT_STYLE=hidden\nGRUB_TERMINAL_OUTPUT=console\nGRUB_GFXPAYLOAD_LINUX=keep' "$C"
fi
t "== %s (what this script sets):" "$C"
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|TERMINAL_OUTPUT|GFXPAYLOAD_LINUX|CMDLINE_LINUX_DEFAULT)=' "$C" | sed 's/^/   /'
update-grub
t "== in grub.cfg:"; grep -E 'set timeout|terminal_output|gfxpayload|seamless' /boot/grub/grub.cfg | sort -u | sed 's/^/   /'
t "== it will boot: %s" "$(grep -m1 -E '^menuentry' /boot/grub/grub.cfg | cut -d"'" -f2)"
