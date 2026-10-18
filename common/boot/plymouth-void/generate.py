#!/usr/bin/env python3
"""generate.py — the frames of the Plymouth themes of install-plymouth.sh, and of Game Mode's loading screen.

Six animations: two logos (Steam and Void) in three forms.
  A  the firmware logo (BGRT: Lenovo's) in its place and, below, the small symbol spinning
     (the package's "bgrt" theme with other frames: two-step repeats throbber-0001.png … -NNNN.png);
  B  that same symbol, large and centred, without the firmware logo;
  C  Steam: the whole mechanism in a blue rectangle with STEAM at the bottom left;
     Void: Void's logo with the letters VOID, large and centred, its arcs spinning behind the letters.
Everything is drawn from vectors at the panel's size, so it is sharp on any screen:
  - Void: /usr/share/void-artwork/void-logo.svg (void-artwork), through rsvg-convert;
  - Steam: the mechanism of Steam's old loading animation is a slider-crank (the big circle fixed, the joint
    turning around it, the end sliding horizontally), measured on that animation (a 700x386 GIF of 186
    frames: the numbers below are in its pixels) and drawn with polygons and circles; the word STEAM, as
    outlines. Steam's logo and wordmark are Valve's trademarks (THIRD_PARTY.md).
Plymouth plays the frames at a fixed ~30 per second (two-step), and so does steam-loading: the speed is the
number of frames per turn. The frames are made at their final size and plymouthd.conf carries DeviceScale=1:
if Plymouth scaled them itself (it does on dense screens, like the Legion's), they would come out blurry.

Usage: generate.py <folder> <steam-a|steam-b|steam-c|void-a|void-b|void-c> <panel height px> [--preview W H out.png]
It writes the throbber-NNNN.png frames, the spinner's other images and <folder name>.plymouth (from bgrt's).
Needs rsvg-convert (librsvg-utils), Pillow and plymouth-data. docs/1-platform/3-boot.md.
Previous (Spanish) name: plymouth-void/generar.py.
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageDraw

LOGO_SVG = "/usr/share/void-artwork/void-logo.svg"
THEMES = os.environ.get("PLYMOUTH_THEMES", "/usr/share/plymouth/themes")   # another folder: previews only
SPINNER = THEMES + "/spinner"
BGRT = THEMES + "/bgrt/bgrt.plymouth"
VARIANTS = ("steam-a", "steam-b", "steam-c", "void-a", "void-b", "void-c")
NAMES = {"steam-a": "Steam A", "steam-b": "Steam B", "steam-c": "Steam C",
         "void-a": "Void A", "void-b": "Void B", "void-c": "Void C"}
BLUE = (25, 85, 170)         # #1955aa
VOID_FRAMES = 54             # Void: frames per turn (6.7° each), a turn every ~1.8 s
STEAM_SPEED = 1.5            # Steam: 1.5 times the original animation: 186 / 1.5 = 124 frames, ~4.1 s a cycle


def symbol_size(variant, height):
    """A: bgrt's gap (56 px per 768 of height at an integer scale: 56 on 1366x768, 112 on 1920x1200);
    B: large, 28 % of the panel's height (336 px on 1920x1200)."""
    if variant.endswith("-b"):
        return round(height * 0.28) // 2 * 2
    return 56 * max(1, (height + 384) // 768)


# ---- Void ----------------------------------------------------------------------------------------------
# Centre of the circle in the SVG's viewBox (252.06 square): circle cx=128 cy=105.2349 of the group "logo",
# with its transform matrix(0.97240747,0,0,0.97240747,1.5789588,23.699565).
K, DX, DY = 0.97240747, 1.5789588, 23.699565
VB = 252.06154
CX, CY = (K * 128 + DX) / VB, (K * 105.2349 + DY) / VB


def layer(drop, px):
    """The logo's SVG without the groups in drop (the white outline follows the rest), at px x px."""
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
    tree = ET.parse(LOGO_SVG)
    for parent in tree.iter():
        for child in list(parent):
            if child.get("id") in drop:
                parent.remove(child)
    with tempfile.TemporaryDirectory() as tmp:
        svg, png = os.path.join(tmp, "s.svg"), os.path.join(tmp, "s.png")
        ET.ElementTree(tree.getroot()).write(svg, encoding="unicode")
        subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", png, svg], check=True)
        return Image.open(png).convert("RGBA")


def void_symbol(px):
    """Void's symbol (arcs and dot, no letters or outline) centred in a px square with room to rotate."""
    s = layer(("letters", "border"), max(1024, px * 2))
    s = s.crop(s.getbbox())
    w, h = s.size
    d = int((w * w + h * h) ** 0.5) + 2
    canvas = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    canvas.paste(s, ((d - w) // 2, (d - h) // 2), s)
    return canvas.resize((px, px), Image.LANCZOS)


def rotate(img, degrees, centre):
    return img.rotate(-degrees, resample=Image.BICUBIC, center=centre)   # clockwise


def void_spinning(dest, size):
    """Void A and B: the symbol spinning."""
    big = void_symbol(size * 4)
    for i in range(VOID_FRAMES):
        rotate(big, 360 * i / VOID_FRAMES, None).resize((size, size), Image.LANCZOS).save(
            os.path.join(dest, f"throbber-{i + 1:04d}.png"))


def void_logo(dest, height):
    """Void C: the whole logo at 45 % of the height, the arcs and the dot spinning behind the letters."""
    side = round(height * 0.45) // 2 * 2
    big = side * 2
    arcs = layer(("letters",), big)                  # arcs + dot, with their outline
    letters = layer(("circlearcs",), big)            # letters, with their outline
    centre = (CX * big, CY * big)
    for i in range(VOID_FRAMES):
        f = rotate(arcs, 360 * i / VOID_FRAMES, centre)
        f.alpha_composite(letters)
        f.resize((side, side), Image.LANCZOS).save(os.path.join(dest, f"throbber-{i + 1:04d}.png"))


# ---- Steam's mechanism -----------------------------------------------------------------------------------
# In the original animation's pixels. The drawing matches it to ~1 px of edge (checked frame by frame).
MECH_BIG = (483.0, 198.0)        # centre of the big circle (fixed)
MECH_CRANK = 140.0               # from the big centre to the joint
MECH_ROD = 279.2                 # from the joint to the end
MECH_GUIDE_Y = 197.8             # the end slides along this horizontal
MECH_RB = (31.75, 40.75, 59.75)  # big circle: core, ring (a hole), disc
MECH_RS = (22.0, 28.75, 39.75)   # small circles
MECH_BAR = 21.5                  # half width of the long bar
MECH_LINK = (54.4, 20.9)         # half width of the link at the big centre and at the joint
MECH_CYCLE = 186                 # frames per turn in the original animation


def mech_positions(theta):
    t = math.radians(theta)
    joint = (MECH_BIG[0] + MECH_CRANK * math.cos(t), MECH_BIG[1] + MECH_CRANK * math.sin(t))
    end = (joint[0] - math.sqrt(max(0.0, MECH_ROD ** 2 - (joint[1] - MECH_GUIDE_Y) ** 2)), MECH_GUIDE_Y)
    return joint, end


def mech_mask(theta, size, scale, turn, ref, target, ss=4):
    """L mask (255 = mechanism; 0 = background and the hollow rings) of the given size: the point ref of the
    original goes to target (pixels), scale px per original px, turned clockwise turn degrees. Layers in the
    original's order: link, big circle, small circles and the long bar on top."""
    w, h = size
    im = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    c, s = math.cos(math.radians(turn)), math.sin(math.radians(turn))

    def at(p):
        x, y = p[0] - ref[0], p[1] - ref[1]
        return ((target[0] + scale * (x * c - y * s)) * ss, (target[1] + scale * (x * s + y * c)) * ss)
    k = scale * ss

    def circle(p, r, v):
        x, y = at(p)
        d.ellipse((x - r * k, y - r * k, x + r * k, y + r * k), fill=v)

    def bar(p, q, w1, w2):
        dx, dy = q[0] - p[0], q[1] - p[1]
        n = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / n, dx / n
        d.polygon([at((p[0] + nx * w1, p[1] + ny * w1)), at((q[0] + nx * w2, q[1] + ny * w2)),
                   at((q[0] - nx * w2, q[1] - ny * w2)), at((p[0] - nx * w1, p[1] - ny * w1))], fill=255)
    joint, end = mech_positions(theta)
    bar(MECH_BIG, joint, *MECH_LINK)
    for r, v in zip(reversed(MECH_RB), (255, 0, 255), strict=True):
        circle(MECH_BIG, r, v)
    for p in (joint, end):
        for r, v in zip(reversed(MECH_RS), (255, 0, 255), strict=True):
            circle(p, r, v)
    bar(joint, end, MECH_BAR, MECH_BAR)
    return im.resize((w, h), Image.LANCZOS)


def mech_angle(i, n, start):
    """Crank angle in frame i of n: an even turn (the original sped up a little and jumped at its loop)."""
    return start - 360.0 * i / n


def steam_badge(dest, size):
    """Steam A and B: the mechanism in white inside a blue circle, cut to the circle (soft edge), in a size x
    size gap (the circle at 80 %). The first frame is the pose of Steam's logo (the original's frame 116,
    turned 2° clockwise)."""
    r = size * 45 / 56 / 2.0
    cx = cy = size / 2.0
    big = Image.new("L", (size * 8, size * 8), 0)
    ImageDraw.Draw(big).ellipse(((cx - r) * 8, (cy - r) * 8, (cx + r) * 8 - 1, (cy + r) * 8 - 1), fill=255)
    disc = big.resize((size, size), Image.LANCZOS)   # the blue and the mechanism end at the same edge
    target = (cx + 0.4344 * r, cy - 0.2371 * r)      # where the big circle goes in the logo
    scale = (0.505 / 75.5) * r
    blue = Image.new("RGB", (size, size), BLUE)
    white = Image.new("RGB", (size, size), (255, 255, 255))
    n = round(MECH_CYCLE / STEAM_SPEED)
    for i in range(n):
        m = mech_mask(mech_angle(i, n, -223.59), (size, size), scale, 2.0, MECH_BIG, target)
        f = Image.composite(white, blue, m).convert("RGBA")
        f.putalpha(disc)
        f.save(os.path.join(dest, f"throbber-{i + 1:04d}.png"))


# The word STEAM, as outlines traced from Steam's logo (a DIN-like bold): T, E, A and M rebuilt with exact
# straight lines, the S its smoothed outline. In units of the letters' height (0..1); WORD_WIDTH wide.
WORD_WIDTH = 4.9355
WORD = [
    # S
    [(0.2565, 0.0081), (0.2196, 0.0182), (0.1845, 0.0311), (0.1526, 0.047), (0.1333, 0.0593), (0.1071, 0.0807),
     (0.0836, 0.1055), (0.0633, 0.1328), (0.0517, 0.1527), (0.0416, 0.1742), (0.0294, 0.2093),
     (0.0239, 0.2349), (0.0208, 0.2641), (0.02, 0.3112), (0.0218, 0.342), (0.0258, 0.3698), (0.0363, 0.4059),
     (0.0458, 0.4282), (0.0569, 0.4488), (0.0698, 0.4675), (0.0846, 0.4847), (0.101, 0.5004), (0.1189, 0.5142),
     (0.1595, 0.5372), (0.1932, 0.5511), (0.2437, 0.5646), (0.2979, 0.5746), (0.3794, 0.5858), (0.4203, 0.594),
     (0.4441, 0.6021), (0.4751, 0.6188), (0.4924, 0.6333), (0.4998, 0.6418), (0.5118, 0.6613),
     (0.5162, 0.6721), (0.5215, 0.6958), (0.5222, 0.7084), (0.5215, 0.7211), (0.5162, 0.7449),
     (0.5066, 0.7663), (0.5002, 0.7759), (0.4844, 0.7921), (0.4651, 0.8046), (0.4431, 0.8143),
     (0.4191, 0.8214), (0.3918, 0.826), (0.3612, 0.8283), (0.3296, 0.8285), (0.2983, 0.8268), (0.2693, 0.8233),
     (0.2315, 0.8154), (0.2072, 0.8077), (0.1846, 0.7982), (0.1255, 0.7644), (0.1165, 0.7611),
     (0.1077, 0.7601), (0.0992, 0.7619), (0.0909, 0.7663), (0.0747, 0.7799), (0.0125, 0.8439),
     (0.0019, 0.8603), (0.0, 0.8687), (0.001, 0.8772), (0.0046, 0.8857), (0.0172, 0.902), (0.0336, 0.917),
     (0.0518, 0.9309), (0.0714, 0.9433), (0.0921, 0.9541), (0.1255, 0.9682), (0.149, 0.9762), (0.1876, 0.9851),
     (0.2682, 0.9977), (0.3453, 1.0), (0.376, 0.9988), (0.4037, 0.9958), (0.4422, 0.9882), (0.4807, 0.9785),
     (0.5154, 0.966), (0.5479, 0.951), (0.578, 0.9335), (0.6056, 0.9135), (0.6305, 0.8904), (0.6453, 0.8732),
     (0.6647, 0.8451), (0.6759, 0.8246), (0.6853, 0.802), (0.6956, 0.7657), (0.6998, 0.7388), (0.7014, 0.6929),
     (0.6979, 0.6486), (0.6926, 0.6232), (0.6851, 0.5995), (0.6758, 0.5771), (0.6589, 0.5465),
     (0.6459, 0.5277), (0.6313, 0.5103), (0.6067, 0.487), (0.5886, 0.4732), (0.5594, 0.4552), (0.5269, 0.4398),
     (0.4796, 0.4241), (0.4539, 0.4188), (0.3153, 0.3969), (0.2889, 0.3912), (0.255, 0.3781), (0.2357, 0.3655),
     (0.2273, 0.3578), (0.2134, 0.3399), (0.2037, 0.3187), (0.1992, 0.2938), (0.199, 0.2805), (0.203, 0.2551),
     (0.2117, 0.2331), (0.2243, 0.2141), (0.2319, 0.2059), (0.2497, 0.1921), (0.26, 0.1864), (0.283, 0.1772),
     (0.3073, 0.1706), (0.3328, 0.1667), (0.3755, 0.1661), (0.4146, 0.1712), (0.4641, 0.185), (0.5295, 0.2139),
     (0.5404, 0.217), (0.5514, 0.2178), (0.5621, 0.216), (0.5721, 0.2115), (0.5897, 0.1979), (0.6441, 0.1415),
     (0.6555, 0.1252), (0.6581, 0.1172), (0.6577, 0.1093), (0.6543, 0.1017), (0.6405, 0.0873),
     (0.6226, 0.0738), (0.5932, 0.0557), (0.5617, 0.0398), (0.5392, 0.0304), (0.4903, 0.0152),
     (0.4386, 0.0043), (0.3772, 0.0), (0.3138, 0.0006), (0.2835, 0.0033)],
    # T
    [(0.949, 0.0079), (0.949, 0.1793), (1.2093, 0.1793), (1.2093, 0.9839), (1.4156, 0.9839), (1.4156, 0.1793),
     (1.6505, 0.1793), (1.6505, 0.0079)],
    # E
    [(1.9615, 0.0079), (1.9615, 0.9839), (2.6026, 0.9839), (2.6026, 0.8205), (2.171, 0.8205), (2.171, 0.5792),
     (2.5534, 0.5792), (2.5534, 0.4158), (2.171, 0.4158), (2.171, 0.1762), (2.6026, 0.1762), (2.6026, 0.0079)],
    # A
    [(3.2866, 0.0079), (2.9153, 0.9839), (3.1105, 0.9839), (3.1739, 0.8173), (3.5136, 0.8173),
     (3.5723, 0.9839), (3.7659, 0.9839), (3.4183, 0.0079)],
    # the counter of the A (a hole)
    [(3.2469, 0.6491), (3.4644, 0.6491), (3.3596, 0.2936)],
    # M
    [(4.0468, 0.0079), (4.0468, 0.9839), (4.2547, 0.9839), (4.2547, 0.438), (4.4411, 0.7856), (4.5745, 0.7856),
     (4.7609, 0.438), (4.7609, 0.9839), (4.9355, 0.9839), (4.9355, 0.0079), (4.7609, 0.0079), (4.5078, 0.5269),
     (4.2547, 0.0079)],
]
WORD_HOLE = 4


def word_mask(height, ss=8):
    """L mask of the word STEAM, height px high."""
    w = round(WORD_WIDTH * height)
    im = Image.new("L", (w * ss, height * ss), 0)
    d = ImageDraw.Draw(im)
    k = height * ss
    for i, loop in enumerate(WORD):
        d.polygon([(x * k, y * k) for x, y in loop], fill=0 if i == WORD_HOLE else 255)
    return im.resize((w, height), Image.LANCZOS)


def steam_card(dest, height):
    """Steam C: the whole mechanism in white in a blue rectangle with slightly rounded corners and STEAM at
    the bottom left, like Steam's logo. The rectangle holds the box of EVERY frame plus a margin, so the
    figure never leaves it; if in some frame the mechanism came near the word, the rectangle grows downwards
    until they do not touch. The mechanism is 85 % of 45 % of the panel's height wide (459 px on 1920x1200)."""
    side = round(height * 0.45) // 2 * 2
    n = round(MECH_CYCLE / STEAM_SPEED)
    box = None                                        # box of the figure in all the frames, original's px
    for i in range(n):
        b = mech_mask(mech_angle(i, n, 0.0), (700, 386), 1.0, 0.0, (0, 0), (0, 0), ss=1).getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    ref = ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2)
    scale = (side * 0.85) / (box[2] - box[0])
    margin = 0.07 * (box[2] - box[0]) * scale
    rw = round((box[2] - box[0]) * scale + 2 * margin) // 2 * 2
    rh0 = round((box[3] - box[1]) * scale + 2 * margin) // 2 * 2       # the mechanism's area
    masks = []
    union = Image.new("L", (rw, rh0), 0)              # where the mechanism passes in some frame
    for i in range(n):
        m = mech_mask(mech_angle(i, n, 0.0), (rw, rh0), scale, 0.0, ref, (rw / 2, rh0 / 2))
        masks.append(m)
        union = ImageChops.lighter(union, m)
    th = max(8, round(0.092 * (box[2] - box[0]) * scale))   # the word: ~9 % of the mechanism's width high
    word = word_mask(th)
    tw, tx = word.width, round(margin)
    gap = round(0.45 * th)                            # minimum space between mechanism and letters
    busy = union.point(lambda v: 255 if v > 24 else 0)
    extra = 0
    while True:
        rh = rh0 + extra
        y0 = max(0, rh - round(margin) - th - gap)
        if y0 >= rh0 or busy.crop((max(0, tx - gap), y0, min(rw, tx + tw + gap), rh0)).getbbox() is None:
            break
        extra += 2
    rh = (rh + 1) // 2 * 2
    big = Image.new("L", (rw * 4, rh * 4), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, rw * 4 - 1, rh * 4 - 1), radius=0.06 * rh0 * 4, fill=255)
    shape = big.resize((rw, rh), Image.LANCZOS)
    card = Image.new("RGBA", (rw, rh), BLUE + (255,))
    letters = Image.new("RGBA", word.size, (255, 255, 255, 0))
    letters.putalpha(word)
    card.alpha_composite(letters, (tx, rh - round(margin) - th))
    white = Image.new("RGBA", (rw, rh0), (255, 255, 255, 255))
    for i, m in enumerate(masks):
        f = card.copy()
        f.paste(white, (0, 0), m)
        f.putalpha(shape)
        f.save(os.path.join(dest, f"throbber-{i + 1:04d}.png"))


# ---- theme -----------------------------------------------------------------------------------------------
def generate(dest, variant, height):
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(dest):
        if f.startswith(("throbber-", "watermark")):
            os.remove(os.path.join(dest, f))
    if os.path.isdir(SPINNER):                        # password, keyboard, lock… (not the frames)
        for f in os.listdir(SPINNER):
            if f.endswith(".png") and not f.startswith(("throbber-", "animation-", "watermark")):
                shutil.copy(os.path.join(SPINNER, f), dest)
    if variant == "void-c":
        void_logo(dest, height)
    elif variant == "steam-c":
        steam_card(dest, height)
    elif variant.startswith("steam"):
        steam_badge(dest, symbol_size(variant, height))
    else:
        void_spinning(dest, symbol_size(variant, height))
    firmware = variant.endswith("-a")
    out = []
    for line in open(BGRT, encoding="utf-8").read().split("\n"):
        if line.startswith("Name["):
            continue
        if line.startswith("Name="):
            line = "Name=" + NAMES[variant]
        elif line.startswith("Description="):
            line = "Description=%s (void-legion-go2, common/boot/install-plymouth.sh)" % NAMES[variant]
        elif line.startswith("ImageDir="):
            line = "ImageDir=" + dest
        elif firmware:
            pass                                      # A: the rest as in bgrt
        elif line.startswith("VerticalAlignment="):
            line = "VerticalAlignment=.5"             # B and C: centred
        elif line.startswith("UseFirmwareBackground="):
            line = "UseFirmwareBackground=false"
        out.append(line)
    name = os.path.basename(os.path.normpath(dest))
    open(os.path.join(dest, name + ".plymouth"), "w", encoding="utf-8").write("\n".join(out))


def preview(dest, variant, width, height, out):
    """A full screen with the first frame where two-step puts it (the firmware logo only if it exists here)."""
    screen = Image.new("RGB", (width, height), (0, 0, 0))
    frame = Image.open(os.path.join(dest, "throbber-0001.png"))
    va = 0.70 if variant.endswith("-a") else 0.5
    if variant.endswith("-a") and os.path.exists("/sys/firmware/acpi/bgrt/image"):
        try:
            logo = Image.open("/sys/firmware/acpi/bgrt/image")
            x = int(open("/sys/firmware/acpi/bgrt/xoffset").read())
            y = int(open("/sys/firmware/acpi/bgrt/yoffset").read())
            screen.paste(logo, (x, y))
        except (OSError, ValueError):
            pass
    screen.paste(frame, (round(width * .5 - frame.width / 2), round(height * va - frame.height / 2)), frame)
    screen.save(out)


if __name__ == "__main__":
    if len(sys.argv) < 4 or sys.argv[2] not in VARIANTS:
        sys.exit("generate.py <folder> <%s> <panel height px> [--preview W H out.png]" % "|".join(VARIANTS))
    folder, variant, panel = sys.argv[1], sys.argv[2], int(sys.argv[3])
    generate(folder, variant, panel)
    if "--preview" in sys.argv:
        i = sys.argv.index("--preview")
        preview(folder, variant, int(sys.argv[i + 1]), int(sys.argv[i + 2]), sys.argv[i + 3])
