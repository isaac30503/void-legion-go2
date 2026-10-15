#!/usr/bin/env python3
"""generate.py — void-update's tray icons, like cachy-update's: the distribution's symbol in a single color
(white for dark panels, black for light ones) with a small status badge in the bottom right corner, cut out of
the symbol with a gap: ✓ up to date, ↓ updates available, ··· checking, ! the check failed.

The symbol is Void's (the two arcs and the dot of /usr/share/void-artwork/void-logo.svg, package void-artwork,
without the letters), kept as vectors. Writes void-update-<state>-<style>.svg next to this script:
    python3 common/void-update/icons/generate.py [void-logo.svg]
The generated SVGs are in the repository (no void-artwork needed to install them); run this again only to
change the design. 2026-10-13, the user's request ("the distro's symbol in black and white, consistent with
the panel", like cachy-update).
"""
import os
import sys
import xml.etree.ElementTree as ET

SRC = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/void-artwork/void-logo.svg"
OUT = os.path.dirname(os.path.abspath(__file__))
NS = {"svg": "http://www.w3.org/2000/svg"}
STYLES = {"light": "#ffffff", "dark": "#000000"}
CX, CY, R = 18.0, 18.0, 5.2          # the badge (24×24 icon)
GAP = 6.7                            # radius of the hole cut out of the symbol around the badge
# Glyphs, drawn in black inside the badge's mask (so they are holes in the badge)
GLYPHS = {
    "up-to-date": '<polyline points="15.5,18.1 17.3,19.9 20.6,16.5" fill="none" stroke="black" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "available": '<line x1="18" y1="15.2" x2="18" y2="20.4" stroke="black" stroke-width="1.5" stroke-linecap="round"/>'
                 '<polyline points="15.8,18.3 18,20.5 20.2,18.3" fill="none" stroke="black" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    "checking": '<circle cx="15.9" cy="18" r="0.85" fill="black"/><circle cx="18" cy="18" r="0.85" fill="black"/>'
                '<circle cx="20.1" cy="18" r="0.85" fill="black"/>',
    "error": '<line x1="18" y1="15.0" x2="18" y2="18.6" stroke="black" stroke-width="1.6" stroke-linecap="round"/>'
             '<circle cx="18" cy="20.7" r="0.9" fill="black"/>',
}


def symbol_shapes():
    """The paths and circle of Void's symbol (group "circlearcs"), in their own 0..256 coordinates."""
    root = ET.parse(SRC).getroot()
    group = root.find(".//svg:g[@id='circlearcs']", NS)
    if group is None:
        sys.exit(f"no 'circlearcs' group in {SRC}")
    out = []
    for e in group:
        tag = e.tag.split("}")[1]
        if tag == "path":
            out.append(f'<path d="{e.get("d")}"/>')
        elif tag == "circle":
            out.append(f'<circle cx="{e.get("cx")}" cy="{e.get("cy", e.get("cx"))}" r="{e.get("r")}"/>')
    return "".join(out)


def icon(shapes, state, color):
    # The symbol spans ~0..256 in its coordinates: scaled to 22 px with 1 px of margin
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <defs>
    <mask id="cut" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
      <rect width="24" height="24" fill="white"/><circle cx="{CX}" cy="{CY}" r="{GAP}" fill="black"/>
    </mask>
    <mask id="glyph" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
      <circle cx="{CX}" cy="{CY}" r="{R}" fill="white"/>{GLYPHS[state]}
    </mask>
  </defs>
  <g mask="url(#cut)" fill="{color}"><g transform="translate(1 1) scale(0.0859375)">{shapes}</g></g>
  <circle cx="{CX}" cy="{CY}" r="{R}" fill="{color}" mask="url(#glyph)"/>
</svg>
'''


def main():
    shapes = symbol_shapes()
    for style, color in STYLES.items():
        for state in GLYPHS:
            path = os.path.join(OUT, f"void-update-{state}-{style}.svg")
            with open(path, "w", encoding="utf-8") as f:
                f.write(icon(shapes, state, color))
            print(path)


if __name__ == "__main__":
    main()
