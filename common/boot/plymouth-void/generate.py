#!/usr/bin/env python3
"""generate.py — Plymouth theme "bgrt-void": "bgrt"'s (Lenovo logo from the firmware) with
Void's symbol spinning instead of the loading circle.
The bgrt theme is the two-step plugin with the images of "spinner": while booting it repeats
throbber-0001.png … throbber-NNNN.png. Here those frames are generated with Void's symbol
(without the word VOID, original colors), rotated 360°/N in each one; the rest of the images
(password, keyboard…) are copied from spinner.
Usage: generate.py <destination folder> [scale]      (install-plymouth.sh calls it with
     /usr/share/plymouth/themes/bgrt-void and the panel's scale: 1 on 1366x768, 2 on 1920x1200).
The frames are already drawn at their final size and plymouthd.conf carries DeviceScale=1: if Plymouth
scaled them itself (it does so by itself on dense screens, like the Legion's), they would come out blurry.
It needs rsvg-convert (librsvg-utils) and Pillow. Previous (Spanish) name: plymouth-void/generar.py.
Void recipe, step 8.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image

LOGO_SVG = "/usr/share/void-artwork/void-logo.svg"
SPINNER = "/usr/share/plymouth/themes/spinner"
BGRT = "/usr/share/plymouth/themes/bgrt/bgrt.plymouth"
SCALE = int(sys.argv[2]) if len(sys.argv) > 2 else 1    # set by install-plymouth.sh according to the panel
SIZE = 56 * SCALE # px of the frame (spinner's circle is 32); 56 on the IdeaPad, 112 on the Legion
FRAMES = 36       # 10° per frame; two-step plays them at ~30 per second: a bit more than 1 s per turn
SUPER = 4         # it is drawn at SIZE*SUPER and reduced: smooth edges when rotating


def symbol(px):
    """Void's symbol (two arcs and the dot) in RGBA, centered in a square of px."""
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")
    tree = ET.parse(LOGO_SVG)
    for parent in tree.iter():
        for child in list(parent):
            if child.get("id") in ("letters", "border"):
                parent.remove(child)
    with tempfile.TemporaryDirectory() as tmp:
        svg, png = os.path.join(tmp, "s.svg"), os.path.join(tmp, "s.png")
        ET.ElementTree(tree.getroot()).write(svg, encoding="unicode")
        subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "-o", png, svg], check=True)
        img = Image.open(png).convert("RGBA")
    img = img.crop(img.getbbox())
    # Square whose inscribed circle contains the whole rotated symbol
    w, h = img.size
    side = int((w * w + h * h) ** 0.5) + 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - w) // 2, (side - h) // 2), img)
    return canvas.resize((px, px), Image.LANCZOS)


def main():
    dest = sys.argv[1]
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(SPINNER):           # password, keyboard, lock… (not the frames)
        if f.endswith(".png") and not f.startswith(("throbber-", "animation-")):
            shutil.copy(os.path.join(SPINNER, f), dest)
    for f in os.listdir(dest):
        if f.startswith("throbber-"):
            os.remove(os.path.join(dest, f))
    base = symbol(SIZE * SUPER)
    for i in range(FRAMES):
        frame = base.rotate(-360 * i / FRAMES, resample=Image.BICUBIC)   # clockwise
        frame.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(dest, f"throbber-{i + 1:04d}.png"))
    conf = open(BGRT, encoding="utf-8").read()
    conf = "\n".join(l for l in conf.split("\n") if not l.startswith("Name["))
    conf = conf.replace("Name=BGRT", "Name=BGRT Void")
    conf = conf.replace("Description=Jimmac's spinner theme using the ACPI BGRT graphics as background",
                        "Description=BGRT (the firmware logo) with Void's symbol spinning; Void recipe, step 8")
    conf = conf.replace(f"ImageDir={SPINNER}", f"ImageDir={dest}")
    assert f"ImageDir={dest}" in conf
    open(os.path.join(dest, "bgrt-void.plymouth"), "w", encoding="utf-8").write(conf)
    print(f"{dest}: {FRAMES} frames of {SIZE}px")


if __name__ == "__main__":
    main()
