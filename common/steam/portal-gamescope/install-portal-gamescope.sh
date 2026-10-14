#!/bin/sh
# SteamOS's gamescope portal (xdg-desktop-portal-gamescope) for Game Mode (2026-10-06; Legion recipe,
# step 14, "Screen sharing in Game Mode"). Valve ships it in SteamOS (holo repo):
# it implements ScreenCast/Screenshot/Access inside gamescope and, to share the screen, it delivers gamescope's
# WHOLE image (its PipeWire node "gamescope", the same one Steam uses), WSI games
# included. SteamOS uses it like this (start-gamescope-session): in Game Mode the portal only looks in
# /usr/share/xdg-desktop-portal/gamescope-portals (XDG_DESKTOP_PORTAL_DIR). Here Game Mode's launcher
# (install-game-mode.sh) does it if the folder that this script creates exists.
# Previous (Spanish) name: instalar-portal-gamescope.sh.
#   sudo sh common/steam/portal-gamescope/install-portal-gamescope.sh            # install
#   sudo sh common/steam/portal-gamescope/install-portal-gamescope.sh --remove   # remove
# The package (next to it; from the GitHub Release: install/fetch-assets.sh) is Valve's official one,
# BSD-3-Clause license; code not public (gitlab.steamos.cloud/holo/xdg-desktop-portal-gamescope).
# Downloaded on 2026-10-06 from
#   https://steamdeck-packages.steamos.cloud/archlinux-mirror/holo-3.8/os/x86_64/
# sha256 of the package and of the binary checked (the binary is identical to the Steam Deck's, SteamOS
# 3.8.28). It only depends on glibc. It is extracted with Python 3.14's compression.zstd module (Void does not
# ship zstd). It installs in /usr/local (xbps does not touch it):
#   /usr/local/lib/xdg-desktop-portal-gamescope        Valve's binary
#   /usr/local/lib/xdg-desktop-portal-gamescope-void   wrapper (next to it): the binary
#       writes to systemd's journal and without /run/systemd/journal/socket it crashes on start (panic,
#       code 101); the wrapper starts it isolated with bwrap and an own journal socket, and leaves
#       its messages in ~/.local/state/portal-gamescope.log. D-Bus starts the wrapper.
#   /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.gamescope.service
#   /usr/local/share/xdg-desktop-portal/gamescope-portals/{gamescope.portal,gamescope-portals.conf}
# (the .conf: default=gamescope; SteamOS sets "holo;gamescope", and holo is not needed here).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
D="$(dirname "$(readlink -f "$0")")"
PKG="$D/xdg-desktop-portal-gamescope-0.1.33.412a4bf-2-x86_64.pkg.tar.zst"
SUM=3929455f2e0e810327d879afef6ed449eeb66fd88448a86ffae184e113627ac5
BIN=/usr/local/lib/xdg-desktop-portal-gamescope
ENV=/usr/local/lib/xdg-desktop-portal-gamescope-void
SRV=/usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.gamescope.service
DIR=/usr/local/share/xdg-desktop-portal/gamescope-portals

if is_remove "${1:-}"; then
    pkill -f "^$BIN" 2>/dev/null || true
    rm -f "$BIN" "$ENV" "$SRV"; rm -rf "$DIR"
    t "removed (Game Mode goes back to having no capture portal from the next entry)"; exit 0
fi

[ -f "$PKG" ] || { t "missing %s (install/fetch-assets.sh downloads it)" "$PKG"; exit 1; }
echo "$SUM  $PKG" | sha256sum -c -
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
python3 -I - "$PKG" "$T" <<'PY'
import io, sys, tarfile
from compression import zstd
with tarfile.open(fileobj=io.BytesIO(zstd.decompress(open(sys.argv[1], "rb").read()))) as t:
    t.extractall(sys.argv[2], filter="data")
PY
echo "b449321f7a5ee1ab8c5d64cdc3cd9e1a63153014b5f3c81c7f7b9c2f13ffb5b0  $T/usr/lib/xdg-desktop-portal-gamescope" | sha256sum -c -
install -D -m 755 "$T/usr/lib/xdg-desktop-portal-gamescope" "$BIN.tmp" && mv "$BIN.tmp" "$BIN"
command -v bwrap >/dev/null || { t "!! bwrap is missing (package bubblewrap; it comes with flatpak)"; exit 1; }
install -m 755 "$D/xdg-desktop-portal-gamescope-void" "$ENV.tmp" && mv "$ENV.tmp" "$ENV"
mkdir -p "$(dirname "$SRV")" "$DIR"
printf '%s\n' "[D-BUS Service]" "Name=org.freedesktop.impl.portal.desktop.gamescope" "Exec=$ENV" > "$SRV"
install -m 644 "$T/usr/share/xdg-desktop-portal/gamescope-portals/gamescope.portal" "$DIR/gamescope.portal"
printf '%s\n' "# common/steam/portal-gamescope/install-portal-gamescope.sh: in Game Mode, only gamescope's portal." \
    "[preferred]" "default=gamescope" > "$DIR/gamescope-portals.conf"
ldd "$BIN" | grep -q "not found" && { t "!! libraries are missing:"; ldd "$BIN"; exit 1; }
ls -l "$BIN" "$ENV" "$SRV" "$DIR"
t "Done. Valid from the next entry into Game Mode (with install-game-mode.sh already up to date):"
t "the main portal looks for its own on start, so if you are in Game Mode, leave and come back."
