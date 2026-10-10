#!/bin/sh
# Regenerates the "JetBrainsMono NFM Blocks" copy after updating the Nerd Font.
# Requires fonttools: python3 -m venv /tmp/ft && /tmp/ft/bin/pip install fonttools
# Previous (Spanish) name: regenerar.sh. The four .ttf it makes are published as a Release asset
# (install/fetch-assets.sh puts them next to this script).
PY=${PY:-/tmp/ft/bin/python}
D=$(dirname "$0")
for s in Regular Bold Italic BoldItalic; do
  "$PY" "$D/patch_blocks.py" ~/.local/share/fonts/JetBrainsMonoNerdFontMono-$s.ttf "$D/JetBrainsMonoNFMBlocks-$s.ttf" $s
done
fc-cache -f "$D"
