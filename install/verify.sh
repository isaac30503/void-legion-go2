#!/bin/bash
# shellcheck disable=SC2015  # "check && ok … || fail …": ok and fail only print, so fail runs only when the check fails
# verify.sh — checks of the clone (without root; changes nothing):
#   bash install/verify.sh              all: syntax, ShellCheck, catalogs, the inventory, links, paths cited by docs/, binaries,
#                                       private values
#   bash install/verify.sh --secrets    only the private values and the encrypted copy of local.env (before every
#                                       commit; docs/sanitization.md)
#   bash install/verify.sh --ci         what can be checked without local.env and the Release binaries (GitHub
#                                       Actions, .github/workflows/ci.yml): the checks of "all" except binaries and
#                                       secrets, plus a generic search for MACs and UUIDs; ShellCheck is required
# Exit 1 if something fails.
set -uo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
cd "$REPO_ROOT" || exit 1
bad=0
ok()   { t "   ok    %s" "$1"; }
fail() { t "!! FAIL  %s" "$1"; bad=1; }

secrets() {
    t "== private values (local.env) in the clone"
    [ -r local.env ] || { fail "local.env is missing: nothing to look for"; return; }
    python3 -I - "$REPO_ROOT" <<'PY' || bad=1
import os, re, sys, tarfile, io
root = sys.argv[1]
settings = {"KEYBOARD_LAYOUT", "KEYBOARD_VARIANT", "CONSOLE_KEYMAP", "WIFI_INTERFACE", "TARGET_USER"}
pats = []
for l in open(os.path.join(root, "local.env"), encoding="utf-8"):
    m = re.match(r"^\s*([A-Z0-9_]+)=(.*)$", l.strip())
    if not m or m.group(1) in settings: continue
    v = m.group(2).strip().strip("'\"")
    if len(v) < 4: continue
    if re.fullmatch(r"([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", v):
        o = v.split(":")
        for s in (":", "_", "-", ""): pats.append((m.group(1), s.join(o).lower().encode()))
    else:
        pats.append((m.group(1), v.lower().encode()))
        if re.fullmatch(r"[0-9a-fA-F]{8}-.*", v): pats.append((m.group(1), v[:8].lower().encode()))
def blobs(path):
    data = open(path, "rb").read()
    yield path, data
    try:
        if path.endswith((".tar.gz", ".tgz")):
            with tarfile.open(path) as t:
                for m in t.getmembers():
                    if m.isfile(): yield path + ":" + m.name, t.extractfile(m).read()
        elif path.endswith((".xbps", ".tar.zst")):
            from compression import zstd
            with tarfile.open(fileobj=io.BytesIO(zstd.decompress(data))) as t:
                for m in t.getmembers():
                    if m.isfile(): yield path + ":" + m.name, t.extractfile(m).read()
    except Exception as e:
        print(f"   (could not open {path}: {e})")
hits = 0
for d, dn, fn in os.walk(root):
    dn[:] = [x for x in dn if x not in (".git", "build")]
    for f in fn:
        p = os.path.join(d, f)
        if os.path.relpath(p, root) == "local.env": continue
        for name, data in blobs(p):
            low = data.lower()
            for key, pat in pats:
                if pat in low:
                    print(f"!! {os.path.relpath(name, root)}: value of {key}"); hits += 1
# the git history too (what was already committed)
import subprocess
if os.path.isdir(os.path.join(root, ".git")):
    log = subprocess.run(["git", "-C", root, "log", "-p", "--all"], capture_output=True).stdout.lower()
    for key, pat in pats:
        if pat in log: print(f"!! git history: value of {key}"); hits += 1
print("   no private values found" if hits == 0 else f"!! {hits} hit(s)")
sys.exit(1 if hits else 0)
PY
}

# The encrypted copy (local.env.age) has to say the same as local.env
sealed() {
    t "== encrypted copy of local.env (local.env.age)"
    bash install/secrets.sh status || bad=1
}

# Without local.env (CI): the real values are unknown, so look for anything shaped like a MAC or a UUID in the
# tracked files; allowed: the made-up ones (02:00:00:…, 0000…) and the public WMI GUIDs of the kernel sources
leaks() {
    t "== MACs and UUIDs in the tracked files"
    git ls-files -z | xargs -0 grep -IHnoE '\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b|\b[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\b' \
        | grep -vE ':(02:00:00:[0-9:]+|0{8}-0{4}-0{4}-0{4}-0{11}[0-9])$' | grep -v '^legion/tdp/lenovo-wmi-tdp/' > "${TMPDIR:-/tmp}/verify-leaks.$$"
    if [ -s "${TMPDIR:-/tmp}/verify-leaks.$$" ]; then sed 's/^/!! /' "${TMPDIR:-/tmp}/verify-leaks.$$"; fail "MACs or UUIDs (use @NAME@: docs/sanitization.md)"
    else ok "none"; fi
    rm -f "${TMPDIR:-/tmp}/verify-leaks.$$"
}

ci=''
case "${1:-}" in
    --secrets) secrets; sealed; exit $bad ;;
    --ci) ci=1 ;;
esac

t "== syntax"
while IFS= read -r f; do
    case "$f" in
        *.fish) if command -v fish >/dev/null; then fish -n "$f" 2>/dev/null || fail "$f"; else nofish=1; fi ;;
        *.py)   python3 -m py_compile "$f" 2>/dev/null || fail "$f" ;;
        *.xml)  command -v xmllint >/dev/null && { xmllint --noout "$f" 2>/dev/null || fail "$f"; } ;;
        *)      case "$(head -c 64 "$f" | tr -d '\0')" in
                    '#!/bin/bash'*|'#!/usr/bin/env bash'*) bash -n "$f" 2>/dev/null || fail "$f" ;;
                    '#!/bin/sh'*) sh -n "$f" 2>/dev/null || fail "$f" ;;
                    '#!/usr/bin/env python3'*) python3 -m py_compile "$f" 2>/dev/null || fail "$f" ;;
                esac ;;
    esac
done < <(git ls-files --cached --others --exclude-standard 2>/dev/null | grep . || find common legion lib install -type f)
find . -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null
ok "scripts"
# Without fish the .fish files cannot be checked: a note (the CI installs it, and there it is a failure)
if [ -n "${nofish:-}" ]; then
    if [ -n "$ci" ]; then fail "fish is not installed"; else t "   note: fish is not installed: the .fish files were not checked"; fi
fi
# Static analysis with ShellCheck, if installed: no errors or warnings in any shell script (notes are allowed; 2026-10-14)
if command -v shellcheck >/dev/null; then
    sh_files=()
    while IFS= read -r f; do
        case "$f" in *.sh) sh_files+=("$f") ;;
            *) [ -f "$f" ] && head -c 40 "$f" | grep -qE '^#!(/bin/(ba)?sh|/usr/bin/env (ba)?sh)' && sh_files+=("$f") ;; esac
    done < <(git ls-files --cached --others --exclude-standard 2>/dev/null)
    # Besides errors and warnings, two notes that catch real bugs: SC2086 (an unquoted variable split or globbed) and
    # SC2015 ("a && b || c" runs c when b fails). Splitting on purpose carries its "disable" with the reason.
    if out=$( { shellcheck -S warning "${sh_files[@]}"; shellcheck -S info -i SC2086,SC2015 "${sh_files[@]}"; } 2>&1 ); then ok "shellcheck (${#sh_files[@]})"
    else printf '%s\n' "$out" | grep -E '^In |SC[0-9]+' | head -20; fail "shellcheck"; fi
elif [ -n "$ci" ]; then
    fail "shellcheck is not installed"
else
    t "   note: shellcheck is not installed (sudo xbps-install -S shellcheck)"
fi

t "== catalogs"
for po in locale/*/messages.po; do
    if command -v msgfmt >/dev/null; then msgfmt -c -o /dev/null "$po" 2>/dev/null && ok "$po" || fail "$po"
    else python3 -I - "$po" <<'PY' && ok "$po" || fail "$po"
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
ids = re.findall(r'^msgid "(.*)"$', s, re.M); strs = re.findall(r'^msgstr "(.*)"$', s, re.M)
assert len(ids) == len(strs), "msgid/msgstr count"
for i, t in zip(ids, strs):
    if t and re.findall(r'%[sdf%.0-9]*[sdf%]', i) != re.findall(r'%[sdf%.0-9]*[sdf%]', t):
        sys.exit(f"format mismatch: {i!r}")
PY
    fi
done
# Every message of the scripts has its entry, and every entry is used (install/catalog.py; after adding or removing
# messages, "python3 install/catalog.py refs" rewrites the "#:" comments)
python3 -I install/catalog.py check && ok "every message translated, no unused entries" || fail "catalog out of step with the scripts"

t "== the inventory (install/pieces.tsv)"
# Everything the repository installs, one piece per line: every tracked file of common/, legion/, lib/ and install/
# belongs to a piece, and each installer is where its piece says (install.sh, reinstall.md or its page). A new piece
# not added there, or one forgotten in the reinstall, fails here (docs/8-maintenance/4-this-repository.md, "The inventory").
if out=$(python3 -I install/pieces.py 2>&1); then ok "$(t "%s pieces; every file has its piece and every installer its place" "$(python3 -I install/pieces.py --list | grep -c .)")"
else printf '%s\n' "$out" | head -20 | sed 's/^/   /'; fail "install/pieces.tsv"; fi

t "== links between the documents"
python3 -I - <<'PY' && ok "all .md links resolve" || fail "broken links"
import re, os, subprocess
def anchors(path):
    out = set()
    for l in open(path, encoding="utf-8"):
        if l.startswith("#"):
            out.add(re.sub(r"[^\w\- ]", "", l.lstrip("#").strip().lower()).replace(" ", "-"))
    return out
bad = 0
for md in subprocess.run(["git", "ls-files", "*.md"], capture_output=True, text=True).stdout.split():
    text = re.sub(r"```.*?```", "", open(md, encoding="utf-8").read(), flags=re.S)
    for target in re.findall(r"\]\(([^)\s]+)\)", text):
        if re.match(r"[a-z]+:", target): continue
        f, _, a = target.partition("#")
        q = os.path.normpath(os.path.join(os.path.dirname(md), f)) if f else md
        if not os.path.exists(q): print("!! %s: %s (missing)" % (md, target)); bad += 1
        elif a and q.endswith(".md") and a not in anchors(q): print("!! %s: %s (no such heading)" % (md, target)); bad += 1
raise SystemExit(1 if bad else 0)
PY

t "== paths cited by docs/"
python3 -I - <<'PY' && ok "docs/" || fail "paths cited by docs/"
import re, os, sys
import glob
s = "".join(open(f, encoding="utf-8").read() for f in sorted(glob.glob("docs/**/*.md", recursive=True)))
miss = []
for p in set(re.findall(r'"\$B/([^"{*<…]+)"', s)):
    p = p.rstrip("/")
    if not os.path.exists(p) and not any(l.split("\t")[2].rstrip("/").startswith(p) for l in open("install/assets.tsv") if l.count("\t") == 2 and not l.startswith("#")):
        miss.append(p)
for m in sorted(miss): print("!! missing:", m)
sys.exit(1 if miss else 0)
PY

if [ -n "$ci" ]; then leaks; exit $bad; fi

t "== binaries of the Release"
bash install/fetch-assets.sh --check >/dev/null 2>&1 && ok "all present (install/fetch-assets.sh --check)" \
    || t "   note: some binaries are not here yet (bash install/fetch-assets.sh)"

secrets
sealed
exit $bad
