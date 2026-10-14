# shellcheck shell=bash

# Go through ~/.bashrc.d/ (Void does not ship it by default; 99-exec-fish.sh lives there)
# Appended at the end of ~/.bashrc by the recipe (steps 5–12). Previous (Spanish) name: bashrc-bloque.sh.
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*.sh; do
        # shellcheck source=/dev/null
        [ -r "$rc" ] && . "$rc"
    done
    unset rc
fi
