#!/usr/bin/env python3
"""remove-loading.py — removes (or gives back) the "Loading Linux …", "Loading initial ramdisk …" and
"Loading devicetree …" that GRUB writes when booting each entry; with the theme they opened a black
box on top of the menu. They are in /etc/grub.d/10_linux as one echo line per message: it is
turned into a marked comment (it goes like that into grub.cfg, where GRUB ignores it) and --remove gives
it back as it was. 10_linux is a configuration file of the grub package: the change survives
updates (xbps leaves the new version as .new-*).
Usage: remove-loading.py /etc/grub.d/10_linux [--remove]    (then update-grub)
Previous (Spanish) name: quitar-loading.py. Its marker was "# arranque-silencioso: echo del mensaje de carga
quitado": it is recognized too, and normalized to the English one when applying.
docs/1-platform/3-boot.md.
"""
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "lib"))
try:
    from void_legion_i18n import _
except ImportError:
    def _(s):
        return s

ORIG = "\techo\t'$(echo \"$message\" | grub_quote)'"
MARK = "\t# silent-boot: echo of the loading message removed"
OLD_MARK = "\t# arranque-silencioso: echo del mensaje de carga quitado"

path = sys.argv[1]
give_back = len(sys.argv) > 2 and sys.argv[2] == "--remove"
lines = open(path, encoding="utf-8").read().split("\n")
n = 0
for i, line in enumerate(lines):
    if give_back and line in (MARK, OLD_MARK):
        lines[i] = ORIG
        n += 1
    elif not give_back and line == ORIG:
        lines[i] = MARK
        n += 1
    elif not give_back and line == OLD_MARK:
        lines[i] = MARK
open(path, "w", encoding="utf-8").write("\n".join(lines))
print(_("== %s: %d lines changed") % (path, n))
