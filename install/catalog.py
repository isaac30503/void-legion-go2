#!/usr/bin/env python3
"""catalog.py — the translatable messages of the scripts against the catalogs (locale/<lang>/messages.po).

    python3 install/catalog.py check    every message has an entry and every entry is used (exit 1 if not)
    python3 install/catalog.py refs     rewrites the "#: file …" comment of every entry from where it is used
    python3 install/catalog.py list     every message found, with its files (to see what the extraction sees)

What counts as a message (docs/i18n.md):
  - shell: the first argument of t, and of tr_ (patch-still-needed); in void-update also of step, ok, info,
    warn and err, the second of ask, and every argument but the first of _u (its help);
  - fish: the first argument of __vl_t;
  - Python (also inside shell heredocs): _("…"), with adjacent literals joined;
  - install/install.sh: the stage titles and the "# " lines of the stages that are prose (the indented
    "#   command" lines are shown as they are).
An argument with a variable or a command substitution is not a message: it is translated where it is built.
Run by install/verify.sh (all modes, also --ci).
"""
import ast
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
SKIP_EXT = (".md", ".po", ".patch", ".xbps", ".gz", ".zst", ".png", ".svg", ".ttf", ".xpm", ".vdf", ".xml",
            ".rc", ".css", ".conf", ".tsv", ".txt", ".desktop", ".service", ".rules", ".c", ".h", ".json", ".yml")


def tracked():
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                         capture_output=True, text=True, check=True).stdout.split("\n")
    return [f for f in out if f and os.path.isfile(f) and not f.startswith(("locale/", "docs/", "LICENSES/"))
            and not f.endswith(SKIP_EXT)]


def kind(path, text):
    first = text.split("\n", 1)[0]
    if path.endswith(".py") or "python" in first[:40]:
        return "py"
    if path.endswith(".fish"):
        return "fish"
    if path.endswith(".sh") or re.match(r"#!\s*/(usr/)?bin/(env )?(ba)?sh", first):
        return "sh"
    return None


# ---- shell and fish literals -------------------------------------------------------------------------------
DQ = r'"((?:[^"\\]|\\.)*)"'
SQ = r"'([^']*)'"


def sh_unquote(m):
    """(value, dynamic) of a matched literal: dynamic if a double-quoted one expands something."""
    if m.group(1) is not None:
        raw = m.group(1)
        if re.search(r'(?<!\\)\$[A-Za-z_{(@*0-9#?!-]|(?<!\\)`', raw):
            return raw, True
        return re.sub(r'\\([\\"$`])', r"\1", raw), False
    return m.group(2), False


LIT = re.compile(DQ + "|" + SQ)


def first_arg_calls(text, names, skip=0):
    """Literals given as argument number skip+1 to any of the functions in names."""
    pat = re.compile(r'(?:^|(?<=[\s;|&({`]))(?:' + "|".join(names) + r')[ \t]+')
    for m in pat.finditer(text):
        pos = m.end()
        for _ in range(skip):      # skip that many plain words
            w = re.match(r'(?:' + DQ + "|" + SQ + r'|[^\s"\']+)[ \t]+', text[pos:])
            if not w:
                break
            pos += w.end()
        lit = LIT.match(text, pos)
        if lit:
            yield sh_unquote(lit)


def usage_calls(text):
    """void-update's _u NAME DESC [MORE…]: every literal after the first, over continuation lines."""
    for m in re.finditer(r'^\s*_u ((?:.*\\\n)*.*)$', text, re.M):
        lits = [sh_unquote(x) for x in LIT.finditer(m.group(1))]
        yield from lits[1:]


def install_stages(text):
    for m in re.finditer(r"^stage " + DQ + r" \w+ \\\n'((?:[^']|'\"'\"')*)'", text, re.M):
        yield m.group(1), False
        for line in m.group(2).replace("'\"'\"'", "'").split("\n"):
            if line.startswith("# ") and not line.startswith("#  "):
                yield line[2:], False


# ---- Python ------------------------------------------------------------------------------------------------
def py_calls(source):
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "_" and node.args
                and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str)):
            yield node.args[0].value, False


def py_in_shell(text):
    """Python heredocs inside shell scripts: every here-document whose body parses as Python."""
    for m in re.finditer(r"<<-?\s*(['\"]?)([A-Za-z_]+)\1[^\n]*\n(.*?)\n\2\n", text, re.S):
        if "_(" in m.group(3):
            yield from py_calls(m.group(3))


# ---- the messages and the catalogs -------------------------------------------------------------------------
def messages():
    found = {}       # message -> set of files
    for f in tracked():
        try:
            text = open(f, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        k = kind(f, text)
        if k is None:
            continue
        if k == "py":
            items = list(py_calls(text))
        elif k == "fish":
            items = list(first_arg_calls(text, ["__vl_t"]))
        else:
            text_ = text.replace("'\"'\"'", "'").replace("'\\''", "'")
            names = ["t", "tr_"]
            items = list(first_arg_calls(text_, names))
            if f.startswith("common/void-update/"):
                items += first_arg_calls(text_, ["step", "ok", "info", "warn", "err"])
                items += first_arg_calls(text_, ["ask"], skip=1)
                items += usage_calls(text_)
            if f == "install/install.sh":
                items += install_stages(text)
            items += py_in_shell(text)
        for value, dynamic in items:
            if value and not dynamic:
                found.setdefault(value, set()).add(f)
    return found


def po_unescape(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def catalogs():
    import glob
    return sorted(glob.glob("locale/*/messages.po"))


def entries(po):
    """[(comment_lines, msgid_raw, rest_lines)] in order; the header (msgid "") is entry 0."""
    blocks = open(po, encoding="utf-8").read().rstrip("\n").split("\n\n")
    out = []
    for b in blocks:
        lines = b.split("\n")
        i = next((n for n, l in enumerate(lines) if l.startswith("msgid ")), None)
        if i is None:       # a loose comment (an old section header): dropped by refs
            continue
        out.append((lines[:i], lines[i][7:-1], lines[i + 1:]))
    return out


def same(msg):
    """The key a message is compared with: shell writes \\n literally in a format, Python a real newline."""
    return msg.replace("\\n", "\n").replace("\\t", "\t")


def check():
    found = messages()
    keys = {same(m) for m in found}
    bad = 0
    for po in catalogs():
        ids = {same(po_unescape(raw)) for _, raw, _ in entries(po)[1:]}
        for m in sorted(found):
            if same(m) not in ids:
                print("!! %s: no translation: %s  (%s)" % (po, m[:100], ", ".join(sorted(found[m]))))
                bad += 1
        for i in sorted(ids - keys):
            print("!! %s: unused entry: %s" % (po, i[:100]))
            bad += 1
    return 1 if bad else 0


def refs():
    found = messages()
    where = {same(m): fs for m, fs in found.items()}
    for po in catalogs():
        ents = entries(po)
        out = ["\n".join(ents[0][0] + ['msgid "%s"' % ents[0][1]] + ents[0][2])]
        for comments, raw, rest in ents[1:]:
            fs = where.get(same(po_unescape(raw)))
            keep = [c for c in comments if not c.startswith("#:")]
            head = keep + (["#: " + " ".join(sorted(fs))] if fs else [])
            out.append("\n".join(head + ['msgid "%s"' % raw] + rest))
        open(po, "w", encoding="utf-8").write("\n\n".join(out) + "\n")
        print("refs rewritten:", po)
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "list":
        for m, fs in sorted(messages().items()):
            print("%s\t%s" % (po_escape(m), " ".join(sorted(fs))))
        sys.exit(0)
    sys.exit({"check": check, "refs": refs}.get(cmd, lambda: (print(__doc__), 2)[1])())
