#!/bin/bash
# "What to share" chooser with previews for xdg-desktop-portal-wlr (Legion, 2026-10-06; recipe,
# step 14, "Discord (Vesktop)"). Without root. Requirements (root, once):
#   sudo xbps-install -S xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr grim fuzzel
# (fuzzel: text-mode fallback; see below). Usage, from the desktop session or over SSH:
#   bash legion/screen-share/install.sh            # install
#   bash legion/screen-share/install.sh --remove   # back to fuzzel
# Previous (Spanish) folder: compartir-pantalla/ (the chooser was ~/.local/bin/compartir-pantalla:
# installing or removing also removes that old name).
# 1. ~/.local/bin/screen-share (Python + GTK 3; thumbnails with grim), and its translations:
#    ~/.local/share/void-legion/{lib,locale} (the chooser's texts follow the system's language).
# 2. ~/.config/xdg-desktop-portal-wlr/config: chooser_type=dmenu + chooser_cmd=that script.
# 2b. ~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service: the same D-Bus service
#    that the package brings (/usr/share/dbus-1/services/…, Exec=/usr/libexec/xdg-desktop-portal-wlr)
#    but with XDPW_PERSIST_MODE=permanent. Without that variable xdpw 0.8.4 never returns a "restore token"
#    (src/screencast/screencast.c) and Chromium/Vesktop asks to choose twice; with it, each app receives
#    at most what it asks for (Vesktop asks for 1 = while running) and the second time it is not asked (only
#    screens: for windows the stock xdpw gives no token; the patch of legion/portal-wlr-patch/ adds it). The
#    user's folder rules over the system's and survives the package's updates.
# 3. Restarts xdg-desktop-portal-wlr (it reads its configuration only on start; D-Bus launches it again
#    on the next request). Without configuration, the portal uses the first chooser it finds
#    (slurp, wmenu, wofi, rofi, bemenu, mew, fuzzel): here, fuzzel.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
D="$(dirname "$(readlink -f "$0")")"
C=~/.config/xdg-desktop-portal-wlr/config
SV=~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service
rm -f ~/.local/bin/compartir-pantalla                  # the old Spanish name, if it is there
if is_remove "${1:-}"; then
    rm -f "$C" ~/.local/bin/screen-share "$SV"
    t "removed: the portal goes back to using fuzzel"
else
    for p in grim python3; do command -v $p >/dev/null || { t "missing %s" "$p"; exit 1; }; done
    mkdir -p ~/.local/bin "$(dirname "$C")"
    install -m 755 "$D/screen-share" ~/.local/bin/screen-share.tmp
    mv ~/.local/bin/screen-share.tmp ~/.local/bin/screen-share
    install_i18n_user                                 # its translations, in ~/.local/share/void-legion
    printf '%s\n' "# Written by legion/screen-share/install.sh (Legion recipe, step 14)." \
        "[screencast]" "chooser_type=dmenu" "chooser_cmd=$HOME/.local/bin/screen-share" > "$C.tmp"
    mv "$C.tmp" "$C"
    mkdir -p "$(dirname "$SV")"
    printf '%s\n' "# Written by legion/screen-share/install.sh (Legion recipe, step 14): the package's one + XDPW_PERSIST_MODE." \
        "[D-BUS Service]" "Name=org.freedesktop.impl.portal.desktop.wlr" \
        "Exec=/usr/bin/env XDPW_PERSIST_MODE=permanent /usr/libexec/xdg-desktop-portal-wlr" > "$SV.tmp"
    mv "$SV.tmp" "$SV"
    t "installed: ~/.local/bin/screen-share, %s and %s" "$C" "$SV"
fi
# D-Bus reads the .service files on start and when reloaded: reload it so that it takes (or drops) the user's one.
dbus-send --session --type=method_call --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ReloadConfig 2>/dev/null || true
# restart the portal (anchored pattern: it does not match this same command). It cuts a running stream.
if pkill -u "$USER" -f '^/usr/libexec/xdg-desktop-portal-wlr'; then t "xdg-desktop-portal-wlr restarted (it comes back by itself when sharing)"; fi
