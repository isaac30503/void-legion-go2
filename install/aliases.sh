#!/bin/sh
# aliases.sh — optional: the old (Spanish) names of the user commands as links to the new ones, for whoever
# is used to them (docs/glossary.md). Without root, in ~/.local/bin; only for commands that are installed.
#   bash install/aliases.sh            creates the links
#   bash install/aliases.sh --remove   removes them (--quitar also works)
# The installers delete the old Spanish-named files when they run (so that only one copy exists): after
# repeating an installer, run this again if the aliases are wanted.
# switch-mode-root already accepts its Spanish arguments (juego, escritorio…) and the sudoers rule keeps
# /usr/local/bin/cambiar-modo-root allowed; the fish functions keep their names (audio-ctrl, install-pkg…).
# For other languages: add lines "old-name new-name" to the list below.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
BIN="$HOME/.local/bin"
LIST="brillo brightness
fondo-vigilante wallpaper-watcher
ventana-acoplar window-snap
ventana-foco window-focus
ventanas-nuevas new-windows
compartir-pantalla screen-share
parche-sigue-haciendo-falta patch-still-needed"
echo "$LIST" | while read -r old new; do
    if is_remove "${1:-}"; then
        [ -L "$BIN/$old" ] && rm -f "$BIN/$old" && t "   removed %s" "$old"
    elif [ -x "$BIN/$new" ] && [ ! -e "$BIN/$old" ]; then
        ln -s "$new" "$BIN/$old" && t "   %s → %s" "$old" "$new"
    fi
done
exit 0
