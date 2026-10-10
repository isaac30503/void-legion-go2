#!/usr/bin/env python3
"""read_pf2.py — reads a GRUB PF2 font and draws text with it, pixel by pixel like GRUB.
It is used to verify the fonts that ttf2pf2.py generates (comparing them with GRUB's, e.g.
/usr/share/grub/unicode.pf2) and for the theme's preview (build.py).
Previous (Spanish) name: leer_pf2.py (methods glifo/ancho/dibujar, now glyph/width/draw).
Standalone usage: read_pf2.py font.pf2 "text" output.png
"""
import struct
import sys

from PIL import Image


class Pf2:
    def __init__(self, path):
        d = open(path, "rb").read()
        self.d, p, sec, self.order = d, 0, {}, []
        while p < len(d):
            n = d[p:p + 4].decode()
            ln = struct.unpack(">I", d[p + 4:p + 8])[0]
            p += 8
            self.order.append(n)
            if n == "DATA":
                break
            sec[n] = d[p:p + ln]
            p += ln
        self.name = sec["NAME"].rstrip(b"\0").decode()
        self.asc = struct.unpack(">H", sec["ASCE"])[0]
        self.desc = struct.unpack(">H", sec["DESC"])[0]
        self.idx = {}
        for i in range(0, len(sec["CHIX"]), 9):
            cp, _f, off = struct.unpack(">IBI", sec["CHIX"][i:i + 9])
            self.idx[cp] = off

    def glyph(self, ch):
        off = self.idx.get(ord(ch), self.idx.get(ord("?")))
        w, h, x, y, adv = struct.unpack(">HHhhh", self.d[off:off + 10])
        return w, h, x, y, adv, self.d[off + 10:off + 10 + (w * h + 7) // 8]

    def width(self, text):
        return sum(self.glyph(c)[4] for c in text)

    def draw(self, img, x, base, text, color):
        """Draws text with the baseline at (x, base)."""
        for ch in text:
            w, h, gx, gy, adv, bits = self.glyph(ch)
            for i in range(w * h):
                if bits[i // 8] & (0x80 >> (i % 8)):
                    img.putpixel((x + gx + i % w, base - gy - h + i // w), _rgb(color))
            x += adv


def _rgb(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) if isinstance(c, str) else c


if __name__ == "__main__":
    f = Pf2(sys.argv[1])
    print("sections:", " ".join(f.order), "· name:", f.name,
          f"· {len(f.idx)} chars · ascent {f.asc} · descent {f.desc}")
    img = Image.new("RGB", (f.width(sys.argv[2]) + 8, f.asc + f.desc + 8), (0, 0, 0))
    f.draw(img, 4, f.asc + 4, sys.argv[2], (255, 255, 255))
    img.save(sys.argv[3])
