#!/bin/bash
# Installs (without root) the test of our own patches that void-update uses (2026-10-09; Void recipe, step 6):
#   ~/.local/bin/patch-still-needed                  ← patch-still-needed.sh (next to this script)
#   ~/.local/share/void-update/patches/<package>/  ← our own patches of each piece built here
#   ~/.local/share/void-legion/{lib,locale}          ← the translations of its messages (install_i18n_user)
# The same on both machines (each one only tests the pieces it has). Repeat it if a
# patch or the script changes. Usage: bash common/patch-test/install-patch-test.sh   (from the repository)
# Previous (Spanish) name: fish/void/instalar-prueba-parches.sh, which installed
# ~/.local/bin/parche-sigue-haciendo-falta and ~/.local/share/update-system/parches: both are removed here
# (the void-update of this repository uses the new names).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
[ "$(id -u)" != 0 ] || { t "without root"; exit 1; }
V="$(dirname "$(readlink -f "$0")")"
DEST=~/.local/share/void-update/patches
# Void package (or name) → folder of its patches, relative to the repository's root
declare -A DIRS=(
    [xfdesktop]=common/xfce-wayland/xfdesktop-wallpaper
    [Thunar]=common/xfce-wayland/thunar-wallpaper
    [gamescope]=common/steam/gamescope-patch
    [xdg-desktop-portal-wlr]=legion/portal-wlr-patch
    [steamos-manager]=common/steam/steamos-manager
)
install -D -m 755 "$V/patch-still-needed.sh" ~/.local/bin/patch-still-needed.new
mv ~/.local/bin/patch-still-needed.new ~/.local/bin/patch-still-needed
for n in "${!DIRS[@]}"; do
    shopt -s nullglob; p=("$REPO_ROOT/${DIRS[$n]}"/0*.patch); shopt -u nullglob
    [ ${#p[@]} -gt 0 ] || { t "!! no patches in %s" "${DIRS[$n]}"; exit 1; }
    rm -rf "$DEST/$n.new"; mkdir -p "$DEST/$n.new"
    install -m 644 "${p[@]}" "$DEST/$n.new/"
    rm -rf "$DEST/$n"; mv "$DEST/$n.new" "$DEST/$n"
done
install_i18n_user
# The old Spanish-named installation
rm -f ~/.local/bin/parche-sigue-haciendo-falta
rm -rf ~/.local/share/update-system/parches ~/.cache/update-system/parches
# and the folders of before void-update (2026-10-11: update-system/patches → void-update/patches)
rm -rf ~/.local/share/update-system ~/.cache/update-system
t "installed:"; ls -l ~/.local/bin/patch-still-needed; (cd "$DEST" && ls -1 */)
