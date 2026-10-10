#!/bin/bash
# install-theme.sh — installs (or removes) the GRUB theme "void-xterm": style of the terminal,
# with ALL the text antialiased in the background image (GRUB only draws 1-bit fonts).
#   sudo bash common/grub-theme/install-theme.sh            installs / reinstalls / regenerates
#   sudo bash common/grub-theme/install-theme.sh --remove   back to the usual text menu (--quitar also works;
#                                                            also from its installed copy:
#                                                            sudo bash /usr/local/share/grub-theme/install-theme.sh --remove)
# What it does (Void recipe, step 8):
#   1. python3-Pillow and python3-fonttools (official; the generator uses them)
#   2. scripts in /usr/local/share/grub-theme/ (and the translations in /usr/local/share/void-legion/, so the
#      texts painted in the background follow the system's language)
#   3. /etc/default/grub (leaves .bak): GRUB_THEME, GRUB_GFXMODE, and without submenu or recovery
#      modes (the names go painted in the background: a submenu would come out invisible)
#   4. hooks /etc/kernel.d/post-{install,remove}/60-grub-theme: they regenerate the background every time
#      the menu changes because of a kernel (after Void's 50-grub)
#   5. generates the theme in /boot/grub/themes/void-xterm and regenerates the menu (update-grub)
# It does not touch custom.cfg (the Windows entry) or the firmware.
# Previous (Spanish) name: grub-tema/instalar-tema.sh (scripts in /usr/local/share/grub-tema, hooks
# 60-grub-tema and the block "# >>> tema void-xterm" in /etc/default/grub: installing or --remove also
# removes those).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
if [ -f "$R/lib/common.sh" ]; then
    . "$R/lib/common.sh"
    FROM_REPO=1
else    # the installed copy (outside the repository): only what it needs
    FROM_REPO=
    if [ -r /usr/local/lib/void-legion/i18n.sh ]; then . /usr/local/lib/void-legion/i18n.sh
    else t() { _f=$1; shift; printf -- "$_f\n" "$@"; }; fi
    is_remove() { case "${1:-}" in --remove|--quitar) return 0 ;; *) return 1 ;; esac; }
fi
[ "$(id -u)" = 0 ] || { t "Run it with sudo."; exit 1; }
HERE=$(dirname "$(readlink -f "$0")")
LIB=/usr/local/share/grub-theme
DEST=/boot/grub/themes/void-xterm
CONF=/etc/default/grub
TTF=/usr/local/share/fonts/jetbrains-blocks/JetBrainsMonoNFMBlocks-Bold.ttf
BEGIN='# >>> theme void-xterm'; END='# <<< theme void-xterm'
BEGIN_OLD='# >>> tema void-xterm'; END_OLD='# <<< tema void-xterm'

remove_block() {   # the new block, the old Spanish one and the loose lines of the first version
    sed -i "/^$BEGIN/,/^$END/d; /^$BEGIN_OLD/,/^$END_OLD/d; /^# Tema void-xterm/d; /^GRUB_THEME=/d; /^GRUB_GFXMODE=/d" "$CONF"
}
remove_old() {     # the Spanish-named scripts and hooks
    rm -rf /usr/local/share/grub-tema /etc/kernel.d/post-install/60-grub-tema /etc/kernel.d/post-remove/60-grub-tema
}

cp "$CONF" "$CONF.bak"
remove_block

if is_remove "${1:-}"; then
    rm -rf "$DEST" /etc/kernel.d/post-install/60-grub-theme /etc/kernel.d/post-remove/60-grub-theme
    remove_old
    [ "$HERE" = "$LIB" ] || rm -rf "$LIB"
    t "== theme, hooks and scripts removed"
    t "== differences in %s:" "$CONF"; diff "$CONF.bak" "$CONF" || true
    update-grub
    [ "$HERE" = "$LIB" ] && rm -rf "$LIB"      # last, when it runs from its installed copy
    exit 0
fi

t "== 1. packages"
python3 -c 'import PIL, fontTools' 2>/dev/null || xbps-install -Sy python3-Pillow python3-fonttools
[ -r "$TTF" ] || { t "%s is missing (copy of the font of step 10 of the recipe)" "$TTF"; exit 1; }

t "== 2. scripts in %s" "$LIB"
mkdir -p "$LIB"
if [ "$HERE" != "$LIB" ]; then
    cp "$HERE"/{build.py,ttf2pf2.py,read_pf2.py,install-theme.sh} "$LIB/"
fi
[ -n "$FROM_REPO" ] && install_i18n_system
remove_old

t "== 3. %s" "$CONF"
# Menu resolution: the machine's panel's (1366x768 on the IdeaPad, 1920x1200 on the Legion);
# build.py reads it from GRUB_GFXMODE and scales the theme to it.
MODE=$(head -1 /sys/class/drm/card*-eDP-*/modes /sys/class/drm/card*-LVDS-*/modes 2>/dev/null | grep -m1 -E '^[0-9]+x[0-9]+$')
MODE=${MODE:-1366x768}; t "   screen: %s" "$MODE"
cat >> "$CONF" <<EOF
$BEGIN (recipe, step 8; remove: sudo bash $LIB/install-theme.sh --remove)
GRUB_THEME="$DEST/theme.txt"
GRUB_GFXMODE=$MODE,auto
GRUB_DISABLE_SUBMENU=y
GRUB_DISABLE_RECOVERY=true
$END
EOF
diff "$CONF.bak" "$CONF" || true

t "== 4. kernel hooks"
for d in post-install post-remove; do
    cat > /etc/kernel.d/$d/60-grub-theme <<EOF
#!/bin/sh
# Regenerates the background of the GRUB theme void-xterm (the names of the entries go painted in
# it) after 50-grub regenerates the menu. It never makes the kernel installation fail.
# Void recipe, step 8. Set/removed by $LIB/install-theme.sh.
[ -f "$DEST/theme.txt" ] || exit 0
/usr/bin/python3 "$LIB/build.py" "$DEST" --from-grub >/dev/null || echo "60-grub-theme: GRUB theme disabled (text menu); see above" >&2
exit 0
EOF
    chmod 755 /etc/kernel.d/$d/60-grub-theme
done
ls -la /etc/kernel.d/post-install/60-grub-theme /etc/kernel.d/post-remove/60-grub-theme

t "== 5. theme and menu"
rm -rf "$DEST"; mkdir -p "$DEST"
python3 "$LIB/build.py" "$DEST" "preparing"     # creates the files (fonts: console, countdown) before update-grub
update-grub                                     # loads those fonts; menu without submenu
if ! python3 "$LIB/build.py" "$DEST" --from-grub; then   # background with the final entries
    t "!! The theme was left DISABLED: GRUB will show the normal text menu (see the reason above)."
fi
t "== entries painted in the background (they must be those of the menu, in this order):"
sed 's/^/   /' "$DEST/entries.txt"

t "== check"
grub-script-check /boot/grub/grub.cfg && t "   syntax of grub.cfg: fine"
grep -E 'loadfont|set theme|gfxmode' /boot/grub/grub.cfg | sed 's/^/   /' | head -8
grep -q 'submenu ' /boot/grub/grub.cfg && t "   CAREFUL: there is still a submenu!" || t "   no submenus: fine"
t "   theme files: %s" "$(ls "$DEST" | tr '\n' ' ')"
