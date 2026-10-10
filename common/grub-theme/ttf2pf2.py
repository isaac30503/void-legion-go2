#!/usr/bin/env python3
"""ttf2pf2.py — converts a TrueType font to GRUB's font format (PF2).

Void's GRUB does not ship grub-mkfont (it is built without FreeType), so this replaces it
for the boot menu theme. It draws each character with FreeType (through Pillow) in 1 bit
—GRUB does not antialias fonts— and writes the PF2 as grub-mkfont does:

  sections  NAME(4) + length(4, big endian) + data, in this order:
  FILE "PFF2" · NAME · FAMI · WEIG · SLAN · PTSZ · MAXW · MAXH · ASCE · DESC · CHIX · DATA
  CHIX: per character, code (u32) + 0 (u8, uncompressed) + position of the glyph (u32)
  DATA: length 0xFFFFFFFF; each glyph: width u16, height u16, x s16, y s16, advance s16 and the
        bitmap, row by row, most significant bit first and without padding between rows.
        y = distance from the base of the glyph to the baseline, upwards (like grub-mkfont).

Usage: ttf2pf2.py font.ttf size_px output.pf2 "Visible name" [bold|normal]
It needs Pillow and fontTools (in a venv: pip install pillow fonttools).
Previous name: ttf2pf2.py (unchanged). Void recipe, step 8 (GRUB theme).
"""
import struct
import sys

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

# What may appear in the menu: ASCII, Latin (accents), typographic punctuation, arrows,
# boxes and blocks (fastfetch-style borders), geometric shapes, Void's logo and the
# clock icons for the countdown.
RANGES = [(0x20, 0x7E), (0xA0, 0x17F), (0x2010, 0x2027), (0x2030, 0x205E), (0x20AC, 0x20AC),
          (0x2190, 0x21FF), (0x2500, 0x259F), (0x25A0, 0x25FF),
          (0xF017, 0xF017), (0xF250, 0xF254), (0xF32E, 0xF32E),             # clock, hourglasses, Void
          (0xF0150, 0xF0150), (0xF051F, 0xF051F), (0xF06AD, 0xF06AD), (0xF0954, 0xF0954),
          (0xF13AB, 0xF13AB), (0xF199F, 0xF199F)]   # in order: GRUB requires the index sorted


def section(name, data):
    return name.encode() + struct.pack(">I", len(data)) + data


def main():
    ttf, px, output, name = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
    weight = sys.argv[5] if len(sys.argv) > 5 else "bold"
    cmap = TTFont(ttf).getBestCmap()
    font = ImageFont.truetype(ttf, px)
    ascent, descent = font.getmetrics()

    glyphs = []   # (code, bytes of the glyph)
    maxw = maxh = 0
    for start, end in RANGES:
        for cp in range(start, end + 1):
            if cp not in cmap:
                continue
            ch = chr(cp)
            advance = round(font.getlength(ch))
            x0, y0, x1, y1 = font.getbbox(ch, mode="1", anchor="ls")
            width, height = max(0, x1 - x0), max(0, y1 - y0)
            bits = []
            if width and height:
                img = Image.new("1", (width, height), 0)
                drw = ImageDraw.Draw(img)
                drw.fontmode = "1"                     # no antialiasing: GRUB is 1-bit
                drw.text((-x0, -y0), ch, font=font, fill=1, anchor="ls")
                img_px = img.load()
                bits = [1 if img_px[x, y] else 0 for y in range(height) for x in range(width)]
            bitmap = bytearray((len(bits) + 7) // 8)
            for i, b in enumerate(bits):
                if b:
                    bitmap[i // 8] |= 0x80 >> (i % 8)
            # grub-mkfont's y: base of the bitmap with respect to the baseline, positive upwards
            data = struct.pack(">HHhhh", width, height, x0, -y1, advance) + bytes(bitmap)
            glyphs.append((cp, data))
            maxw, maxh = max(maxw, width), max(maxh, height)

    family = name.rsplit(" ", 1)[0] if weight == "bold" and name.endswith(" Bold") else name
    head = b"".join([
        section("FILE", b"PFF2"),
        section("NAME", f"{name} {px}".encode() + b"\0"),
        section("FAMI", family.encode() + b"\0"),
        section("WEIG", weight.encode() + b"\0"),
        section("SLAN", b"normal\0"),
        section("PTSZ", struct.pack(">H", px)),
        section("MAXW", struct.pack(">H", maxw)),
        section("MAXH", struct.pack(">H", maxh)),
        section("ASCE", struct.pack(">H", ascent)),
        section("DESC", struct.pack(">H", descent)),
    ])
    chix_len = 9 * len(glyphs)
    data_start = len(head) + 8 + chix_len + 8          # header + CHIX + header of DATA
    chix, body, pos = bytearray(), bytearray(), data_start
    for cp, data in glyphs:                             # they are already in code order
        chix += struct.pack(">IBI", cp, 0, pos)
        body += data
        pos += len(data)
    with open(output, "wb") as f:
        f.write(head + section("CHIX", bytes(chix)) + b"DATA" + struct.pack(">I", 0xFFFFFFFF) + body)
    print(f"{output}: '{name} {px}', {len(glyphs)} characters, ascent {ascent}, "
          f"descent {descent}, max. {maxw}x{maxh} px")


if __name__ == "__main__":
    main()
