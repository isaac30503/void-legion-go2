#!/usr/bin/env python3
"""pieces.py — checks install/pieces.tsv against the repository (run by install/verify.sh; docs/8-maintenance/4-this-repository.md):
every tracked file of common/, legion/, lib/ and install/ belongs to a piece; each piece's installer, page and sources exist;
a "root"/"user" piece is in install/install.sh and in docs/reinstall.md or its page; a "manual" one is named in its page;
a "via:<id>" one is named by that piece's installer. Prints one line per problem; exit 1 if any.
   python3 install/pieces.py [--list]     (--list: the pieces, for people and the audit's index)"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLS = ["id", "machines", "stage", "how", "installer", "doc", "sources", "installs"]


def load(path=os.path.join(ROOT, "install", "pieces.tsv")):
    rows, bad = [], []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line or line.startswith("#") or line.startswith("id\t"):
            continue
        f = line.split("\t")
        if len(f) != len(COLS):
            bad.append("pieces.tsv:%d: %d columns, not %d" % (n, len(f), len(COLS)))
            continue
        rows.append(dict(zip(COLS, f), line=n))
    return rows, bad


def read(p):
    try:
        return open(os.path.join(ROOT, p), encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def check():
    rows, bad = load()
    ids = {}
    for r in rows:
        where = "pieces.tsv:%d (%s)" % (r["line"], r["id"])
        if r["id"] in ids:
            bad.append("%s: id repeated" % where)
        ids[r["id"]] = r
        if r["machines"] not in ("L", "I", "LI", "-"):
            bad.append("%s: machines must be L, I, LI or -" % where)
        if not (r["stage"] == "-" or r["stage"].isdigit() and 1 <= int(r["stage"]) <= 19):
            bad.append("%s: stage must be 1-19 or -" % where)
        how = r["how"]
        if how not in ("root", "user", "manual", "tool") and not how.startswith("via:"):
            bad.append("%s: how must be root, user, manual, via:<id> or tool" % where)
        if how != "tool" and (r["machines"] == "-" or r["installs"] == ""):
            bad.append("%s: an installed piece needs machines" % where)
        for p in [r["doc"]] + ([r["installer"]] if r["installer"] != "-" else []):
            if not os.path.exists(os.path.join(ROOT, p)):
                bad.append("%s: %s does not exist" % (where, p))
        for s in r["sources"].split():
            if s != "-" and not os.path.exists(os.path.join(ROOT, s)):
                bad.append("%s: source %s does not exist" % (where, s))
    install_sh, reinstall = read("install/install.sh"), read("docs/reinstall.md")
    for r in rows:
        where = "pieces.tsv:%d (%s)" % (r["line"], r["id"])
        how, inst = r["how"], r["installer"]
        if inst == "-":
            continue
        # a folder (common/fish/functions/) is named by its last two parts ("fish/functions")
        base = "/".join(inst.rstrip("/").split("/")[-2:]) if inst.endswith("/") else os.path.basename(inst)
        if how in ("root", "user"):
            if base not in install_sh:
                bad.append("%s: %s is not in install/install.sh (stage %s)" % (where, base, r["stage"]))
            if base not in reinstall and base not in read(r["doc"]):
                bad.append("%s: %s is in neither docs/reinstall.md nor %s" % (where, base, r["doc"]))
        elif how == "manual":
            if base not in read(r["doc"]):
                bad.append("%s: %s is not named in its page %s" % (where, base, r["doc"]))
        elif how.startswith("via:"):
            parent = ids.get(how[4:])
            if not parent:
                bad.append("%s: %s: no piece with that id" % (where, how))
            elif base not in read(parent["installer"]) and not any(
                    base in read(s) for s in parent["sources"].split() if os.path.isfile(os.path.join(ROOT, s))):
                bad.append("%s: %s does not name %s" % (where, parent["installer"], base))
    # every tracked file belongs to a piece
    files = subprocess.run(["git", "-C", ROOT, "ls-files", "common", "legion", "lib", "install"],
                           capture_output=True, text=True).stdout.split()
    srcs = [s for r in rows for s in r["sources"].split() if s != "-"]
    for f in files:
        if not any(f == s or (s.endswith("/") and f.startswith(s)) for s in srcs):
            bad.append("%s: belongs to no piece of install/pieces.tsv" % f)
    return bad


if __name__ == "__main__":
    if sys.argv[1:] == ["--list"]:
        rows, _ = load()
        for r in rows:
            print("\t".join(r[c] for c in COLS))
        sys.exit(0)
    problems = check()
    for p in problems:
        print(p)
    sys.exit(1 if problems else 0)
