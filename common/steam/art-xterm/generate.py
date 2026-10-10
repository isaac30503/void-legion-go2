#!/usr/bin/env python3
"""Steam library art for the xterm shortcut (non-Steam game).

As in the SteamOS recipe (§13.7), redone for Void (2026-10-04): the real Papirus icon
(utilities-x-terminal.svg, the one xterm uses in the menu) rasterized with rsvg-convert, on a
background with radial gradient, halo and scan lines, and the label "XTERM" in JetBrainsMono Nerd
Font Mono bold, with the Super Game Bro palette (#0D2A1A #214130 #88A827 #D4F060). The icon, centered.
It writes in ~/.local/share/Steam/userdata/<user>/config/grid/ the 5 art files + the logo's
.json, with the UNSIGNED appid (appid & 0xFFFFFFFF), and the quick menu icon in
~/.local/share/icons/steam-shortcuts/xterm-color-256.png, which goes in the "icon" field of
shortcuts.vdf: that field is only written with Steam CLOSED (otherwise, Steam overwrites it on exit).
Previous (Spanish) name: arte-xterm/generar.py. Its messages follow the system's language.
Usage: python3 common/steam/art-xterm/generate.py      (without root; the system's Pillow: python3-Pillow)
"""
import os, struct, subprocess, sys, tempfile, json, shutil
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "lib"))
try:
    from void_legion_i18n import _
except ImportError:
    def _(s):
        return s
from PIL import Image, ImageDraw, ImageFilter, ImageFont

BG_DARK, BG, GREEN, LIGHT = "#0D2A1A", "#214130", "#88A827", "#D4F060"
SVG = "/usr/share/icons/Papirus/64x64/apps/utilities-x-terminal.svg"
STEAM = os.path.expanduser("~/.local/share/Steam")
ICONS = os.path.expanduser("~/.local/share/icons/steam-shortcuts")

def raster(side, dest):
    subprocess.run(["rsvg-convert", "-w", str(side), "-h", str(side), SVG, "-o", dest], check=True)
    return Image.open(dest).convert("RGBA")

FONT = subprocess.run(["fc-match", "-f", "%{file}", "JetBrainsMono Nerd Font Mono:style=Bold"],
                      capture_output=True, text=True).stdout

def background(w, h, cx=0.5, cy=0.5):
    """Radial gradient BG (center) -> BG_DARK (edges), with subtle scan lines."""
    r = max(w, h)
    mask = Image.radial_gradient("L").resize((int(r * 1.3), int(r * 1.3)))
    mask = mask.crop((int(r*1.3/2 - w*cx), int(r*1.3/2 - h*cy), int(r*1.3/2 - w*cx) + w, int(r*1.3/2 - h*cy) + h))
    im = Image.composite(Image.new("RGBA", (w, h), BG_DARK), Image.new("RGBA", (w, h), BG), mask)
    lines = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(lines)
    for y in range(0, h, 4):
        d.line([(0, y), (w, y)], fill=(0, 0, 0, 22))
    return Image.alpha_composite(im, lines)

def with_icon(im, icon, side, cx, cy):
    """Blurred green halo behind and the Papirus icon on top, centered on (cx, cy)."""
    halo = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(halo)
    rr = side * 0.62
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=GREEN + "70")
    im = Image.alpha_composite(im, halo.filter(ImageFilter.GaussianBlur(side * 0.22)))
    ic = icon.resize((side, side), Image.LANCZOS)
    im.alpha_composite(ic, (int(cx - side / 2), int(cy - side / 2)))
    return im

def label(im, text, size, cx, cy):
    d = ImageDraw.Draw(im); f = ImageFont.truetype(FONT, size)
    d.text((cx, cy), text, font=f, fill=LIGHT, anchor="mm", stroke_width=max(2, size // 22), stroke_fill=BG_DARK)
    return im

def read_vdf(d):
    def cstr(i):
        j = d.index(b"\0", i); return d[i:j], j + 1
    def obj(i):
        o = []
        while True:
            t = d[i]; i += 1
            if t == 8: return o, i
            k, i = cstr(i)
            if t == 0: v, i = obj(i)
            elif t == 1: v, i = cstr(i)
            elif t == 2: v = d[i:i + 4]; i += 4
            else: sys.exit(_("shortcuts.vdf: unknown type %s") % t)
            o.append([t, k, v])
    return obj(0)[0]

def write_vdf(o):
    b = b""
    for t, k, v in o:
        b += bytes([t]) + k + b"\0"
        b += write_vdf(v) if t == 0 else (v + b"\0" if t == 1 else v)
    return b + b"\x08"

def main():
    users = [u for u in os.listdir(f"{STEAM}/userdata") if u.isdigit() and u != "0"]
    steam_open = subprocess.run(["pgrep", "-x", "steam"], capture_output=True).returncode == 0
    tmp = tempfile.mkdtemp()
    icon = raster(1024, f"{tmp}/papirus-1024.png")
    os.makedirs(ICONS, exist_ok=True)
    ico256 = f"{ICONS}/xterm-color-256.png"
    raster(256, ico256)
    for u in users:
        vdf = f"{STEAM}/userdata/{u}/config/shortcuts.vdf"
        if not os.path.exists(vdf): continue
        data = read_vdf(open(vdf, "rb").read())
        shortcuts = next(v for t, k, v in data if k == b"shortcuts")
        for _t, _k, s in shortcuts:
            fields = {k: v for t, k, v in s}
            exe = fields.get(b"Exe", b"").decode()
            if "xterm" not in exe: continue
            appid = struct.unpack("<i", fields[b"appid"])[0] & 0xFFFFFFFF
            grid = f"{STEAM}/userdata/{u}/config/grid"; os.makedirs(grid, exist_ok=True)
            p = with_icon(background(600, 900, cy=0.42), icon, 360, 300, 380); label(p, "XTERM", 120, 300, 720)
            p.convert("RGB").save(f"{grid}/{appid}p.png")
            c = with_icon(background(920, 430, cy=0.4), icon, 230, 460, 170); label(c, "XTERM", 80, 460, 360)
            c.convert("RGB").save(f"{grid}/{appid}.png")
            with_icon(background(1920, 620), icon, 380, 960, 310).convert("RGB").save(f"{grid}/{appid}_hero.png")
            label(Image.new("RGBA", (1200, 400), (0, 0, 0, 0)), "XTERM", 230, 600, 200).save(f"{grid}/{appid}_logo.png")
            icon.resize((512, 512), Image.LANCZOS).save(f"{grid}/{appid}_icon.png")
            json.dump({"nVersion": 1, "logoPosition": {"pinnedPosition": "BottomLeft", "nWidthPct": 50, "nHeightPct": 50}},
                      open(f"{grid}/{appid}.json", "w"))
            print(_("art: %s/%s* (user %s, %s)") % (grid, appid, u, exe))
            if fields.get(b"icon", b"").decode() == ico256:
                print(_("quick menu icon: already set")); continue
            if steam_open:
                print(_("!! quick menu icon NOT set: Steam is open (close it and repeat)")); continue
            for c2 in s:
                if c2[1] == b"icon": c2[2] = ico256.encode()
            shutil.copy2(vdf, vdf + ".bak")
            open(vdf + ".new", "wb").write(write_vdf(data)); os.replace(vdf + ".new", vdf)
            print(_("quick menu icon: %s (copy in shortcuts.vdf.bak)") % ico256)
    shutil.rmtree(tmp)

main()
