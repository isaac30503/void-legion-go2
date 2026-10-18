#!/usr/bin/env python3
"""Steam library art for Vesktop (Discord client): VESKTOP'S LOGO with Discord's colors,
minimalist (2026-10-06, instead of Vencord's pink art set with SteamGridDB). The logo
is the vector of the Flatpak itself (dev.vencord.Vesktop.svg), recolored: pink bubble #eb7396 → blue
"blurple" #5865F2; white #ededed/#fff → #ffffff; outlines #1d2021 → #1e1f22 (Discord's darkest
gray). Background with Vesktop's aesthetics and the same colors (2026-10-06, second request): diagonal
gradient #313338 → #1e1f22 (Discord's grays), diffuse blue halo behind the logo, pattern of small speech
bubbles (the shape of Vesktop's bubble), rotated and in very faint blue, with the center free, and the
logo with a soft shadow, like a sticker. The bubbles' layout comes from a fixed seed: always the same.
Text "Vesktop" in Noto Sans Bold (fc-match). Without root; it uses python3-Pillow and rsvg-convert, already there.
(First version, the same morning: Papirus's Discord silhouette on blue; the user preferred
Vesktop's logo. Its function, silhouette(), stays below, unused.)

It looks in shortcuts.vdf for Vesktop's shortcut (name "Vesktop"/"Discord" or "Vesktop" in the
launch options), takes its unsigned appid and writes in
~/.local/share/Steam/userdata/<user>/config/grid/: <appid>p.png (600x900), <appid>.png (920x430),
<appid>_hero.png (1920x620), <appid>_logo.png (1200x400, transparent), <appid>_icon.png (512x512) and
<appid>.json (logo bottom left, 50 %). Before, it copies whatever art there was to
~/.cache/art-vesktop-previous/, only what is not already there (that way it keeps the original, SteamGridDB's
pink one, even if it is repeated; the old folder ~/.cache/arte-vesktop-anterior is renamed to it). It does not
touch shortcuts.vdf: the quick menu icon is chosen in Steam
(Properties → Shortcut → icon) with ~/.local/share/icons/steam-shortcuts/discord-256.png.
With Steam open, the art shows after restarting Steam.
Desktop (Xfce): it saves the recolored logo as a vector in the icon theme,
~/.local/share/icons/hicolor/scalable/apps/vesktop-discord.svg, and writes
~/.local/share/applications/dev.vencord.Vesktop.desktop = the Flatpak's with Icon=vesktop-discord (a name of its own,
which Papirus does not have, so it is ours and not Papirus's "vesktop"; the user's copy rules over the Flatpak's; same
StartupWMClass=vesktop, so the open window takes the same icon in the panel and in Alt+Tab). By name and not by path
(2026-10-16): with a file path the panel loads it at 1x and stretches it, blurry on a screen at scale 2. If a
Vesktop update changes its launcher, run this again.
Tray (the "VC" of the top panel): that icon is drawn by Vesktop, not by the theme. Vesktop first uses the
"user assets" (~/.var/app/dev.vencord.Vesktop/config/vesktop/userAssets/tray and trayUnread, without
extension; the same ones chosen in its settings). Its tray.png and trayUnread.png are taken out of app.asar and
only their pink is changed to the blue (the white, the outline and the red "unread" dot stay).
It shows when opening Vesktop again. To go back to pink: delete that userAssets folder.
Previous (Spanish) name: arte-vesktop/generar.py. Its messages follow the system's language.
  python3 common/steam/art-vesktop/generate.py    (or, from another machine: ssh lego python3 - < generate.py)
  python3 common/steam/art-vesktop/generate.py --desktop    only the desktop icon and launcher (Steam may be open)
docs/7-apps/2-vesktop.md (Library art).
"""
import glob, json, os, random, re, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "lib"))
try:
    from void_legion_i18n import _
except ImportError:
    def _(s):
        return s
from PIL import Image, ImageDraw, ImageFilter, ImageFont

BLUE = (88, 101, 242)            # #5865F2, Discord's "blurple"
GRAY = (49, 51, 56)              # #313338, the background of Discord's chat
DARK = (30, 31, 34)              # #1e1f22, Discord's darkest gray
WHITE = (255, 255, 255)
VESKTOP = os.path.expanduser("~/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/dev.vencord.Vesktop.svg")
COLORS = {"#eb7396": "#5865f2", "#ededed": "#ffffff", "#fff": "#ffffff", "#1d2021": "#1e1f22"}
STEAM = os.path.expanduser("~/.local/share/Steam")
ICONS = os.path.expanduser("~/.local/share/icons/steam-shortcuts")
SVG = next(f for f in ["/usr/share/icons/Papirus/24x24/panel/discord-tray.svg",
                       "/usr/share/icons/Papirus-Dark/24x24/panel/discord-tray.svg"] if os.path.exists(f))
FONT = subprocess.run(["fc-match", "-f", "%{file}", "Noto Sans:bold"],
                      capture_output=True, text=True).stdout.strip()

def silhouette(width):
    """Discord's silhouette in white, cropped to its box (≈ 2.3–21.7 × 6.0–19.0 of the 24 SVG)."""
    t = open(SVG).read()
    t = re.sub(r'<defs>.*?</defs>', '', t, flags=re.S)
    t = t.replace('style="fill:currentColor"', 'style="fill:#ffffff"')
    t = re.sub(r'width="24" height="24"', 'width="19.4" height="13.0" viewBox="2.3 6.0 19.4 13.0"', t, count=1)
    with tempfile.TemporaryDirectory() as d:
        s, p = f"{d}/s.svg", f"{d}/s.png"
        open(s, "w").write(t)
        subprocess.run(["rsvg-convert", "-w", str(width), s, "-o", p], check=True)
        return Image.open(p).convert("RGBA")

def vesktop_logo(width):
    """Vesktop's logo (square) with Discord's colors."""
    t = open(VESKTOP).read()
    for old, new in COLORS.items():
        t = re.sub(re.escape(old) + r"(?![0-9a-fA-F])", new, t, flags=re.I)
    with tempfile.TemporaryDirectory() as d:
        s, p = f"{d}/v.svg", f"{d}/v.png"
        open(s, "w").write(t)
        subprocess.run(["rsvg-convert", "-w", str(width), "-h", str(width), s, "-o", p], check=True)
        return Image.open(p).convert("RGBA")

def bubble(side):
    """Only the bubble of Vesktop's logo (its first path), in blue, for the background's pattern."""
    t = open(VESKTOP).read()
    d = re.search(r'<path fill="#eb7396" d="([^"]+)"', t).group(1)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><path fill="#5865f2" d="{d}"/></svg>'
    with tempfile.TemporaryDirectory() as tmp:
        open(f"{tmp}/g.svg", "w").write(svg)
        subprocess.run(["rsvg-convert", "-w", str(side), "-h", str(side), f"{tmp}/g.svg", "-o", f"{tmp}/g.png"], check=True)
        return Image.open(f"{tmp}/g.png").convert("RGBA")

def recolored_svg():
    t = open(VESKTOP).read()
    for old, new in COLORS.items():
        t = re.sub(re.escape(old) + r"(?![0-9a-fA-F])", new, t, flags=re.I)
    return t

def desktop():
    """Desktop icon: the recolored logo and a user launcher that uses it."""
    icon = os.path.expanduser("~/.local/share/icons/hicolor/scalable/apps/vesktop-discord.svg")
    os.makedirs(os.path.dirname(icon), exist_ok=True)
    open(icon, "w").write(recolored_svg())
    old = os.path.expanduser("~/.local/share/icons/vesktop-discord.svg")   # by path, before 2026-10-16
    if os.path.exists(old):
        os.remove(old)
    source = os.path.expanduser("~/.local/share/flatpak/exports/share/applications/dev.vencord.Vesktop.desktop")
    if not os.path.exists(source):
        source = "/var/lib/flatpak/exports/share/applications/dev.vencord.Vesktop.desktop"
    if not os.path.exists(source):
        print(_("no Vesktop launcher from the Flatpak: the desktop is not touched")); return
    dest = os.path.expanduser("~/.local/share/applications/dev.vencord.Vesktop.desktop")
    lines = open(source).read().splitlines()
    lines = ["Icon=vesktop-discord" if l.startswith("Icon=") else l for l in lines]
    i = lines.index("[Desktop Entry]") + 1 if "[Desktop Entry]" in lines else 0
    lines.insert(i, "# Copy of the Flatpak's launcher with the recolored icon (common/steam/art-vesktop/generate.py)")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    open(dest + ".tmp", "w").write("\n".join(lines) + "\n"); os.replace(dest + ".tmp", dest)
    print(_("desktop: %s → Icon=%s") % (dest, "vesktop-discord"))

def tray():
    """Tray icons: Vesktop's with the pink changed to Discord's blue."""
    try:
        root = subprocess.run(["flatpak", "info", "--show-location", "dev.vencord.Vesktop"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        print(_("tray: no Flatpak Vesktop")); return
    asar = os.path.join(root, "files/bin/vesktop/resources/app.asar")
    with open(asar, "rb") as f:
        f.seek(12); n = int.from_bytes(f.read(4), "little"); head = json.loads(f.read(n))
        base = 16 + ((n + 3) & ~3)
        inside = head["files"]["static"]["files"]["tray"]["files"]
        dest = os.path.expanduser("~/.var/app/dev.vencord.Vesktop/config/vesktop/userAssets")
        os.makedirs(dest, exist_ok=True)
        for name in ("tray", "trayUnread"):
            e = inside[name + ".png"]
            f.seek(base + int(e["offset"])); data = f.read(e["size"])
            im = Image.open(__import__("io").BytesIO(data)).convert("RGBA")
            px = im.load(); dark = (29, 32, 33)          # outline #1d2021
            for y in range(im.height):
                for x in range(im.width):
                    r, g, b, a = px[x, y]
                    # pink #eb7396 (and its blend with the outline): b clearly greater than g; the red
                    # of the "unread" dot has b ≈ g and is not touched
                    if a and r > g + 40 and b > g + 15:
                        t = max(0.0, min(1.0, (r - dark[0]) / (235 - dark[0])))
                        px[x, y] = tuple(round(t * c + (1 - t) * o) for c, o in zip(BLUE, DARK, strict=True)) + (a,)
            im.save(os.path.join(dest, name + ".tmp"), "PNG")
            os.replace(os.path.join(dest, name + ".tmp"), os.path.join(dest, name))
    print(_("tray: %s/tray and trayUnread (they show when opening Vesktop again)") % dest)

def flat(w, h, cx=0.5, cy=0.5, free=(), seed=7):
    """Background with Vesktop's aesthetics: diagonal gradient of grays, blue halo at (cx, cy) and faint
    bubbles spread outside the `free` zones (rectangles in fractions: x0, y0, x1, y1), which
    cover the logo and the text so that the pattern does not clutter them."""
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(0, w):
            f = (x / w + y / h) / 2
            px[x, y] = tuple(int(GRAY[i] + (DARK[i] - GRAY[i]) * f) for i in range(3)) + (255,)
    # diffuse blue halo
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = int(min(w, h) * 0.42)
    ImageDraw.Draw(halo).ellipse((cx * w - r, cy * h - r, cx * w + r, cy * h + r), fill=BLUE + (70,))
    im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(r * 0.5)))
    # bubble pattern
    rnd = random.Random(seed)
    base = max(w, h)
    n = int(w * h / (base * base) * 34) + 8
    for _i in range(n * 6):
        if n <= 0:
            break
        side = int(base * rnd.uniform(0.045, 0.09))
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        m = side * 0.6
        if any(x0 * w - m < x < x1 * w + m and y0 * h - m < y < y1 * h + m for x0, y0, x1, y1 in free):
            continue
        g = bubble(side).rotate(rnd.uniform(-35, 35), resample=Image.BICUBIC, expand=True)
        k = rnd.uniform(0.10, 0.22)           # this bubble's opacity (a new one for each bubble)
        a = g.getchannel("A").point([int(v * k) for v in range(256)])   # a table, not a closure over k
        g.putalpha(a)
        im.alpha_composite(g, (int(x - g.width / 2), int(y - g.height / 2)))
        n -= 1
    return im

def with_shadow(im, figure, cx, cy, offset=None):
    """Pastes the figure with a soft shadow underneath (sticker style)."""
    offset = offset or max(4, figure.width // 40)
    shadow = Image.new("RGBA", figure.size, (0, 0, 0, 0))
    shadow.putalpha(figure.getchannel("A").point(lambda v: int(v * 0.55)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(figure.width / 30))
    paste(im, shadow, cx + offset, cy + offset)
    return paste(im, figure, cx, cy)

def paste(im, figure, cx, cy):
    im.alpha_composite(figure, (int(cx - figure.width / 2), int(cy - figure.height / 2)))
    return im

def text(im, t, size, cx, cy, anchor="mm"):
    ImageDraw.Draw(im).text((cx, cy), t, font=ImageFont.truetype(FONT, size), fill=WHITE, anchor=anchor)
    return im

def appids():
    for vdf in glob.glob(f"{STEAM}/userdata/*/config/shortcuts.vdf"):
        d = open(vdf, "rb").read()
        for m in re.finditer(rb'\x02appid\x00(.{4})\x01AppName\x00([^\x00]*)\x00', d, re.S):
            name = m.group(2).decode(errors="replace")
            rest = d[m.end():m.end() + 2048]
            options = re.search(rb'\x01LaunchOptions\x00([^\x00]*)\x00', rest)
            options = options.group(1).decode(errors="replace") if options else ""
            if re.search(r"vesktop|discord", name, re.I) or "Vesktop" in options:
                yield os.path.dirname(vdf), int.from_bytes(m.group(1), "little") & 0xFFFFFFFF, name

def main():
    done = 0
    for config, appid, name in appids():
        grid = f"{config}/grid"; os.makedirs(grid, exist_ok=True)
        previous = os.path.expanduser("~/.cache/art-vesktop-previous")
        old_previous = os.path.expanduser("~/.cache/arte-vesktop-anterior")   # the old Spanish name
        if os.path.isdir(old_previous) and not os.path.exists(previous):
            os.rename(old_previous, previous)
        os.makedirs(previous, exist_ok=True)
        for f in glob.glob(f"{grid}/{appid}*"):
            if not os.path.exists(f"{previous}/{os.path.basename(f)}"):
                shutil.copy2(f, previous)
        p = with_shadow(flat(600, 900, 0.5, 0.43, [(0.10, 0.17, 0.90, 0.84)]), vesktop_logo(380), 300, 390); text(p, "Vesktop", 92, 300, 690)
        p.convert("RGB").save(f"{grid}/{appid}p.png")
        c = with_shadow(flat(920, 430, 0.5, 0.38, [(0.27, 0.05, 0.73, 0.95)]), vesktop_logo(240), 460, 165); text(c, "Vesktop", 64, 460, 345)
        c.convert("RGB").save(f"{grid}/{appid}.png")
        # header: Steam puts the logo bottom left; halo there and the rest with bubbles
        flat(1920, 620, 0.22, 0.72, [(0.0, 0.38, 0.56, 1.0)]).convert("RGB").save(f"{grid}/{appid}_hero.png")
        logo = Image.new("RGBA", (1200, 400), (0, 0, 0, 0))
        logo.alpha_composite(vesktop_logo(340), (30, 30))
        text(logo, "Vesktop", 190, 400, 200, "lm")
        logo.save(f"{grid}/{appid}_logo.png")
        ico = vesktop_logo(512)
        ico.save(f"{grid}/{appid}_icon.png")
        os.makedirs(ICONS, exist_ok=True); ico.resize((256, 256), Image.LANCZOS).save(f"{ICONS}/discord-256.png")
        json.dump({"nVersion": 1, "logoPosition": {"pinnedPosition": "BottomLeft", "nWidthPct": 50, "nHeightPct": 50}},
                  open(f"{grid}/{appid}.json", "w"))
        print(_("art: %s/%s* (%s); the previous one, in %s; icon: %s/discord-256.png") % (grid, appid, name, previous, ICONS))
        done += 1
    if not done:
        print(_("I cannot find Vesktop's shortcut in shortcuts.vdf"))
    desktop()
    tray()

if sys.argv[1:] == ["--desktop"]:
    desktop()
else:
    main()
