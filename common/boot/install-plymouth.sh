#!/bin/sh
# install-plymouth.sh — the Lenovo logo (the firmware's BGRT) on screen at boot until the
# login screen (not at shutdown: see silent-boot.sh), with Void's symbol spinning
# below. Plymouth with the theme "bgrt-void": the package's "bgrt" with the frames of the loading
# circle changed (plymouth-void/generate.py). Void's runit does not integrate Plymouth, so it is
# done here:
#   - initramfs with Plymouth (dracut's module 45plymouth) and "splash" in the kernel line;
#   - lightdm closes Plymouth by itself (it knows how to do it by default). As Plymouth is on console 1,
#     lower than its minimum-vt (7), it does not reuse it: X stays on 7. Console 1 (the logo's) has no
#     text login, as a precaution (agetty-tty1 out; 2-6 stay, Ctrl+Alt+F2).
#     DO NOT close Plymouth before lightdm: on 2026-10-02 a "plymouth quit --retain-splash" in
#     /etc/sv/lightdm/conf left console 1 unable to switch console, X waiting for 7
#     forever and the machine stuck on the logo;
#   - the /etc/rc.conf block (silent-boot.sh, which respects "splash") also sends runit's warnings and
#     errors to Plymouth and removes it if the emergency console kicks in.
# Diagnosis if it gets stuck on the logo (over SSH): sudo sh diag-vt.sh (IdeaPad; not in this repository)
#   sudo sh common/boot/install-plymouth.sh            installs
#   sudo sh common/boot/install-plymouth.sh --remove   removes it (leaves the package installed)
# Void recipe, step 8. On the Legion it was tried and REMOVED (Legion recipe, step 8, "Plymouth"):
# in a reinstall it is not run; its --remove is part of how it was taken out.
# Previous (Spanish) name: arranque/instalar-plymouth.sh.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
GRUB=/etc/default/grub
LDM=/etc/sv/lightdm/conf
TTY1=/etc/runit/runsvdir/default/agetty-tty1
THEME=/usr/share/plymouth/themes/bgrt-void
BEGIN='# >>> plymouth'; END='# <<< plymouth'
HERE=$(dirname "$(readlink -f "$0")")

cp "$GRUB" "$GRUB.bak"
# The block of the first version (it closed Plymouth before lightdm: see above)
if [ -f "$LDM" ]; then
    cp "$LDM" "$LDM.bak"; sed -i "/^$BEGIN/,/^$END/d" "$LDM"
    [ -s "$LDM" ] || rm -f "$LDM" "$LDM.bak"
fi

if is_remove "${1:-}"; then
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\) splash"/\1"/' "$GRUB"
    if [ -d "$THEME" ]; then plymouth-set-default-theme bgrt; rm -rf "$THEME"; t "   theme bgrt-void removed"; fi
    sed -i '/^DeviceScale=1$/d' /etc/plymouth/plymouthd.conf
    [ -e "$TTY1" ] || ln -s /etc/sv/agetty-tty1 "$TTY1"
    t "   text login of console 1 given back"
else
    t "== 1. package and theme"
    command -v plymouthd >/dev/null || xbps-install -Sy plymouth plymouth-data
    command -v rsvg-convert >/dev/null || xbps-install -Sy librsvg-utils
    python3 -c 'import PIL' 2>/dev/null || xbps-install -Sy python3-Pillow
    # Panel scale (like the GRUB theme): 1366x768 → 1, 1920x1200 → 2. The frames are already made at that
    # size and Plymouth scales nothing (DeviceScale=1): on the Legion, with automatic scale
    # 2, it stretched the 56 px ones and the symbol came out blurry (2026-10-03).
    HEIGHT=$(head -1 /sys/class/drm/card*-eDP-*/modes /sys/class/drm/card*-LVDS-*/modes 2>/dev/null | grep -m1 -oE 'x[0-9]+$' | tr -d x)
    SCALE=$(( (${HEIGHT:-768} + 384) / 768 )); [ "$SCALE" -ge 1 ] || SCALE=1
    t "   panel %s px high: scale %s" "${HEIGHT:-768}" "$SCALE"
    python3 "$HERE/plymouth-void/generate.py" "$THEME" "$SCALE"     # Void's symbol spinning
    plymouth-set-default-theme bgrt-void
    # DeviceScale AFTER Theme: the reader of plymouth-set-default-theme (and of dracut, which uses it
    # to choose which theme to put in the initramfs) only looks at the FIRST key of [Daemon]; with
    # DeviceScale in front it does not see the theme and uses "spinner" (it happened on 2026-10-03).
    C=/etc/plymouth/plymouthd.conf
    sed -i '/^DeviceScale=/d' "$C"
    sed -i '/^Theme=bgrt-void$/a DeviceScale=1' "$C"
    grep -A3 '^\[Daemon\]' "$C" | sed 's/^/   /'
    t "   theme: %s" "$(plymouth-set-default-theme)"
    [ "$(plymouth-set-default-theme)" = bgrt-void ] || { t "!! Plymouth does not see the theme bgrt-void: the initramfs is NOT rebuilt"; exit 1; }

    t "== 2. kernel line: splash"
    grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]* splash"' "$GRUB" || \
        sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 splash"/' "$GRUB"

    t "== 3. console 1 for X (lightdm closes Plymouth): without text login on it"
    rm -f "$TTY1"
    ls /etc/runit/runsvdir/default | grep agetty | tr '\n' ' '; echo
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$GRUB"

t "== 4. /etc/rc.conf block (warnings on the logo and emergency console)"
sh "$HERE/silent-boot.sh" >/dev/null && t "   redone"

t "== 5. initramfs and menu"
dracut --force --regenerate-all
if [ -x /usr/local/share/grub-theme/install-theme.sh ]; then
    bash /usr/local/share/grub-theme/install-theme.sh | tail -8   # update-grub + repaint the background
elif [ -x /usr/local/share/grub-tema/instalar-tema.sh ]; then
    bash /usr/local/share/grub-tema/instalar-tema.sh | tail -8    # the old Spanish-named installation
else
    update-grub
fi
t "== check"
for i in /boot/initramfs-*.img; do
    printf '   %s: ' "$i"; lsinitrd "$i" 2>/dev/null | grep -q 'plymouthd' && t "with Plymouth" || t "without Plymouth"
done
