#!/bin/bash
# render.sh — makes build/: a copy of the whole clone with every @NAME@ replaced by its real value from
# local.env, and @TARGET_HOME@ / @TARGET_USER@ by the home and name of the user who runs it (without root).
# The recipe's blocks copy and run everything from there ("$B" = <repo>/build), so the files land on the
# system exactly as they were on the original machine. Repeat it after editing local.env or pulling.
#
#   bash install/render.sh            (re)makes build/
#   bash install/render.sh --check    only lists the @NAME@ that local.env lacks (exit 1 if any)
#
# Text files are rendered; binaries (fonts, packages, images…) are hard-linked (copied if that is not
# possible); file modes are kept. build/local.env is a link to local.env (the scripts read it from their
# root). Not rendered: .git/ and build/ itself. build/ is git-ignored: it holds the real values.
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
# A fresh clone: local.env comes from its encrypted copy (asks the passphrase; install/secrets.sh)
if [ ! -e "$REPO_ROOT/local.env" ] && [ -s "$REPO_ROOT/local.env.age" ]; then bash "$REPO_ROOT/install/secrets.sh" open; fi
[ -r "$REPO_ROOT/local.env" ] || { t "Missing %s (copy local.env.example to local.env and fill it in)." "$REPO_ROOT/local.env"; exit 1; }
python3 -I - "$REPO_ROOT" "${1:-}" "$HOME" "$(id -un)" <<'PY'
import os, re, sys, shutil
root, mode, home, user = sys.argv[1:5]
sys.path.insert(0, os.path.join(root, "lib"))
from void_legion_i18n import _   # messages through the translation catalog (docs/i18n.md)
vals = {"TARGET_HOME": home, "TARGET_USER": user}
for l in open(os.path.join(root, "local.env"), encoding="utf-8"):
    m = re.match(r"^\s*([A-Z0-9_]+)=(.*)$", l.rstrip("\n"))
    if m:
        v = m.group(2).strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
            v = v[1:-1]
        vals[m.group(1)] = v
ph = re.compile(rb"@([A-Z][A-Z0-9_]*)@")
# Words between @…@ that are not placeholders (e.g. in e-mail-like text): only those listed in
# local.env.example are placeholders.
known = set()
for l in open(os.path.join(root, "local.env.example"), encoding="utf-8"):
    m = re.match(r"^\s*#?\s*([A-Z0-9_]+)=", l)
    if m:
        known.add(m.group(1))
known |= {"TARGET_HOME", "TARGET_USER"}
def binary(data):
    return b"\0" in data[:8192]
missing = set()
out = os.path.join(root, "build")
skip = {".git", "build"}
files = []
for d, dn, fn in os.walk(root):
    rel = os.path.relpath(d, root)
    dn[:] = [x for x in dn if not (rel == "." and (x in skip or x.startswith("build."))) and x != "__pycache__"]
    for f in fn:
        if rel == "." and f == "local.env":
            continue
        files.append(os.path.normpath(os.path.join(rel, f)))
for rel in files:
    data = open(os.path.join(root, rel), "rb").read()
    if not binary(data):
        for m in ph.finditer(data):
            n = m.group(1).decode()
            if n in known and n not in vals:
                missing.add(n)
if mode == "--check":
    for n in sorted(missing):
        print(_("missing in local.env: %s") % n)
    sys.exit(1 if missing else 0)
if missing:
    print(_("!! local.env lacks: %s (those stay as @NAME@ in build/)") % " ".join(sorted(missing)))
import time
def clear(path):
    """Removes path; if something in it cannot be removed (e.g. a root-owned __pycache__ left by an installer run
    with sudo), it is moved aside (renaming only needs the parent folder) and the command to delete it is shown."""
    if not os.path.lexists(path):
        return
    shutil.rmtree(path, ignore_errors=True)
    if os.path.lexists(path):
        aside = f"{path}.old-{int(time.time())}"
        os.rename(path, aside)
        print(_("!! %s had files that cannot be removed without root: moved to %s; delete it with: sudo rm -rf %s")
              % (os.path.basename(path), os.path.basename(aside), aside))
tmp = out + ".tmp"
clear(tmp)
for rel in files:
    src = os.path.join(root, rel); dst = os.path.join(tmp, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.islink(src):
        os.symlink(os.readlink(src), dst); continue
    data = open(src, "rb").read()
    if binary(data):
        try:
            os.link(src, dst)
        except OSError:
            shutil.copy2(src, dst)
        continue
    new = ph.sub(lambda m: vals[m.group(1).decode()].encode() if m.group(1).decode() in known and m.group(1).decode() in vals else m.group(0), data)
    with open(dst, "wb") as f:
        f.write(new)
    shutil.copymode(src, dst)
os.symlink(os.path.join(root, "local.env"), os.path.join(tmp, "local.env"))
clear(out)
os.rename(tmp, out)
print(_("build/: %s files") % len(files))
PY
