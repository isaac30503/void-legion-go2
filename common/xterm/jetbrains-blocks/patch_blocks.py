#!/usr/bin/env python3
# Copy of JetBrainsMono Nerd Font Mono with the box blocks/lines
# (U+2500-U+259F) extended EXT units beyond ascent/descent.
# xterm draws each cell clipped (useClipping), so the leftover is not
# seen and the glyph fills the whole row even if xterm rounds the height
# up. Metrics (hhea/OS2) untouched: the cell height does not change.
import sys
from fontTools.ttLib import TTFont

EXT = 150  # ~2px at 10pt on the panel; it is clipped, it does not matter if it is too much
FAMILY = "JetBrainsMono NFM Blocks"

src, dst, style = sys.argv[1], sys.argv[2], sys.argv[3]
f = TTFont(src)
hhea = f["hhea"]
top, bot = hhea.ascent, hhea.descent  # 1020, -300
glyf = f["glyf"]
cmap = f.getBestCmap()

n = 0
for cp in range(0x2500, 0x25A0):
    name = cmap.get(cp)
    if not name:
        continue
    g = glyf[name]
    if g.isComposite() or g.numberOfContours <= 0:
        continue
    coords = g.coordinates
    changed = False
    for i, (x, y) in enumerate(coords):
        if y >= top:
            coords[i] = (x, top + EXT); changed = True
        elif y <= bot:
            coords[i] = (x, bot - EXT); changed = True
    if changed:
        g.recalcBounds(glyf); n += 1

name = f["name"]
full = f"{FAMILY} {style}" if style != "Regular" else FAMILY
ps = (FAMILY + "-" + style).replace(" ", "")
for rec in name.names:
    if rec.nameID in (1, 16):
        rec.string = FAMILY
    elif rec.nameID == 4:
        rec.string = full
    elif rec.nameID == 6:
        rec.string = ps
    elif rec.nameID == 3:
        rec.string = ps + ";blocks-patch"
f.save(dst)
print(f"{dst}: {n} glyphs extended")
