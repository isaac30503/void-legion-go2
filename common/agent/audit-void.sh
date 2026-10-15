#!/bin/bash
# audit-void.sh — READ-ONLY audit of one of the network's Void installations (IdeaPad or Legion),
# without root. It is used by the maintenance agent (void-maintainer, in the private repository's claude/agents/); it also works by hand.
# It changes nothing: it reports. What it finds is diagnosed, proposed and, if the user approves it,
# fixed with a script that the user runs (root) and documented in docs/.
#
# Usage, on the machine itself (with the repository's clone there, or with an index):
#   bash audit-void.sh [--repo <repo>] [--index FILE] [--sample SECONDS]
# On another machine over SSH (the clone is not there): generate the index here and pass it:
#   bash audit-void.sh --make-index <repo> > /tmp/repo-index.txt
#   scp /tmp/repo-index.txt lego:/tmp/ && ssh lego bash -s -- --index /tmp/repo-index.txt < audit-void.sh
# (The old Spanish options also work: --comun, --indice, --muestra, --hacer-indice.)
#
# Sections: 1 runit services (down, relaunching in a loop, also started by D-Bus),
# 2 packages (orphans, held, from local repositories, updates, kernels, .new-*,
# capabilities, missing libraries in /usr/local), 3 fidelity with the repository (the system's and the user's
# own files: exact copy, mentioned by a script, or NO TRACE), 4 consumption (CPU and
# memory per process during the sample, and processes created: a relaunch loop shows there).
# Written on 2026-10-07 after finding on the Legion the rtkit loop (runit relaunched it every
# second because D-Bus had already started another one).
#
# Its texts follow the system's language (lib/i18n.sh and lib/void_legion_i18n.py: from the clone, or from
# ~/.local/share/void-legion when it runs from stdin over SSH; without them, English).
# Previous (Spanish) name: fish/void/agente/auditar-void.sh. Its section 3 compared with Common
# ("Backups Linux": fish/, herramientas/, claude-agentes/ and the recipes); here it compares with this
# repository (common/, legion/, lib/, install/ and the .md documents) and the private companion's claude/ (cloned
# next to it, <clone>-private). The files with
# @PLACEHOLDERS@ count also with them filled in (local.env of the clone, and @TARGET_HOME@/@TARGET_USER@
# = the home and name of whoever makes the index), which is how the installers write them.
set -u

# Translations: from the clone (if this is a file inside it) or from the installed copy
_R=""
if [ -f "$0" ]; then
    _R=$(dirname "$(readlink -f "$0")"); until [ -f "$_R/lib/i18n.sh" ] || [ "$_R" = / ]; do _R=$(dirname "$_R"); done
    [ -f "$_R/lib/i18n.sh" ] || _R=""
fi
if [ -n "$_R" ]; then I18N_REPO_DIR=$_R; . "$_R/lib/i18n.sh"
elif [ -r "$HOME/.local/share/void-legion/lib/i18n.sh" ]; then . "$HOME/.local/share/void-legion/lib/i18n.sh"
elif [ -r /usr/local/lib/void-legion/i18n.sh ]; then . /usr/local/lib/void-legion/i18n.sh
else t() { _f=$1; shift; printf -- "$_f\n" "$@"; }; fi
export VL_LIB_DIRS="${_R:+$_R/lib:}$HOME/.local/share/void-legion/lib:/usr/local/share/void-legion/lib"
# Prepended to each Python block: _() from void_legion_i18n, or English without it
PY_I18N='import os as _os, sys as _sys
for _d in _os.environ.get("VL_LIB_DIRS", "").split(":"):
    if _d and _os.path.isfile(_os.path.join(_d, "void_legion_i18n.py")):
        _sys.path.insert(0, _d); break
try:
    from void_legion_i18n import _
except ImportError:
    def _(s): return s
'

REPO=""; INDEX=""; SAMPLE=10
while [ $# -gt 0 ]; do
    case "$1" in
        --repo|--comun) REPO="$2"; shift 2 ;;
        --index|--indice) INDEX="$2"; shift 2 ;;
        --sample|--muestra) SAMPLE="$2"; shift 2 ;;
        --make-index|--hacer-indice)
            # Index of the repository: "M <md5> <relative path>" of each file and "R <absolute path>" of each
            # path of the system or of ~ that the scripts and documents mention (for what is generated).
            python3 -I - "$2" <<'PY'
import os, sys, re, hashlib, pwd
base = sys.argv[1]
home = os.path.expanduser("~")
user = pwd.getpwuid(os.getuid()).pw_name
rx = re.compile(r'(?:(?<=[\s"\'`=(:])|^)((?:/etc|/usr|/boot|/var|' + re.escape(home) + r'|~|@TARGET_HOME@)/[\w.@+\-/]+)')
# Values of the @PLACEHOLDERS@ (local.env of the clone; git-ignored) and the target user's ones
vals = {"TARGET_HOME": home, "TARGET_USER": user}
try:
    for l in open(os.path.join(base, "local.env"), encoding="utf-8"):
        m = re.match(r'^\s*([A-Z0-9_]+)=(.*)$', l.rstrip("\n"))
        if m:
            v = m.group(2).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"": v = v[1:-1]
            vals[m.group(1)] = v
except OSError:
    pass
ph = re.compile(rb'@([A-Z][A-Z0-9_]*)@')
def rendered(data):
    return ph.sub(lambda m: vals[m.group(1).decode()].encode() if m.group(1).decode() in vals else m.group(0), data)
def path_of(m):
    return m.replace("~/", home + "/", 1).replace("@TARGET_HOME@", home, 1).rstrip("/.")
# Claude Code's context lives in the private companion repository (claude/), cloned next to this one
private = os.path.join(os.path.dirname(base), os.path.basename(base) + "-private")
for root_, top in [(base, t) for t in ("common", "legion", "lib", "install")] + [(private, "claude")]:
    for d, dn, fn in os.walk(os.path.join(root_, top)):
        if "__pycache__" in d: continue
        for f in fn:
            p = os.path.join(d, f)
            if f.endswith(".bak") or os.path.getsize(p) > 64 << 20: continue
            data = open(p, "rb").read()
            rel = os.path.relpath(p, root_)
            print("M", hashlib.md5(data).hexdigest(), rel)
            if b"\0" in data[:4096]: continue
            r = rendered(data)
            if r != data: print("M", hashlib.md5(r).hexdigest(), rel)
            for m in rx.findall(data.decode("utf-8", "replace")):
                print("R", path_of(m))
for d, dn, fn in os.walk(base):
    dn[:] = [x for x in dn if x not in (".git", "logs", "build", "assets")]
    for f in fn:
        if f.endswith(".md"):
            for m in rx.findall(open(os.path.join(d, f), encoding="utf-8", errors="replace").read()):
                print("R", path_of(m))
PY
            exit 0 ;;
        *) t "unknown option: %s" "$1" >&2; exit 2 ;;
    esac
done
if [ -z "$INDEX" ] && [ -n "$REPO" ]; then
    INDEX=$(mktemp); trap 'rm -f "$INDEX"' EXIT
    bash "$0" --make-index "$REPO" > "$INDEX"
fi

echo "# $(t "Audit of %s — %s — kernel %s, up since %s" "$(cat /etc/hostname)" "$(date '+%F %T')" "$(uname -r)" "$(uptime -s)")"

echo; echo "## $(t "1. runit services")"
# Without root there is no "sv status": the process tree is looked at. runsv <svc> has as children the process
# of the service and, if there is log/, the logger's. Two looks 2 s apart: if the main child
# is missing in both or changes PID, the service is down or relaunching in a loop.
{ printf '%s' "$PY_I18N"; cat <<'PY'
import os, re, glob, time
def procs():
    r = {}
    for p in glob.glob("/proc/[0-9]*"):
        try:
            st = open(p + "/stat").read(); ppid = int(st.rsplit(")", 1)[1].split()[1])
            args = open(p + "/cmdline", "rb").read().replace(b"\0", b" ").decode(errors="replace").strip()
            r[int(p[6:])] = (ppid, args)
        except Exception: pass
    return r
def children(pr, sv):
    rs = [pid for pid, (pp, a) in pr.items() if a == "runsv " + sv]
    if not rs: return None
    return {pid: a for pid, (pp, a) in pr.items() if pp == rs[0] and not a.startswith("svlogd") and not a.startswith("vlogger")}
dbus = {}
for f in glob.glob("/usr/share/dbus-1/system-services/*.service"):
    for l in open(f, errors="replace"):
        if l.startswith("Exec="): dbus[l[5:].split()[0]] = os.path.basename(f)
svs = sorted(os.listdir("/var/service"))
a = procs(); time.sleep(2); b = procs()
warnings = 0
for sv in svs:
    d = os.path.realpath("/var/service/" + sv)
    if os.path.exists(d + "/down"):
        print("   " + _("%s: 'down' on purpose (only with sv once)") % sv); continue
    h1, h2 = children(a, sv), children(b, sv)
    if h1 is None or h2 is None:
        print("!! " + _("%s: there is no 'runsv %s' (link just created or runsvdir down?)") % (sv, sv)); warnings += 1; continue
    if not h2:
        print("!! " + (_("%s: DOWN or RELAUNCHING IN A LOOP (runsv without the service's process in both looks)") % sv if not h1
              else _("%s: its process disappeared between the two looks (loop?)") % sv)); warnings += 1
    elif h1 and set(h1) != set(h2) and not set(h1) & set(h2):
        print("!! " + _("%s: the process changed PID in 2 s (%s → %s): RELAUNCHING") % (sv, sorted(h1), sorted(h2))); warnings += 1
    # Is the service's executable also started by D-Bus? Is there a copy running outside runsv?
    try: run = open(d + "/run", errors="replace").read()
    except Exception: run = ""
    ex = re.findall(r'^\s*exec\s+(?:chpst\s+\S+(?:\s+\S+)?\s+)?(/\S+)', run, re.M)
    for e in ex:
        if e in dbus:
            outside = [pid for pid, (pp, args) in b.items() if args.split(" ")[0] == e and pid not in (h2 or {})]
            msg = "   " + _("%s: %s is also started by D-Bus (%s)") % (sv, e, dbus[e])
            if outside:
                msg = "!! " + _("%s: there is %s running OUTSIDE runsv (PID %s, started by D-Bus) → clash with runit") % (sv, e, outside); warnings += 1
            print(msg)
print("   " + _("(%d services; warnings: %d)") % (len(svs), warnings))
PY
} | python3 -I -

echo; echo "## $(t "2. Packages")"
{ printf '%s' "$PY_I18N"; cat <<'PY'
import plistlib, glob, os, subprocess
db = sorted(glob.glob("/var/db/xbps/pkgdb-*.plist"))[-1]
pk = plistlib.load(open(db, "rb"))
manual = sorted(n for n, v in pk.items() if isinstance(v, dict) and v.get("automatic-install") is not True and "pkgver" in v)
hold = sorted(n for n, v in pk.items() if isinstance(v, dict) and v.get("hold"))
local = sorted(f"{v['pkgver']} ← {v.get('repository')}" for n, v in pk.items()
               if isinstance(v, dict) and "repository" in v and not v["repository"].startswith("http"))
none = _("none")
print("   " + _("installed: %d; by hand: %d") % (sum(1 for v in pk.values() if isinstance(v, dict) and 'pkgver' in v), len(manual)))
print("   " + _("held (hold): %s") % (' '.join(hold) or none))
print("   " + _("from local repositories (built here; void-update warns if Void replaces them):"))
for l in local: print("      " + l)
o = subprocess.run(["xbps-query", "-O"], capture_output=True, text=True).stdout.split()
print("   " + _("orphans: %s  (a backup linuxX.Y is on purpose)") % (' '.join(o) or none))
u = subprocess.run(["xbps-install", "-un"], capture_output=True, text=True)
lines = [l for l in u.stdout.splitlines() if l.strip()]
print("   " + _("pending updates (repodata of the last sync): %d") % len(lines))
for l in (u.stderr.strip().splitlines()[:5]): print("!! xbps: " + l)
kern = sorted(n for n in pk if n.startswith("linux") and n[5:6].isdigit() and "-headers" not in n)
print("   " + _("kernels: %s; in use %s; vmlinuz: %s") % (' '.join(kern), os.uname().release, ' '.join(sorted(os.path.basename(x) for x in glob.glob('/boot/vmlinuz-*')))))
print("   " + _("list of those installed by hand (to cross-check with docs/):"))
print("      " + " ".join(manual))
PY
} | python3 -I -
NEW=$(ls /etc/*.new-* /etc/default/*.new-* 2>/dev/null); echo "   $(t ".new-* in /etc: %s (do not apply them: the good one is the current one)" "${NEW:-$(t "none")}")"
command -v gamescope >/dev/null && echo "   gamescope: $(getcap /usr/bin/gamescope 2>/dev/null || t 'WITHOUT cap_sys_nice')"
for b in /usr/local/bin/* /usr/local/lib/* /usr/lib/steamos-manager /usr/bin/inputplumber "$HOME"/.local/lib/*/*.so; do
    [ -f "$b" ] && file -b "$b" 2>/dev/null | grep -q ELF || continue
    ldd "$b" 2>/dev/null | grep -q 'not found' && echo "!! $(t "%s: libraries missing: %s" "$b" "$(ldd "$b" | grep 'not found' | awk '{print $1}' | tr '\n' ' ')")"
done

echo; echo "## $(t "3. Fidelity with the repository")"
if [ -z "$INDEX" ] || [ ! -s "$INDEX" ]; then
    echo "   $(t "(without the repository's index: --repo DIR or --index FILE)")"
else
{ printf '%s' "$PY_I18N"; cat <<'PY'
import os, sys, glob, plistlib, hashlib
md5c, refs = {}, set()
for l in open(sys.argv[1], encoding="utf-8", errors="replace"):
    t = l.rstrip("\n").split(" ", 2)
    if t[0] == "M" and len(t) == 3: md5c.setdefault(t[1], t[2])
    elif t[0] == "R": refs.add(t[1])
own, sha = set(), {}
for p in glob.glob("/var/db/xbps/.*-files.plist"):
    d = plistlib.load(open(p, "rb"))
    for k in ("files", "conf_files", "links", "dirs"):
        for e in d.get(k, []):
            own.add(e["file"])
            if k == "conf_files" and "sha256" in e: sha[e["file"]] = e["sha256"]
noise = ("/etc/ssh/ssh_host_", "/etc/shadow", "/etc/gshadow", "/etc/passwd-", "/etc/group-", "/etc/subuid-",
         "/etc/subgid-", "/etc/.pwd.lock", "/etc/resolv.conf", "/etc/localtime", "/etc/shells", "/etc/runit/runsvdir/",
         "/etc/NetworkManager/system-connections/", "/etc/lightdm/.session", "/etc/xbps.d/00-repository-main.conf.old",
         "/etc/default/live.conf", "/etc/fonts/conf.d/", "/etc/sv/ntpd", "/usr/local/share/fonts/", "/etc/sudoers.d/wheel",
         "/etc/.updated", "/usr/local/share/applications/mimeinfo.cache", "/etc/ld.so.cache", "/etc/ssl/certs/",
         "/etc/udev/hwdb.bin", "/etc/passwd.OLD", "/etc/group", "/etc/subuid", "/etc/subgid", "/etc/passwd",
         "/etc/locale.conf", "/etc/hostname", "/etc/default/libc-locales")   # of the system or of the installer
roots = ["/etc", "/usr/local", "/usr/share/applications", "/usr/share/wayland-sessions", "/usr/share/xsessions",
         "/usr/share/dbus-1", "/usr/share/xdg-desktop-portal", "/boot/grub/custom.cfg", "/boot/grub/themes"]
NO_TRACE = _("NO TRACE in the repository")
def classify(p):
    try: h = hashlib.md5(open(p, "rb").read()).hexdigest()
    except PermissionError: return _("unreadable without root")
    except Exception: return None
    if h in md5c: return "= " + md5c[h]
    q = p
    while q not in ("/", ""):
        if q in refs: return _("generated (the repository mentions it)") + ("" if q == p else f": {q}")
        q = os.path.dirname(q)
    return NO_TRACE
missing = 0; n = 0
print("   " + _("system (files that belong to no package; and those of packages that were modified):"))
for r in roots:
    it = [r] if os.path.isfile(r) else [os.path.join(d, f) for d, dn, fn in os.walk(r) for f in fn]
    for p in sorted(it):
        if p in own or p.startswith(noise) or p.endswith((".bak", ".pyc")) or "/__pycache__/" in p: continue
        if os.path.islink(p): continue
        c = classify(p); n += 1
        if c == NO_TRACE: missing += 1; print(f"!! {p}: {c}")
for p, s in sorted(sha.items()):
    if not p.startswith("/etc") or not os.path.isfile(p): continue
    try: cur = hashlib.sha256(open(p, "rb").read()).hexdigest()
    except PermissionError: continue
    if cur != s:
        n += 1; c = classify(p)
        if c == NO_TRACE:
            if p in refs:
                c = _("modified; the repository mentions it")
            else:
                c = _("modified, NO TRACE in the repository"); missing += 1; print(f"!! {p}: {c}")
H = os.path.expanduser("~")
usr = [".Xresources", ".xprofile", ".ssh/config", ".bashrc.d", ".config/autostart", ".config/xfce4/labwc",
       ".config/xfce4/helpers.rc", ".config/fish", ".config/fuzzel", ".config/gtk-3.0/gtk.css", ".config/wireplumber",
       ".config/xdg-desktop-portal-wlr", ".config/fastfetch/gen-config.py", ".local/bin", ".local/lib",
       ".local/share/applications/steam.desktop", ".local/share/applications/dev.vencord.Vesktop.desktop",
       ".local/share/dbus-1", ".local/share/icons/xterm-papirus.xpm"]
print("   " + _("user:"))
for u in usr:
    q = os.path.join(H, u)
    it = [q] if os.path.isfile(q) else [os.path.join(d, f) for d, dn, fn in os.walk(q) for f in fn]
    for p in sorted(it):
        if p.endswith((".bak", "fish_variables")) or "/.local/bin/claude" in p or ".antes-" in p: continue
        c = classify(p); n += 1
        if c == NO_TRACE: missing += 1; print(f"!! {p}: {c}")
print("   " + _("(%d files looked at; with no trace: %d. 'Generated' = the agent must confirm which script writes it)") % (n, missing))
PY
} | python3 -I - "$INDEX"
fi

echo; echo "## $(t "4. Consumption (sample of %s s)" "$SAMPLE")"
{ printf '%s' "$PY_I18N"; cat <<'PY'
import glob, time, sys, os
T = float(sys.argv[1]); hz = os.sysconf("SC_CLK_TCK")
def snap():
    r = {}
    for p in glob.glob("/proc/[0-9]*"):
        try:
            st = open(p + "/stat").read(); nm = st[st.index("(") + 1:st.rindex(")")]
            f = st.rsplit(")", 1)[1].split()
            r[int(p[6:])] = (nm, int(f[11]) + int(f[12]), int(f[21]) * os.sysconf("SC_PAGE_SIZE") // 1048576)
        except Exception: pass
    return r
pid0 = int(open("/proc/loadavg").read().split()[4]); a = snap(); time.sleep(T); b = snap()
pid1 = int(open("/proc/loadavg").read().split()[4])
cpu = sorted(((b[p][1] - a[p][1]) / hz / T * 100, b[p][0], p) for p in b if p in a)
cpu.reverse()
# (The original wrote "CPU …: " + list or "everything idle", which never chose the second one: with nothing
# busy it printed the label alone. Here "everything idle" does come out then, as was intended.)
busy = ", ".join(f"{n}[{p}] {c:.1f}" for c, n, p in cpu[:8] if c >= 0.5)
print("   " + _("CPU (%% of one core):  %s") % busy if busy else "   " + _("everything idle"))
mem = sorted(((v[2], v[0], p) for p, v in b.items()), reverse=True)
print("   " + _("memory (MiB):  %s") % ", ".join(f"{n} {m}" for m, n, p in mem[:8]))
new = pid1 - pid0
print("   " + _("processes created in %.0f s: %d") % (T, new) + ("  ← " + _("~1 per second or more: check whether something relaunches in a loop (idle, the IdeaPad creates ~1 every 5 s)") if new >= T * 0.8 else ""))
for l in open("/proc/meminfo"):
    if l.startswith(("MemAvailable", "SwapFree", "SwapTotal")): print("   " + " ".join(l.split()))
PY
} | python3 -I - "$SAMPLE"
echo; echo "# $(t "end")"
