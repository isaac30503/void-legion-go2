#!/bin/bash
# verify.sh — checks of the clone (without root; changes nothing):
#   bash install/verify.sh              all: syntax, catalogs, recipe paths, binaries, private values
#   bash install/verify.sh --secrets    only the private values (before every commit; docs/sanitization.md)
# Exit 1 if something fails.
set -uo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
cd "$REPO_ROOT"
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

if [ "${1:-}" = --secrets ]; then secrets; exit $bad; fi

t "== syntax"
while IFS= read -r f; do
    case "$f" in
        *.fish) fish -n "$f" 2>/dev/null || fail "$f" ;;
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

t "== paths cited by the recipe"
python3 -I - <<'PY' || bad=1
import re, os, sys
s = open("docs/void-legion-go2.md", encoding="utf-8").read()
miss = []
for p in set(re.findall(r'"\$B/([^"{*<…]+)"', s)):
    p = p.rstrip("/")
    if not os.path.exists(p) and not any(l.split("\t")[2].rstrip("/").startswith(p) for l in open("install/assets.tsv") if l.count("\t") == 2 and not l.startswith("#")):
        miss.append(p)
for m in sorted(miss): print("!! missing:", m)
sys.exit(1 if miss else 0)
PY
[ $bad = 0 ] && ok "docs/void-legion-go2.md"

t "== binaries of the Release"
bash install/fetch-assets.sh --check >/dev/null 2>&1 && ok "all present (install/fetch-assets.sh --check)" \
    || t "   note: some binaries are not here yet (bash install/fetch-assets.sh)"

secrets
exit $bad
