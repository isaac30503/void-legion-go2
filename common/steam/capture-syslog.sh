#!/bin/sh
# capture-syslog.sh — temporary DIAGNOSIS: listens on /dev/log (there is no system log here,
# so whatever is sent to syslog ends up on the text console) and records each message with the time and
# WHO sent it: the process, its parent and its grandparent (e.g. for "unix_chkpwd: password check failed",
# the parent is the program that checked the password). It runs as a temporary runit service
# (/etc/sv/capture-syslog): launched from the session, elogind killed it when restarting lightdm.
# Previous (Spanish) name: capturar-avisos.sh (service capturar-avisos, log /var/log/capturar-avisos.log).
#   sudo sh common/steam/capture-syslog.sh          starts (log, in English: /var/log/capture-syslog.log)
#   sudo sh common/steam/capture-syslog.sh --stop   stops and removes /dev/log
# Void recipe, step 14 (diagnosis of the unix_chkpwd message when switching mode).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
LOG=/var/log/capture-syslog.log
SV=/etc/sv/capture-syslog
case "${1:-}" in --stop)
    sv down capture-syslog >/dev/null 2>&1
    rm -f /var/service/capture-syslog; rm -rf "$SV" /run/capture-syslog.py
    [ -S /dev/log ] && rm -f /dev/log
    t "== stopped. Log:"; cat "$LOG"; exit 0 ;;
esac
[ -e /var/service/capture-syslog ] && { t "!! it is already running"; exit 1; }
cat > /run/capture-syslog.py <<'EOF'
import socket, struct, time, os
s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
s.bind("/dev/log"); os.chmod("/dev/log", 0o666)
s.setsockopt(socket.SOL_SOCKET, socket.SO_PASSCRED, 1)
def who(pid):
    try:
        st = dict(l.split(":\t", 1) for l in open(f"/proc/{pid}/status").read().splitlines() if ":\t" in l)
        cmd = open(f"/proc/{pid}/cmdline", "rb").read().replace(b"\0", b" ").decode(errors="replace").strip()
        return int(st["PPid"]), f"{pid} uid={st['Uid'].split()[0]} {cmd or st['Name']}"
    except Exception:
        return 0, f"{pid} (already ended)"
log = open("/var/log/capture-syslog.log", "a", buffering=1)
log.write(time.strftime("%F %T") + " == listening on /dev/log\n")
while True:
    msg, anc, _f, _a = s.recvmsg(8192, socket.CMSG_SPACE(12))
    pid = 0
    for lvl, typ, data in anc:
        if typ == socket.SCM_CREDENTIALS:
            pid = struct.unpack("iII", data[:12])[0]
    line = [time.strftime("%F %T") + " " + msg.decode(errors="replace").strip()]
    for _i in range(3):
        if pid <= 1: break
        pid, desc = who(pid); line.append("    <- " + desc)
    log.write("\n".join(line) + "\n")
EOF
mkdir -p "$SV"
printf '#!/bin/sh\nrm -f /dev/log\nexec python3 /run/capture-syslog.py 2>&1\n' > "$SV/run"
chmod 755 "$SV/run"
ln -s "$SV" /var/service/
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S /dev/log ] && break; sleep 1; done   # runsvdir sees it in ~5 s
logger -t capture-syslog "test" 2>/dev/null
sleep 1; cat "$LOG"
t "== Listening. Switch mode (there and back) and then: sudo sh %s --stop" "$0"
