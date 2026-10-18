#!/usr/bin/env python3
"""pieces.py — checks install/pieces.tsv against the repository (run by install/verify.sh; docs/8-maintenance/4-this-repository.md):
every tracked file of common/, legion/, lib/ and install/ belongs to exactly one piece (as a file to one xbps package);
each piece's installer, page and sources exist; its "undo" is possible (--remove: its installer takes it; rm: copies in ~);
a "root"/"user" piece is in install/install.sh and in docs/reinstall.md or its page; a "manual" one is named in its page;
a "via:<id>" one is named by that piece's installer. Prints one line per problem; exit 1 if any.
   python3 install/pieces.py [--list]     (--list: the pieces, for people and the audit's index)"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLS = ["id", "machines", "stage", "how", "installer", "doc", "sources", "installs", "undo"]


def load(path=os.path.join(ROOT, "install", "pieces.tsv")):
    rows, bad = [], []
    with open(path, encoding="utf-8") as f:
        text = f.read().splitlines()
    for n, line in enumerate(text, 1):
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
        with open(os.path.join(ROOT, p), encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def named(text, name):
    """Whether text names that file: as a word of its own, not inside a longer name (install-x.sh ≠ re-install-x.sh)."""
    return re.search(r"(?<![\w.-])" + re.escape(name) + r"(?![\w.-])", text) is not None


INSTALLS = re.compile(r"^(/|~/|grep:/[^:]+:.+$|xbps-local:[\w.+-]+$)")


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
        if how != "tool":
            if r["machines"] == "-":
                bad.append("%s: an installed piece says on which machines (L, I, LI)" % where)
            if r["installs"] in ("", "-") and how != "manual":
                bad.append("%s: an installed piece says what proves it is there (installs)" % where)
            for q in r["installs"].split():
                if q != "-" and not INSTALLS.match(q):
                    bad.append("%s: installs %r: a path, grep:<file>:<regex> or xbps-local:<package>" % (where, q))
        undo = r["undo"]
        if how == "tool":
            if undo != "-":
                bad.append("%s: a tool has no undo (-)" % where)
        elif undo in ("", "-"):
            bad.append("%s: every installed piece says how it is undone (undo)" % where)
        elif undo == "--remove":
            if not re.search(r"is_remove|--remove|--undo", read(r["installer"]) if r["installer"] != "-" else ""):
                bad.append("%s: undo --remove, but %s does not take --remove" % (where, r["installer"]))
        elif undo == "rm":
            if r["installs"] == "-" or not all(q.startswith("~/") for q in r["installs"].split()):
                bad.append("%s: undo rm is only for copies in ~ (its installs)" % where)
        elif undo == "via" and not how.startswith("via:"):
            bad.append("%s: undo via, but how is not via:<id>" % where)
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
            if not named(install_sh, base):
                bad.append("%s: %s is not in install/install.sh (stage %s)" % (where, base, r["stage"]))
            if not named(reinstall, base) and not named(read(r["doc"]), base):
                bad.append("%s: %s is in neither docs/reinstall.md nor %s" % (where, base, r["doc"]))
        elif how == "manual":
            if not named(read(r["doc"]), base):
                bad.append("%s: %s is not named in its page %s" % (where, base, r["doc"]))
        elif how.startswith("via:"):
            parent = ids.get(how[4:])
            if not parent:
                bad.append("%s: %s: no piece with that id" % (where, how))
            elif not named(read(parent["installer"]), base) and not any(
                    named(read(s), base) for s in parent["sources"].split() if os.path.isfile(os.path.join(ROOT, s))):
                bad.append("%s: %s does not name %s" % (where, parent["installer"], base))
    # every tracked file belongs to a piece
    files = subprocess.run(["git", "-C", ROOT, "ls-files", "common", "legion", "lib", "install"],
                           capture_output=True, text=True).stdout.split()
    for f in files:
        owners = [r["id"] for r in rows for s in r["sources"].split()
                  if s != "-" and (f == s or (s.endswith("/") and f.startswith(s)))]
        if not owners:
            bad.append("%s: belongs to no piece of install/pieces.tsv" % f)
        elif len(set(owners)) > 1:
            bad.append("%s: belongs to several pieces (%s): one owner, as in a package" % (f, ", ".join(sorted(set(owners)))))
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
