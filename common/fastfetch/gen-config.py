# gen-config.py — writes ~/.config/fastfetch/config.jsonc (Omarchy-style greeting; docs/5-desktop/2-look-and-feel.md).
# Edit this file, never config.jsonc (it is regenerated): python3 ~/.config/fastfetch/gen-config.py
# The icons go as \uXXXX escapes. Every line comes from the real system, not copied from Omarchy.
# The labels follow the system's language (locale/<lang>/messages.po; installed with the user's
# translations in ~/.local/share/void-legion): with the Spanish catalog the greeting is the same as before.
# Previous name: gen-config.py (unchanged).
import json, os, sys
for _d in (os.path.expanduser("~/.local/share/void-legion/lib"), "/usr/local/share/void-legion/lib",
           os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "lib")):
    if os.path.isfile(os.path.join(_d, "void_legion_i18n.py")):
        sys.path.insert(0, _d)
        break
try:
    from void_legion_i18n import _
except ImportError:
    def _(s):
        return s
HW, SW, AGE = "bright_cyan", "bright_white", "bright_yellow"
GRAY = "\u001b[32m"
def box(title=None, w=52):
    if title is None: return {"type":"custom","format":GRAY+"└"+"─"*w+"┘"}
    pad=w-len(title); l=pad//2
    return {"type":"custom","format":GRAY+"┌"+"─"*l+title+"─"*(pad-l)+"┐"}
def m(t,key,color,**kw):
    d={"type":t,"key":key,"keyColor":color}; d.update(kw); return d
def sh(s):
    """A translated text inside a double-quoted shell string."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
ONE_DAY, N_DAYS = sh(_("1 day ago")), sh(_("%s days ago"))
mid="│ ├"; end="└ └"
cfg={
 "$schema":"https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
 "logo":{"padding":{"top":2,"left":2,"right":4}},
 "display":{"disableLinewrap":True},
 "modules":["break",
  box("Hardware"),
  m("host","\uf109 "+_("Host"),HW),
  m("cpu",mid+"\uf4bc",HW),
  m("gpu",mid+"\ue266",HW,detectionMethod="pci",format="{name}"),
  m("display",mid+"\U000f1104",HW),
  m("memory",mid+"\uefc5",HW),
  m("swap",mid+"\U000f04e1",HW),
  m("disk",mid+"\U000f02ca",HW,folders="/"),
  m("battery",end+"\U000f0079",HW,format="{capacity}"),
  box(),"break",
  box("Software"),
  m("command","\uf32e "+_("OS"),SW,text='. /etc/os-release && echo "$PRETTY_NAME (rolling)"'),
  m("command",mid+"\U000f048b",SW,text='xbps-query -L | awk \'NR==1 {sub(/^https?:\\/\\//,"",$2); print $2}\''),
  m("command",mid+"\U000f08d6",SW,text='echo "glibc $(ldd --version | awk \'NR==1 {print $NF}\') · $(cat /proc/1/comm)"'),
  m("kernel",mid+"\uf013",SW),
  m("de",mid+"\uf108",SW),
  m("wm",mid+"\uf2d0",SW),
  m("shell",mid+"\uf120",SW),
  m("terminal",mid+"\uf489",SW),
  m("packages",mid+"\U000f03d7",SW,format="xbps: {xbps}"),
  m("terminalfont",mid+"\uf031",SW),
  m("command",end+"\U000f0e0c",SW,text='printf "'+sh(_("Palette"))+' \\033[30m●\\033[31m●\\033[32m●\\033[33m●\\033[34m●\\033[35m●\\033[36m●\\033[37m●\\033[90m●\\033[91m●\\033[92m●\\033[93m●\\033[94m●\\033[95m●\\033[96m●\\033[97m●\\033[0m\\n"'),
  box(),"break",
  box(_("Installed / Powered on / Updated")),
  m("command","\U000f199f "+_("Installed"),AGE,text='n=$(( ($(date +%s) - $(stat -c %W /home)) / 86400 )); [ $n -eq 1 ] && echo "'+ONE_DAY+'" || printf "'+N_DAYS+'\\n" "$n"'),
  m("uptime","\U000f1ad0 "+_("Powered on"),AGE,format="{?1}{1} d, {?}{2} h {3} min"),
  # Date of the last void-update that ended fine (it records it in ~/.local/state/void-update/last-update; before
  # 2026-10-11, update-system in ~/.local/state/update-system.last). If neither exists, that of xbps's pkgdb (it
  # changes with any installation).
  m("command","\ueb29 "+_("Updated"),AGE,text='f="$HOME/.local/state/void-update/last-update"; [ -r "$f" ] || f="$HOME/.local/state/update-system.last"; if [ -r "$f" ]; then t=$(cat "$f"); else t=$(stat -c %Y /var/db/xbps/pkgdb-0.38.plist); fi; n=$(( ($(date +%s) - t) / 86400 )); if [ $n -eq 1 ]; then s="'+ONE_DAY+'"; else s=$(printf "'+N_DAYS+'" "$n"); fi; echo "$s ($(date -d @$t +%d-%m-%Y))"'),
  # Counts against the repodata of the last sync (xbps-install -S needs root)
  m("command","\U000f06b0 "+_("Pending"),AGE,text='n=$(xbps-install -un 2>/dev/null | wc -l); [ $n -eq 0 ] && echo "'+sh(_("nothing (according to the last sync)"))+'" || printf "'+sh(_("%s packages (according to the last sync)"))+'\\n" "$n"'),
  box(),"break"]}
open(os.path.expanduser('~/.config/fastfetch/config.jsonc'),'w').write(json.dumps(cfg,ensure_ascii=False,indent=2)+"\n")
