#!/bin/bash
# install-void-update.sh — installs void-update for the user (without root; 2026-10-11), on both machines:
#   ~/.local/bin/void-update                        the command
#   ~/.local/lib/void-update/{lib/,icons/,void-update-tray,void-update.conf.example}
#   ~/.local/share/icons/hicolor/scalable/apps/void-update.svg   the application's icon (launcher, notification)
#   ~/.local/share/applications/void-update.desktop the launcher (terminal) that the icon and the notification open
#   ~/.config/fish/completions/void-update.fish
#   ~/.local/bin/patch-still-needed and its patches  (common/patch-test/install-patch-test.sh)
#   ~/.local/share/void-legion/                     translations of the messages
# and starts the panel icon at every login (void-update --tray --enable; --no-tray skips it).
# Migration from update-system (the fish function it replaces; the user's decision: the old name is removed):
# deletes ~/.config/fish/functions/update-system.fish and moves the date of the last update
# (~/.local/state/update-system.last → ~/.local/state/void-update/last-update, used by fastfetch, whose
# gen-config.py is brought up to date and regenerated if it is installed).
#   bash common/void-update/install-void-update.sh [--no-tray]
#   bash common/void-update/install-void-update.sh --remove     (leaves the state and config)
# Needs (Void packages, already on both machines; it says what is missing): python3-gobject,
# libayatana-appindicator, libnotify, curl, glib (gio), xbps.
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
HERE=$(dirname "$(readlink -f "$0")")
LIB=~/.local/lib/void-update
BIN=~/.local/bin
APPS=${XDG_DATA_HOME:-$HOME/.local/share}/applications
COMP=~/.config/fish/completions

if is_remove "${1:-}"; then
    "$BIN/void-update" --tray --disable 2>/dev/null || true
    pkill -u "$(id -u)" -f void-update-tray 2>/dev/null || true
    rm -rf "$LIB"; rm -f "$BIN/void-update" "$APPS/void-update.desktop" "$COMP/void-update.fish" ~/.local/share/icons/hicolor/scalable/apps/void-update.svg
    t "void-update removed (state and configuration kept in ~/.local/state/void-update and ~/.config/void-update)"
    exit 0
fi

missing=()
python3 -c 'import gi' 2>/dev/null || missing+=(python3-gobject)
[ -f /usr/lib/girepository-1.0/AyatanaAppIndicator3-0.1.typelib ] || missing+=(libayatana-appindicator)
command -v notify-send >/dev/null || missing+=(libnotify)
command -v curl >/dev/null || missing+=(curl)
command -v gio >/dev/null || missing+=(glib)
if [ ${#missing[@]} -gt 0 ]; then
    t "!! missing packages: %s" "sudo xbps-install -S ${missing[*]}"; exit 1
fi

t "== void-update"
mkdir -p "$LIB/lib.new" "$BIN" "$APPS" "$COMP"
install -m 644 "$HERE"/lib/*.sh "$LIB/lib.new/"
rm -rf "$LIB/lib"; mv "$LIB/lib.new" "$LIB/lib"
install -m 755 "$HERE/void-update-tray" "$LIB/void-update-tray.new" && mv "$LIB/void-update-tray.new" "$LIB/void-update-tray"
install -m 644 "$HERE/void-update.conf.example" "$LIB/"
mkdir -p "$LIB/icons" ~/.local/share/icons/hicolor/scalable/apps
install -m 644 "$HERE"/icons/*.svg "$LIB/icons/"
# The application's icon (launcher, notification): the "updates available" one, in the style of the config
style=$(sed -n 's/^[[:space:]]*tray_icon_style[[:space:]]*=[[:space:]]*\([a-z]*\).*/\1/p' ~/.config/void-update/void-update.conf 2>/dev/null | tail -1 || true)
install -m 644 "$HERE/icons/void-update-available-${style:-light}.svg" ~/.local/share/icons/hicolor/scalable/apps/void-update.svg
install -m 755 "$HERE/void-update" "$BIN/void-update.new" && mv "$BIN/void-update.new" "$BIN/void-update"
install -m 644 "$HERE/void-update.desktop" "$APPS/void-update.desktop"
install -m 644 "$HERE/completions/void-update.fish" "$COMP/void-update.fish"
install_i18n_user
bash "$REPO_ROOT/common/patch-test/install-patch-test.sh" >/dev/null && t "   patch test installed (patch-still-needed)"

t "== migration from update-system"
if [ -e ~/.config/fish/functions/update-system.fish ]; then
    rm -f ~/.config/fish/functions/update-system.fish && t "   removed ~/.config/fish/functions/update-system.fish"
fi
mkdir -p ~/.local/state/void-update
if [ -f ~/.local/state/update-system.last ]; then
    [ -f ~/.local/state/void-update/last-update ] || cp ~/.local/state/update-system.last ~/.local/state/void-update/last-update
    rm -f ~/.local/state/update-system.last && t "   date of the last update moved to ~/.local/state/void-update/last-update"
fi

# fastfetch's "Updated" line reads the new file (with the old one as fallback): its generator, brought up to date
if [ -f ~/.config/fastfetch/gen-config.py ]; then
    install -m 644 "$REPO_ROOT/common/fastfetch/gen-config.py" ~/.config/fastfetch/gen-config.py
    python3 ~/.config/fastfetch/gen-config.py && t "   fastfetch's configuration regenerated"
fi

if [ "${1:-}" != --no-tray ]; then
    t "== panel icon"
    "$BIN/void-update" --tray --enable
fi
t "== done: void-update --help"
