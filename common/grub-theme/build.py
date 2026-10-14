#!/usr/bin/env python3
"""build.py — generates the GRUB theme "void-xterm" in the style of the terminal (xterm):
Super Game Bro palette from ~/.Xresources, font JetBrainsMono NFM Blocks and a frame with the
title on the border, like the boxes of fastfetch's greeting. Void's logo on the left.

GRUB only draws 1-bit fonts (without antialiasing, jagged), so ALL the text
is drawn with antialiasing in the background image, also the names of the entries:
  - GRUB's menu uses an empty font ("Empty"; "Vacia" in the Spanish original): it writes nothing,
    it only puts the box of the chosen entry (sel_*.png, which fits the row);
  - the countdown is the only thing GRUB writes: a label "__timeout__" in the bottom
    right corner with an hourglass icon (from the Nerd Font itself) and the number
    (in 1 bit). Tried before, without success in this GRUB: digits and phrases as images in
    progress bars (the fill piece with an image is not drawn) and a colored bar
    with a frame (it came out as a 2 px line); the hourglass with bars was discarded;
  - as the names of the entries go in the background, the background is regenerated when the
    menu changes: the hook /etc/kernel.d/post-{install,remove}/60-grub-theme does it after 50-grub.
  - the "Advanced options" submenu is disabled (GRUB_DISABLE_SUBMENU=y): if it existed, its
    entries would be invisible. That way all the kernels are in the main menu.
The texts painted in the background (the title and the help line) follow the system's language
(locale/<lang>/messages.po): with the Spanish catalog the images are the same as before.

Usage:
  build.py theme_folder --from-grub          entries read from /boot/grub/grub.cfg (root)
  build.py theme_folder "Entry 1" "Entry 2" ...   entries by hand (preview)
  --preview output.png   also, a preview with the first entry chosen
The resolution comes from GRUB_GFXMODE and all sizes are scaled with it (it was designed for
1366x768: on the IdeaPad it comes out identical); under the logo, the machine's name.
Previous (Spanish) name: grub-tema/construir.py (its files fondo.png, vacia.pf2, entradas.txt and
theme.txt.desactivado are now background.png, empty.pf2, entries.txt and theme.txt.disabled).
Void recipe, step 8 (GRUB theme); Legion recipe, step 8.
"""
import os
import re
import socket
import struct
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
for _d in (HERE, "/usr/local/share/void-legion/lib", os.path.join(os.path.dirname(os.path.dirname(HERE)), "lib")):
    if os.path.isfile(os.path.join(_d, "void_legion_i18n.py")):
        sys.path.insert(0, _d)
        break
try:
    from void_legion_i18n import _
except ImportError:
    def _(s):
        return s


def screen(conf="/etc/default/grub"):
    """Menu resolution: the first one of GRUB_GFXMODE (install-theme.sh sets it with the
    panel's, /sys/class/drm/*-eDP-*/modes: 1366x768 on the IdeaPad, 1920x1200 on the Legion).
    For a preview of another machine: THEME_SCREEN=1920x1200 (and THEME_HOST=name)."""
    m = re.match(r"(\d+)x(\d+)$", os.environ.get("THEME_SCREEN", ""))
    if m:
        return int(m.group(1)), int(m.group(2))
    try:
        for line in open(conf, encoding="utf-8"):
            m = re.match(r"\s*GRUB_GFXMODE=\"?(\d+)x(\d+)", line)
            if m:
                return int(m.group(1)), int(m.group(2))
    except OSError:
        pass
    return 1366, 768


W, H = screen()
E = H / 768                                        # scale: everything was designed for 1366x768
HOST = os.environ.get("THEME_HOST") or socket.gethostname()   # under the logo


def sc(v):
    """Size in px of the 768-high screen, scaled to this one (on the IdeaPad, the same)."""
    return round(v * E)


TTF = "/usr/local/share/fonts/jetbrains-blocks/JetBrainsMonoNFMBlocks-Bold.ttf"   # the system's copy
LOGO_SVG = "/usr/share/void-artwork/void-logo.svg"

# Palette of ~/.Xresources (background, foreground, color2, color3, color7, cursorColor)
BG, TEXT, FRAME, DIM, LIGHT, CURSOR = "#214130", "#88A827", "#4A7828", "#648820", "#B8D432", "#D4F060"

# Geometry (the same for the background and for theme.txt). % of the screen except where noted.
LOGO_CX, LOGO_CY, LOGO_SIZE = 25, 44, sc(300)      # logo center (%) and size (px)
BOX_L, BOX_W = 47, 47                              # frame: left and width
MENU_L, MENU_W = 49, 43                            # boot_menu: left and width
ROW, GAP = sc(34), sc(8)                           # height of each entry and spacing (px)
TEXT_X = sc(14)                                    # indentation of the name inside the row (px)
COUNT_ICON = chr(0xF252)                           # fa-hourglass-half of the Nerd Font
COUNT_MARGIN = sc(24)                              # distance to the bottom right corner (px)
SIZE_ENTRY, SIZE_TITLE, SIZE_SMALL, SIZE_BIG = sc(20), sc(20), sc(16), sc(28)
SIZE_COUNT, SIZE_CONSOLE = sc(20), sc(16)          # PF2 fonts: countdown and console (c, e)
BOX_MARGIN, THICK = sc(46), sc(2)                  # margin inside the frame and line thickness


def px(pct, total):
    return int(total * pct / 100)                  # GRUB computes the % like this (integer rounded down)


def _level0_entries(lines, custom=None, done=None):
    """Titles of the FIRST-level entries, in order. It follows the braces { } (bodies of
    menuentry, submenu and function): an entry counts if it appears outside any block,
    whether indented or inside an if (UEFI Firmware Settings goes like that). Where
    custom.cfg is loaded (41_custom), it inserts its entries. Quotes are not counted as braces."""
    pat = re.compile(r"""^\s*(menuentry|submenu)\s+(['"])(.*?)\2""")
    out, depth, done = [], 0, done if done is not None else [False]
    for line in lines:
        no_quotes = re.sub(r"'[^']*'|\"[^\"]*\"", "", line)
        m = pat.match(line)
        if m and depth == 0:
            out.append(m.group(3))
        elif (depth == 0 and custom and not done[0] and re.match(r"\s*source\s.*custom\.cfg", line)
              and os.path.exists(custom)):
            done[0] = True
            out += _level0_entries(open(custom, encoding="utf-8", errors="replace"))
        depth += no_quotes.count("{") - no_quotes.count("}")
        depth = max(depth, 0)
    return out


def grub_entries(cfg="/boot/grub/grub.cfg", custom="/boot/grub/custom.cfg"):
    """Entries of the main menu as GRUB shows them."""
    return _level0_entries(open(cfg, encoding="utf-8", errors="replace"), custom)


def check(entries, cfg="/boot/grub/grub.cfg", custom="/boot/grub/custom.cfg"):
    """Second count, independent of the reader: all the menuentry lines of grub.cfg and
    custom.cfg. Without submenus they are all first-level, so they must match those that
    are going to be painted. Returns a text with the problem, or "" if everything matches."""
    pat = re.compile(r"^\s*(menuentry|submenu)\s")
    lines = list(open(cfg, encoding="utf-8", errors="replace"))
    if os.path.exists(custom):
        lines += list(open(custom, encoding="utf-8", errors="replace"))
    if any(re.match(r"^\s*submenu\s", l) for l in lines):
        return _("there is a submenu in grub.cfg (its entries would come out invisible)")
    n = sum(1 for l in lines if pat.match(l))
    if n != len(entries):
        return _("GRUB has %d entries and %d were going to be painted") % (n, len(entries))
    return ""


def disable(folder, reason):
    """Without theme.txt GRUB cannot load the theme and uses the text menu: never a background
    with names that do not correspond to the entries."""
    t = os.path.join(folder, "theme.txt")
    if os.path.exists(t):
        os.replace(t, t + ".disabled")
    sys.exit(_("THEME DISABLED (text menu): %s") % reason)


def grub_timeout(conf="/etc/default/grub"):
    try:
        for line in open(conf, encoding="utf-8"):
            m = re.match(r"\s*GRUB_TIMEOUT=\"?(\d+)", line)
            if m:
                return int(m.group(1))
    except OSError:
        pass
    return 5


def geometry(n):
    """Positions in px: frame, menu and texts below, according to the number of entries."""
    menu_h = n * (ROW + GAP)                       # GRUB: visible rows = height // (row + gap)
    box_h = menu_h + 2 * BOX_MARGIN                # top and bottom margin inside the frame
    box_y = (H - box_h) // 2 - sc(30)              # centered, a bit upwards
    g = dict(box=(px(BOX_L, W), box_y, px(BOX_L, W) + px(BOX_W, W), box_y + box_h),
             menu=(px(MENU_L, W), box_y + BOX_MARGIN, px(MENU_W, W), menu_h),
             help_y=box_y + box_h + sc(18))
    return g


def logo(dest):
    """Only the symbol (the two arcs and the dot), as in the ISO's menu: the SVG also carries
    the word VOID ("letters") and a white outline ("border"); they are removed, and the
    greens of the logo become the palette's."""
    import xml.etree.ElementTree as ET
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
    tree = ET.parse(LOGO_SVG)
    for parent in tree.iter():
        for child in list(parent):
            if child.get("id") in ("letters", "border"):
                parent.remove(child)
    svg = ET.tostring(tree.getroot(), encoding="unicode").replace("#478061", FRAME).replace("#abc2ab", LIGHT)
    tmp = dest + ".svg"
    open(tmp, "w", encoding="utf-8").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(LOGO_SIZE), "-h", str(LOGO_SIZE), "-o", dest, tmp], check=True)
    os.remove(tmp)


def background(folder, entries, timeout, g):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    f_ent, f_tit, f_small, f_big = (ImageFont.truetype(TTF, s) for s in (SIZE_ENTRY, SIZE_TITLE, SIZE_SMALL, SIZE_BIG))

    # Void's logo and, below, the name (like fastfetch's big logo)
    lp = os.path.join(folder, ".logo.png")
    logo(lp)
    lg = Image.open(lp).convert("RGBA")
    cx, cy = px(LOGO_CX, W), px(LOGO_CY, H)
    img.paste(lg, (cx - LOGO_SIZE // 2, cy - LOGO_SIZE // 2), lg)
    os.remove(lp)
    d.text((cx, cy + LOGO_SIZE // 2 + sc(30)), "Void Linux", font=f_big, fill=TEXT, anchor="mt")
    d.text((cx, cy + LOGO_SIZE // 2 + sc(70)), HOST, font=f_small, fill=DIM, anchor="mt")

    # Frame with the title cutting the top border, like fastfetch's ┌──Hardware──┐
    x0, y0, x1, y1 = g["box"]
    d.rectangle((x0, y0, x1, y1), outline=FRAME, width=THICK)
    title = _(" Boot ")
    tw = d.textlength(title, font=f_tit)
    tx = (x0 + x1 - tw) / 2
    d.rectangle((tx, y0 - THICK, tx + tw, y0 + THICK), fill=BG)
    d.text((tx, y0), title, font=f_tit, fill=FRAME, anchor="lm")

    # Names of the entries, each one in its row (GRUB puts the chosen one's box on top)
    mx, my, mw, _h = g["menu"]
    for i, e in enumerate(entries):
        y = my + i * (ROW + GAP)
        name = e
        while d.textlength(name, font=f_ent) > mw - 2 * TEXT_X and len(name) > 4:
            name = name[:-2].rstrip() + "…"
        d.text((mx + TEXT_X, y + ROW // 2), name, font=f_ent, fill=TEXT, anchor="lm")

    # Text below
    d.text(((x0 + x1) / 2, g["help_y"]), _("↑↓ choose · Enter boot · e edit · c console"),
           font=f_small, fill=FRAME, anchor="mt")
    img.save(os.path.join(folder, "background.png"))
    return img


def countdown_label(folder):
    """Countdown: GRUB label with id "__timeout__", which GRUB updates every second
    (%d = seconds left) and hides when a key is pressed. It needs the 20 px font,
    with the clock icons (ttf2pf2.py includes them). Returns the lines of theme.txt."""
    pf2 = pf2_font(folder, SIZE_COUNT)
    width, height = sc(160), sc(30)
    return f"""+ label {{
    id = "__timeout__"
    text = "{COUNT_ICON} %d"
    left = {W - COUNT_MARGIN - width}
    top = {H - COUNT_MARGIN - height}
    width = {width}
    height = {height}
    align = "right"
    font = "JetBrainsMono NFM Blocks Bold {SIZE_COUNT}"
    color = "{TEXT}"
}}
""", (W - COUNT_MARGIN - width, H - COUNT_MARGIN - height, width, pf2)


def pf2_font(folder, size):
    """JetBrainsMono NFM Blocks Bold in PF2 (1 bit) of size px, if it is not already in the theme."""
    pf2 = os.path.join(folder, f"jetbrains-{size}.pf2")
    if not os.path.exists(pf2):
        subprocess.run([sys.executable, os.path.join(HERE, "ttf2pf2.py"), TTF, str(size), pf2,
                        "JetBrainsMono NFM Blocks Bold", "bold"], check=True, stdout=subprocess.DEVNULL)
    return pf2


def selection(folder, thick=THICK):
    """Box of the chosen entry (xterm's cursor color), straight corners like fastfetch's
    frames. GRUB puts the border pieces OUTSIDE the row and the center
    (transparent) on top: the box surrounds the row without covering or moving it."""
    t = thick
    pieces = {"nw": (t, t), "n": (1, t), "ne": (t, t), "w": (t, 1), "e": (t, 1),
              "sw": (t, t), "s": (1, t), "se": (t, t)}
    for name, size in pieces.items():
        Image.new("RGBA", size, CURSOR).save(os.path.join(folder, f"sel_{name}.png"))
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(os.path.join(folder, "sel_c.png"))


def empty_font(path, px_=SIZE_ENTRY):
    """PF2 "Empty" without any pixel: GRUB's menu uses it so that it writes nothing."""
    def sec(n, d):
        return n.encode() + struct.pack(">I", len(d)) + d
    cps = list(range(0x20, 0x7F)) + list(range(0xA0, 0x180)) + [0x2026]
    head = b"".join([sec("FILE", b"PFF2"), sec("NAME", f"Empty Regular {px_}".encode() + b"\0"),
                     sec("FAMI", b"Empty\0"), sec("WEIG", b"normal\0"), sec("SLAN", b"normal\0"),
                     sec("PTSZ", struct.pack(">H", px_)), sec("MAXW", struct.pack(">H", 1)),
                     sec("MAXH", struct.pack(">H", 1)), sec("ASCE", struct.pack(">H", px_)),
                     sec("DESC", struct.pack(">H", 4))])
    pos = len(head) + 8 + 9 * len(cps) + 8
    chix, data = bytearray(), bytearray()
    for cp in cps:
        g = struct.pack(">HHhhh", 0, 0, 0, 0, 12)
        chix += struct.pack(">IBI", cp, 0, pos)
        data += g
        pos += len(g)
    open(path, "wb").write(head + sec("CHIX", bytes(chix)) + b"DATA" + struct.pack(">I", 0xFFFFFFFF) + data)


def theme_txt(folder, g, count_txt):
    mx, my, mw, mh = g["menu"]
    x0, _y0, x1, _y1 = g["box"]
    txt = f"""# GRUB theme "void-xterm": the style of the terminal (Super Game Bro palette from
# ~/.Xresources, JetBrainsMono NFM Blocks) and a frame like fastfetch's boxes.
# Generated by build.py; DO NOT EDIT: it is regenerated with every kernel (60-grub-theme).
# All the text is in background.png (GRUB only draws 1-bit fonts). The console (the
# "Loading Linux…" at boot, c, e) takes the whole screen, without border. Recipe, step 8.
title-text: ""
desktop-image: "background.png"
desktop-color: "{BG}"
terminal-font: "JetBrainsMono NFM Blocks Bold {SIZE_CONSOLE}"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

+ boot_menu {{
    left = {mx}
    top = {my}
    width = {mw}
    height = {mh}
    item_font = "Empty Regular {SIZE_ENTRY}"
    selected_item_font = "Empty Regular {SIZE_ENTRY}"
    item_color = "{TEXT}"
    selected_item_color = "{TEXT}"
    selected_item_pixmap_style = "sel_*.png"
    item_height = {ROW}
    item_padding = 0
    item_spacing = {GAP}
    icon_width = 0
    icon_height = 0
    item_icon_space = 0
    scrollbar = false
}}

{count_txt}"""
    open(os.path.join(folder, "theme.txt"), "w", encoding="utf-8").write(txt)


def preview(img, g, out, extra):
    """Whole menu as when 3 s are left, with the countdown drawn like GRUB (PF2 font)."""
    lx, ly, width, pf2 = extra
    sys.path.insert(0, HERE)
    from read_pf2 import Pf2
    f = Pf2(pf2)
    v = img.copy()
    text = f"{COUNT_ICON} 3"
    f.draw(v, lx + width - f.width(text), ly + f.asc, text, TEXT)
    d = ImageDraw.Draw(v)
    mx, my, mw, _h = g["menu"]
    d.rectangle((mx - 2, my - 2, mx + mw + 1, my + ROW + 1), outline=CURSOR, width=2)
    v.save(out)


if __name__ == "__main__":
    args = sys.argv[1:]
    prev = None
    if "--preview" in args:
        i = args.index("--preview"); prev = args[i + 1]; del args[i:i + 2]
    folder = args[0]
    from_grub = args[1:] == ["--from-grub"]
    entries = grub_entries() if from_grub else args[1:]
    if not entries:
        disable(folder, _("no entry could be read from /boot/grub/grub.cfg"))
    if from_grub:
        problem = check(entries)
        if problem:
            disable(folder, problem)
    os.makedirs(folder, exist_ok=True)
    g = geometry(len(entries))
    img = background(folder, entries, grub_timeout(), g)
    selection(folder)
    pf2_font(folder, SIZE_CONSOLE)
    empty_font(os.path.join(folder, "empty.pf2"))
    timeout = grub_timeout()
    count_txt, data = countdown_label(folder)
    theme_txt(folder, g, count_txt)
    if prev:
        preview(img, g, prev, data)
    open(os.path.join(folder, "entries.txt"), "w", encoding="utf-8").write("\n".join(entries) + "\n")
    print(_("theme generated in %s: %d entries:") % (folder, len(entries)), " | ".join(entries))
