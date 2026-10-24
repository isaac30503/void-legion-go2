#!/bin/sh
# install-xfce-mango.sh — the session "Xfce (mango)": the same Xfce as "Xfce (Wayland)", with mangowc placing the
# windows instead of labwc, in Omarchy's two layouts per workspace (Super+L): dwindle (each new window splits the
# focused one, right or down) and scroller (columns). Since 2026-10-23 (IdeaPad first) THE desktop where it is
# installed: switch-mode-root desktop (Game Mode's "Switch to Desktop") enters it; labwc stays one more mode
# (switch-mode-root desktop-labwc). docs/5-desktop/5-mango.md.
# It replaces niri's trial of the same day (niri cannot split a window: no dwindle): it removes its pieces.
#   - package mangowc (pulls scenefx and cJSON; Xwayland is built in, as in labwc);
#   - ~/.config/xfce4/mango/config.conf: light (no animations, blur, shadows or rounded corners), 8 px gap, focus that
#     follows the mouse, Omarchy's keybindings (tiling.lua) and labwc's programs, keyboard from 00-keyboard.conf,
#     Volantes cursor, ~/.Xresources in Xwayland and wallpaper-watcher (from install-xfce-wayland.sh);
#   - ~/.local/bin/mango-scratchpad: Super+S brings the scratchpad window you choose (a list when there are several);
#   - ~/.local/bin/mango-keys: Super+K shows the table of shortcuts, read from the configuration (as Omarchy's);
#   - /usr/local/bin/startxfce4-mango and /usr/share/wayland-sessions/xfce-mango.desktop: the session;
#   - launcher "mango Desktop" (finder, Super+Space; Spanish name in Name[es]).
# Needs install-xfce-wayland.sh (brightness, wallpaper-watcher) and install-passwordless-switch.sh with desktop-mango.
#   sudo sh common/xfce-wayland/install-xfce-mango.sh            installs (or redoes mango's configuration)
#   sudo sh common/xfce-wayland/install-xfce-mango.sh --remove   removes session, launcher and configuration (leaves
#                                                                the package: sudo xbps-remove mangowc)
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
U=$TARGET_USER
H=$TARGET_HOME
D=$(cd "$(dirname "$0")" && pwd)
CFG="$H/.config/xfce4/mango"
BIN=/usr/local/bin/startxfce4-mango
SES=/usr/share/wayland-sessions/xfce-mango.desktop
LN=/usr/share/applications/desktop-mango.desktop
DROP=/etc/xdg/lightdm/lightdm.conf.d/60-steam-mode.conf

if is_remove "${1:-}"; then
    if grep -q '^autologin-session=xfce-mango$' "$DROP" 2>/dev/null; then
        t "!! the current mode is Xfce (mango): first switch to another one (sudo /usr/local/bin/switch-mode-root desktop-labwc)"
        exit 1
    fi
    rm -f "$BIN" "$SES" "$LN" "$H/.local/bin/mango-scratchpad" "$H/.local/bin/mango-keys"
    rm -rf "${CFG:?}"
    t "== removed the session, the launcher and %s (mangowc stays installed: sudo xbps-remove mangowc)" "$CFG"
    exit 0
fi

grep -q 'desktop-mango' /usr/local/bin/switch-mode-root 2>/dev/null || {
    t "!! switch-mode-root is missing or old (without desktop-mango): first, install-passwordless-switch.sh"
    exit 1; }
[ -x "$H/.local/bin/wallpaper-watcher" ] && [ -x "$H/.local/bin/brightness" ] || {
    t "!! wallpaper-watcher or brightness are missing: first, install-xfce-wayland.sh"
    exit 1; }
for p in "$BIN" "$SES" "$LN"; do
    owner=$(xbps-query -o "$p" 2>/dev/null | head -1)
    [ -z "$owner" ] || { t "!! %s belongs to a package (%s): nothing was installed" "$p" "$owner"; exit 1; }
done

t "== 1. mangowc"
command -v mango >/dev/null || xbps-install -Sy mangowc
mango -v 2>&1 | head -1

t "== 2. mango's configuration for Xfce (%s)" "$CFG"
sudo -u "$U" mkdir -p "$CFG" "$H/.local/bin"
sudo -u "$U" install -m 755 "$D/mango/mango-scratchpad" "$H/.local/bin/mango-scratchpad"
sudo -u "$U" install -m 755 "$D/mango/mango-keys" "$H/.local/bin/mango-keys"
# Their Spanish: the user's copy of the catalogs (install_i18n_user, but for the target user: this runs as root).
_copy_i18n "$H/.local/share/void-legion" "$H/.local/share/void-legion/lib"
chown -R "$U:" "$H/.local/share/void-legion"
sudo -u "$U" install -m 644 "$D/mango/config.conf" "$CFG/config.conf.new"
# Keyboard: X's (00-keyboard.conf, docs/2-base-system/1-system.md), as labwc's environment: latam on the IdeaPad,
# us + intl on the Legion.
KB=/etc/X11/xorg.conf.d/00-keyboard.conf
LAY=$(sed -n 's/.*"XkbLayout"[[:space:]]*"\([^"]*\)".*/\1/p' "$KB" 2>/dev/null || true)
VAR=$(sed -n 's/.*"XkbVariant"[[:space:]]*"\([^"]*\)".*/\1/p' "$KB" 2>/dev/null || true)
if [ -n "$LAY" ]; then
    sed -i "s/^xkb_rules_layout=.*/xkb_rules_layout=$LAY/" "$CFG/config.conf.new"
    if [ -n "$VAR" ]; then sed -i "/^xkb_rules_layout=/a xkb_rules_variant=$VAR" "$CFG/config.conf.new"; fi
fi
if ! out=$(sudo -u "$U" mango -c "$CFG/config.conf.new" -p 2>&1); then
    printf '%s\n' "$out"; rm -f "$CFG/config.conf.new"
    t "!! mango does not accept the configuration: nothing was changed"
    exit 1
fi
sudo -u "$U" mv "$CFG/config.conf.new" "$CFG/config.conf"
grep -E '^xkb_rules_' "$CFG/config.conf" | sed 's/^/   /'

t "== 3. the session (%s)" "$SES"
install -m 755 "$D/mango/startxfce4-mango" "$BIN"
cat > "$SES" <<EOF
[Desktop Entry]
Name=Xfce Session (mango)
Name[es]=Sesión de Xfce (mango)
Comment=Xfce on Wayland with mangowc placing the windows (dwindle and scroller)
Comment[es]=Xfce sobre Wayland con mangowc colocando las ventanas (dwindle y columnas)
Exec=$BIN
Type=Application
DesktopNames=XFCE
EOF
ls -la "$BIN" "$SES"

t "== 4. launcher"
cat > "$LN" <<'EOF'
[Desktop Entry]
Name=mango Desktop
Name[es]=Escritorio mango
Comment=Switch to Xfce on Wayland with mangowc (trial), without password
Comment[es]=Pasar a Xfce sobre Wayland con mangowc (prueba), sin contraseña
Exec=sudo -n /usr/local/bin/switch-mode-root desktop-mango
Icon=preferences-desktop-display
Terminal=false
Type=Application
Categories=System;
EOF
ls -la "$LN"

# niri's trial (2026-10-23, never committed) had the same pieces: the chosen mode moves to mango, and its files go.
# The running niri session keeps working until it ends (the files are unlinked, not overwritten).
t "== 5. niri's trial, replaced"
if grep -q '^autologin-session=xfce-niri$' "$DROP" 2>/dev/null; then
    sed -i 's/^autologin-session=xfce-niri$/autologin-session=xfce-mango/' "$DROP"
    grep -n '^autologin-session=' "$DROP"
fi
rm -f /usr/local/bin/startxfce4-niri /usr/share/wayland-sessions/xfce-niri.desktop \
      /usr/share/applications/desktop-niri.desktop "$H/.local/bin/niri-tile"
rm -rf "${H:?}/.config/xfce4/niri" "${H:?}/.local/state/niri-tile"
if xbps-query niri >/dev/null 2>&1; then
    t "   niri's files removed; its packages stay until you leave its session:"
    t "   sudo xbps-remove niri xwayland-satellite"
fi

t "== Done. Finder (Super+Space) → 'mango Desktop' (it closes the current session: save first)."
t "   It is now the desktop: Game Mode's 'Switch to Desktop' comes here. labwc: 'labwc Desktop'."
t "   Shortcuts: docs/5-desktop/5-mango.md."
