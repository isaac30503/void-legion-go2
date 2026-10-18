#!/bin/bash
# Diagnosis: where gamescope breaks when changing a setting of a stream through its PipeWire node
# (2026-10-07; docs/7-apps/1-screen-sharing.md). Seen on
# 2026-10-07 00:07:56: Vesktop streaming the screen through gamescope's portal; when changing a
# setting of the stream, gamescope "pipewire: warning: out of buffers" and "Segmentation fault" → the
# launcher switches to Xfce. Valve's 2026 PipeWire fixes (e3ed1ea7, 4d143bfd) are already in
# 3.16.30.
# No core dump is possible: gamescope has cap_sys_nice and with fs.suid_dumpable=0 the kernel does not
# dump it; that is why gdb is attached to it (as root: ptrace of a program with capabilities).
# Usage, already inside Game Mode (from the IdeaPad: ssh -t lego sudo bash /tmp/diag-gamescope-pipewire.sh):
#   sudo bash legion/diag/diag-gamescope-pipewire.sh
# Requirements (root, once; Void's "debug" repository only for the symbols):
#   sudo xbps-install -S gdb
#   sudo xbps-install -S --repository=https://repo-default.voidlinux.org/current/debug gamescope-dbg
# It leaves gdb waiting in the background; when gamescope crashes it writes the trace to
# /var/tmp/gamescope-pipewire-trace.txt (readable by the user). The screen freezes for an instant
# when attaching. If it does not reproduce, when leaving Game Mode gdb ends by itself.
# Previous name: diag-gamescope-pipewire.sh (unchanged; the trace was /var/tmp/gamescope-pipewire-traza.txt:
# the one of 2026-10-07 is archived in the private repository, archive/2026-10-14/logs/legion/).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
command -v gdb >/dev/null || { t "gdb is missing: sudo xbps-install -S gdb"; exit 1; }
xbps-query gamescope-dbg >/dev/null 2>&1 || t "!! without gamescope-dbg: the trace will come out without function names or lines"
P=$(pgrep -x gamescope-wl) || { t "gamescope is not running: enter Game Mode first"; exit 1; }
OUT=/var/tmp/gamescope-pipewire-trace.txt
{
    echo "== $(date '+%F %T') gdb attached to gamescope-wl (pid $P), $(gamescope --version 2>&1 | tail -1)"
    xbps-query -p pkgver gamescope gamescope-dbg pipewire 2>/dev/null
} > "$OUT"
chmod 644 "$OUT"
setsid nohup gdb -p "$P" -batch \
    -ex "set pagination off" -ex "set print pretty on" \
    -ex "handle SIGPIPE nostop noprint pass" -ex "handle SIGUSR1 nostop noprint pass" \
    -ex "handle SIGUSR2 nostop noprint pass" -ex "handle SIGCHLD nostop noprint pass" \
    -ex "handle SIGTERM nostop print pass" -ex "handle SIGINT nostop print pass" \
    -ex "continue" \
    -ex "echo \n== thread that failed\n" -ex "bt full" \
    -ex "echo \n== all threads\n" -ex "thread apply all bt" \
    -ex "echo \n== registers\n" -ex "info registers" \
    >> "$OUT" 2>&1 < /dev/null &
sleep 2
if pgrep -f "gdb -p $P" >/dev/null; then
    t "gdb waiting (pid %s). Now: stream in Vesktop and change a setting." "$(pgrep -f "gdb -p $P" | head -1)"
    t "Trace: %s" "$OUT"
else
    t "gdb did not stay attached:"; tail -20 "$OUT"
fi
