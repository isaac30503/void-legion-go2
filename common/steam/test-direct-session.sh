#!/bin/sh
# test-direct-session.sh — (it started as a TEST) session "Steam (Game Mode, direct screen)", with gamescope
# handling the screen itself (DRM/KMS), as in SteamOS: what on the Legion gives VRR, HDR and
# refresh-rate changes. The X session "Steam (Game Mode)" stays as it is, as the fallback.
# It attacks the cause of the failure of 2026-10-03 (recipe, step 14, "What it took" 2): the login screen
# did not die with lightdm's SIGTERM because it waited for its accessibility bus (at-spi); when it died
# late, lightdm locked the Wayland session. With NO_AT_BRIDGE=1 (GTK variable: do not connect to
# at-spi), only for the login screen, it should die instantly.
# Previous (Spanish) name: probar-sesion-directa.sh (session steam-modo-juego-directo, wrapper
# lightdm-greeter-envoltorio and the marker "# probar-sesion-directa.sh" in lightdm.conf: installing or
# --remove also removes those).
#   /usr/share/wayland-sessions/steam-game-mode-direct.desktop   the session (same launcher:
#                                                                without DISPLAY, it goes direct)
#   /usr/local/bin/lightdm-greeter-wrapper                       NO_AT_BRIDGE=1 + the greeter
#   /etc/lightdm/lightdm.conf: greeter-wrapper=… in [Seat:*]     (leaves .bak; valid on reboot)
#   sudo sh common/steam/test-direct-session.sh            installs
#   sudo sh common/steam/test-direct-session.sh --remove   removes everything
# Needs install-game-mode.sh (the version with both modes). Void recipe, step 14.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
SES=/usr/share/wayland-sessions/steam-game-mode-direct.desktop
ENV=/usr/local/bin/lightdm-greeter-wrapper
CONF=/etc/lightdm/lightdm.conf
MARK='# test-direct-session.sh'
OLD_MARK='# probar-sesion-directa.sh'

cp "$CONF" "$CONF.bak"
# The marker goes on its own line, right above: GKeyFile does not accept comments at the end of a line.
sed -i "/^$MARK\$/,+1d; /^$OLD_MARK\$/,+1d" "$CONF"
rm -f /usr/share/wayland-sessions/steam-modo-juego-directo.desktop /usr/local/bin/lightdm-greeter-envoltorio

if is_remove "${1:-}"; then
    rm -f "$SES" "$ENV"
    t "== removed; differences in %s:" "$CONF"; diff "$CONF.bak" "$CONF" || true
    t "== Reboot so that lightdm stops using the wrapper."
    exit 0
fi
grep -q 'mode: direct screen' /usr/local/bin/steam-game-mode || {
    t "!! /usr/local/bin/steam-game-mode is an old one: run install-game-mode.sh first"; exit 1; }

cat > "$ENV" <<'EOF'
#!/bin/sh
# Login screen wrapper (lightdm greeter-wrapper; installed by common/steam/test-direct-session.sh):
# without connecting to the accessibility bus (at-spi), so that it dies instantly with lightdm's
# SIGTERM. Void recipe, step 14.
export NO_AT_BRIDGE=1
exec "$@"
EOF
chmod 755 "$ENV"
sed -i "/^\[Seat:\*\]/a $MARK\\ngreeter-wrapper=$ENV" "$CONF"

mkdir -p /usr/share/wayland-sessions
cat > "$SES" <<'EOF'
[Desktop Entry]
Name=Steam (Game Mode, direct screen)
Name[es]=Steam (Modo Juego, pantalla directa)
Comment=gamescope handles the screen itself (DRM), as in SteamOS
Comment[es]=gamescope maneja la pantalla él mismo (DRM), como en SteamOS
Exec=/usr/local/bin/steam-game-mode
Type=Application
DesktopNames=gamescope
EOF

t "== differences in %s:" "$CONF"; diff "$CONF.bak" "$CONF" || true
ls -la "$SES" "$ENV"
t "== Reboot and, at the login screen, choose 'Steam (Game Mode, direct screen)'."
