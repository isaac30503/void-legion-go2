#!/bin/sh
# install-xfce-wayland.sh — the session "Xfce (Wayland)": the same Xfce, with labwc handling the
# windows instead of xfwm4 (Xfce 4.20: startxfce4 --wayland uses labwc). Since 2026-10-03 it is
# THE desktop: Game Mode's "Switch to Desktop" enters it (switch-mode-root desktop)
# and Xfce X11 stays as the fallback. You enter and leave without password with the launchers below.
#   - package labwc (Xwayland and gtk-layer-shell are already there, from Steam and from Xfce);
#   - ~/.config/xfce4/labwc/{rc.xml,environment,autostart,lock}: Omarchy-style shortcuts, focus that
#     follows the mouse, 8 px gap, new windows almost maximized (dialogs centered), rule
#     for Firefox (labwc's bar), keyboard from 00-keyboard.conf, Volantes cursor, and
#     ~/.Xresources loaded in Xwayland (xterm). "lock" = startxfce4 does not rewrite environment;
#   - ~/.local/bin/brightness: brightness keys through elogind (SetBrightness, without root);
#   - ~/.local/bin/wallpaper-watcher: asks xfdesktop for the wallpaper again when the screens change
#     (event-driven; without it, when coming from Game Mode the internal screen was left without wallpaper);
#   - ~/.local/share/themes/Orchis-Teal-Dark-Compact/labwc: Orchis for labwc (labwc-theme.sh);
#   - launchers "Wayland Desktop" and "X11 Desktop" (finder, Super+Space; Spanish names in Name[es]).
# Needs install-passwordless-switch.sh with desktop = Wayland and desktop-x11 (docs/5-desktop/1-xfce.md).
# What does NOT work on Wayland (X11 only): window-focus and window-snap (xdotool; here
# labwc redoes them: Super+arrows by direction only between snapped ones), the Docklike's per-workspace
# filter (labwc does not give each window's workspace), xfce4-screensaver (no screen
# lock) and the shortcuts of xfce4-keyboard-shortcuts (on Wayland they go in labwc's rc.xml).
# Previous (Spanish) name: instalar-xfce-wayland.sh (it installed ~/.local/bin/brillo and fondo-vigilante, and
# the launchers escritorio-wayland.desktop / escritorio-x11.desktop: installing replaces them).
#   sudo sh common/xfce-wayland/install-xfce-wayland.sh            installs (or redoes labwc's configuration)
#   sudo sh common/xfce-wayland/install-xfce-wayland.sh --remove   removes launchers and configuration (leaves labwc)
# docs/5-desktop/1-xfce.md.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
U=$TARGET_USER
H=$TARGET_HOME
D=$(cd "$(dirname "$0")" && pwd)
CFG="$H/.config/xfce4/labwc"
LW=/usr/share/applications/desktop-wayland.desktop
LX=/usr/share/applications/desktop-x11.desktop
OLD="/usr/share/applications/escritorio-wayland.desktop /usr/share/applications/escritorio-x11.desktop
     $H/.local/bin/brillo $H/.local/bin/fondo-vigilante"

if is_remove "${1:-}"; then
    rm -f "$LW" "$LX" "$H/.local/bin/brightness" "$H/.local/bin/wallpaper-watcher" $OLD
    rm -rf "$CFG" "$H/.local/share/themes/Orchis-Teal-Dark-Compact/labwc"
    t "== removed the launchers, %s and ~/.local/bin/brightness (labwc stays installed:" "$CFG"
    t "   sudo xbps-remove labwc). CAREFUL: \"desktop\" is still Wayland in switch-mode-root;"
    t "   to go back to X11: sudo /usr/local/bin/switch-mode-root desktop-x11"
    exit 0
fi

grep -q 'desktop-x11' /usr/local/bin/switch-mode-root 2>/dev/null || {
    t "!! switch-mode-root is missing or old (without desktop-x11): first, install-passwordless-switch.sh"
    exit 1; }

t "== 1. labwc"
command -v labwc >/dev/null || xbps-install -Sy labwc
labwc --version

t "== 2. labwc's configuration for Xfce (%s)" "$CFG"
sudo -u "$U" mkdir -p "$CFG" "$H/.local/bin"
for f in rc.xml environment autostart; do
    sudo -u "$U" install -m 644 "$D/labwc/$f" "$CFG/$f"
done
# Keyboard: X's (00-keyboard.conf, docs/2-base-system/1-system.md), not fixed. latam on the IdeaPad (without variant: the
# file stays the same as the backed-up one); us + intl on the Legion (2026-10-03).
KB=/etc/X11/xorg.conf.d/00-keyboard.conf
LAY=$(sed -n 's/.*"XkbLayout"[[:space:]]*"\([^"]*\)".*/\1/p' "$KB" 2>/dev/null || true)
VAR=$(sed -n 's/.*"XkbVariant"[[:space:]]*"\([^"]*\)".*/\1/p' "$KB" 2>/dev/null || true)
if [ -n "$LAY" ]; then
    sed -i "s/^XKB_DEFAULT_LAYOUT=.*/XKB_DEFAULT_LAYOUT=$LAY/" "$CFG/environment"
    if [ -n "$VAR" ]; then sed -i "/^XKB_DEFAULT_LAYOUT=/a XKB_DEFAULT_VARIANT=$VAR" "$CFG/environment"; fi
fi
grep '^XKB_' "$CFG/environment" | sed 's/^/   /'
sudo -u "$U" touch "$CFG/lock"
sudo -u "$U" install -m 755 "$D/brightness" "$H/.local/bin/brightness"
sudo -u "$U" install -m 755 "$D/wallpaper-watcher" "$H/.local/bin/wallpaper-watcher"
rm -f $OLD
ls -la "$CFG" "$H/.local/bin/brightness" "$H/.local/bin/wallpaper-watcher"

t "== 2b. Orchis theme for labwc's borders (labwc-theme.sh, from the xfwm4 one)"
sudo -u "$U" env HOME="$H" sh "$D/labwc-theme.sh"

t "== 3. launchers"
cat > "$LW" <<'EOF'
[Desktop Entry]
Name=Wayland Desktop
Name[es]=Escritorio Wayland
Comment=Switch to Xfce on Wayland (labwc), the normal desktop, without password
Comment[es]=Pasar a Xfce sobre Wayland (labwc), el escritorio normal, sin contraseña
Exec=sudo -n /usr/local/bin/switch-mode-root desktop
Icon=preferences-desktop-display
Terminal=false
Type=Application
Categories=System;
EOF
cat > "$LX" <<'EOF'
[Desktop Entry]
Name=X11 Desktop
Name[es]=Escritorio X11
Comment=Switch to Xfce on X11 (xfwm4), the fallback one, without password
Comment[es]=Pasar a Xfce sobre X11 (xfwm4), el de respaldo, sin contraseña
Exec=sudo -n /usr/local/bin/switch-mode-root desktop-x11
Icon=preferences-desktop-display
Terminal=false
Type=Application
Categories=System;
EOF
ls -la "$LW" "$LX"

t "== check"
sudo -n -u "$U" sudo -n /usr/local/bin/switch-mode-root --check && t "   %s can switch mode without password" "$U"
t "== Done. Finder (Super+Space) → 'Wayland Desktop' (it closes the current session: save"
t "   first). X11, as the fallback: 'X11 Desktop'. Game Mode's 'Switch to Desktop' → Wayland."
