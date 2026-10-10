#!/bin/bash
# diag-inputplumber-cpu.sh — Legion Go 2 (Void). What spends CPU in InputPlumber, by origin.
# Previous name: diag-inputplumber-cpu.sh (unchanged; its labels were modojuego/escritorio/modojuego-mando
# and its result /tmp/medir-inputplumber-<label>.txt: the results of 2026-10-08 are archived with those
# names in logs/legion/install/).
#
# WHY (2026-10-08): idle in Game Mode, InputPlumber 0.81 spends ~3 % of one core and
# ~7000 wakeups/s (11 % average since boot). It reads 8 sources: the controller's hidraw, 4 evdev
# and two iio IMUs (gyro_3d and accel_3d, at 200 Hz, with the iio buffer off: it seems to read them by
# polling sysfs). Hypothesis: the polling of the IMUs. This script measures, it changes nothing.
#
# WHAT IT DOES (read-only; root only to read the process's /proc and for strace; ~65 s):
#   1. Window WITHOUT strace (DUR s): CPU of the process (/proc/<pid>/stat), CPU and context switches
#      per thread (/proc/<pid>/task/*), read/write calls (/proc/<pid>/io: syscr/syscw).
#      It is the reliable figure: strace adds load while it measures.
#   2. strace -f -c (DUR s): summary of system calls (how many and which).
#   3. strace -f with reads/waits (DUR s): counts per descriptor and translates it to its path
#      (/proc/<pid>/fd): times per second it reads each /sys/bus/iio/..., /dev/hidraw*,
#      /dev/input/event*; and the distribution of the wait timeouts (nanosleep/epoll) that
#      gives away a fixed-interval polling.
#   It does not restart InputPlumber or touch its profile. While strace is attached (steps 2 and 3) the
#   input may be somewhat slower; when it is released (SIGINT) it goes back to normal.
#
# USAGE (on the Legion, as root; from the IdeaPad: ssh -t lego sudo bash /tmp/diag-inputplumber-cpu.sh <label>):
#   sudo bash legion/diag-inputplumber-cpu.sh game-mode              # Game Mode idle, WITHOUT touching the controller
#   sudo bash legion/diag-inputplumber-cpu.sh desktop                # Xfce Wayland with Steam in the background + extest
#   sudo bash legion/diag-inputplumber-cpu.sh game-mode-controller   # optional: moving the controller all the time
#   DUR=30 sudo -E ...   changes the duration of each pass (20 s by default).
# Needs strace (sudo xbps-install -S strace; it can be removed afterwards). Without strace it does only step 1.
#
# HOW TO READ /tmp/measure-inputplumber-<label>.txt (644, no secrets):
#   - "CPU without strace": % of one core; "per thread": which thread spends and how many context switches/s.
#   - "syscr/s": reads per second; if it is around 200 × IMU channels, it is the iio polling.
#   - "Per descriptor": the path that is read the most rules. If they are files in_anglvel_*/in_accel_*_raw
#     of /sys/bus/iio/devices/iio:device1|2 → polling of the IMUs. If it is /dev/hidraw* → the controller
#     sends reports nonstop (normal when moving it; idle, it should not). epoll_wait without a data fd
#     and nanosleep with the same timeout (e.g. 5 ms = 200 Hz) → fixed-interval loop.
# The report is written in English (it is a data file); the progress on the terminal follows the language.
set -u
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
LABEL=${1:-no-label}
LABEL=$(printf '%s' "$LABEL" | tr -c 'A-Za-z0-9_.-' '_')
DUR=${DUR:-20}
OUT=/tmp/measure-inputplumber-$LABEL.txt
TMP=$(mktemp -d /tmp/measure-ip.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

if [ "$(id -u)" -ne 0 ]; then t "It has to be run with sudo." >&2; exit 1; fi
PID=$(pgrep -xo inputplumber) || { t "InputPlumber is not running." >&2; exit 1; }
HZ=$(getconf CLK_TCK)

: > "$OUT"; chmod 644 "$OUT"
log() { printf '%s\n' "$*" >> "$OUT"; }
cpu_proc() { awk '{print $14+$15}' "/proc/$PID/stat"; }
threads() { # tid name ticks vol nvol
	for tk in /proc/$PID/task/*; do
		tid=${tk##*/}
		name=$(cat "$tk/comm" 2>/dev/null) || continue
		tic=$(awk '{print $14+$15}' "$tk/stat" 2>/dev/null)
		vol=$(awk '/^voluntary_ctxt/{print $2}' "$tk/status" 2>/dev/null)
		nvo=$(awk '/^nonvoluntary_ctxt/{print $2}' "$tk/status" 2>/dev/null)
		printf '%s %s %s %s %s\n' "$tid" "$name" "$tic" "$vol" "$nvo"
	done
}
fds() { for f in /proc/$PID/fd/*; do printf '%s -> %s\n' "${f##*/}" "$(readlink "$f")"; done; }
io_val() { awk -v k="$1:" '$1==k{print $2}' "/proc/$PID/io"; }

t ">> Measuring InputPlumber (PID %s), label '%s', 3 passes of %s s." "$PID" "$LABEL" "$DUR"
t ">> Do not touch the controller (unless the label is the 'moving the controller' one)."

log "== diag-inputplumber-cpu: $LABEL — $(date '+%F %T') — PID $PID — DUR $DUR s"
log "inputplumber: $(/usr/bin/inputplumber --version 2>/dev/null | head -1)"
log "kernel $(uname -r); booted $(awk '{printf "%d", $1}' /proc/uptime) s ago"
log "Session: gamescope-wl=$(pgrep -xc gamescope-wl) labwc=$(pgrep -xc labwc) steam=$(pgrep -xc steam) extest=$(pgrep -fc 'extest' ) xfce4-session=$(pgrep -xc xfce4-session)"
log "Average CPU since the process started: $(awk -v hz="$HZ" -v up="$(cut -d' ' -f1 /proc/uptime)" '{printf "%.1f %%", 100*($14+$15)/hz/(up-$22/hz)}' "/proc/$PID/stat")"
log ""
log "-- IIO"
for d in /sys/bus/iio/devices/iio:device*; do
	log "$(basename "$d") $(cat "$d/name" 2>/dev/null): buffer=$(cat "$d/buffer/enable" 2>/dev/null) $(for f in "$d"/*sampling_frequency; do [ -e "$f" ] && printf '%s=%s ' "$(basename "$f")" "$(cat "$f")"; done)"
done
log ""
log "-- Open descriptors (fd -> path)"
fds > "$TMP/fd"
cat "$TMP/fd" >> "$OUT"
log ""

# ---------- 1. Without strace ----------
t ">> 1/3: without strace (%s s)…" "$DUR"
threads > "$TMP/h0"; c0=$(cpu_proc); r0=$(io_val syscr); w0=$(io_val syscw); t0=$(date +%s.%N)
sleep "$DUR"
threads > "$TMP/h1"; c1=$(cpu_proc); r1=$(io_val syscr); w1=$(io_val syscw); t1=$(date +%s.%N)
DT=$(awk -v a="$t0" -v b="$t1" 'BEGIN{print b-a}')
log "== 1. WITHOUT strace ($(printf '%.1f' "$DT") s)"
log "CPU without strace: $(awk -v c="$((c1-c0))" -v hz="$HZ" -v dt="$DT" 'BEGIN{printf "%.2f %% of one core", 100*c/hz/dt}')"
log "syscr/s (reads): $(awk -v n="$((r1-r0))" -v dt="$DT" 'BEGIN{printf "%.0f", n/dt}')   syscw/s (writes): $(awk -v n="$((w1-w0))" -v dt="$DT" 'BEGIN{printf "%.0f", n/dt}')"
log "Per thread (tid name: %CPU, voluntary context switches/s, involuntary/s):"
awk -v hz="$HZ" -v dt="$DT" 'NR==FNR{t[$1]=$3; v[$1]=$4; n[$1]=$5; next}
	($1 in t){printf "  %s %s: %.2f %%, %.0f vol/s, %.0f invol/s\n", $1, $2, 100*($3-t[$1])/hz/dt, ($4-v[$1])/dt, ($5-n[$1])/dt; sv+=($4-v[$1]); sn+=($5-n[$1])}
	END{printf "  TOTAL wakeups: %.0f/s\n", (sv+sn)/dt}' "$TMP/h0" "$TMP/h1" >> "$OUT"
log ""

if ! command -v strace >/dev/null; then
	log "strace is not installed: only pass 1. Install: sudo xbps-install -S strace"
	t ">> strace is not there: only pass 1 done. Result in %s" "$OUT"
	exit 0
fi

# ---------- 2. strace -c ----------
t ">> 2/3: strace -c (%s s; the input may be somewhat slower)…" "$DUR"
c0=$(cpu_proc); t0=$(date +%s.%N)
timeout -s INT "$DUR" strace -f -c -p "$PID" -o "$TMP/summary" 2>/dev/null
c1=$(cpu_proc); t1=$(date +%s.%N)
DT=$(awk -v a="$t0" -v b="$t1" 'BEGIN{print b-a}')
log "== 2. strace -f -c ($(printf '%.1f' "$DT") s; CPU of the process WITH strace: $(awk -v c="$((c1-c0))" -v hz="$HZ" -v dt="$DT" 'BEGIN{printf "%.2f %%", 100*c/hz/dt}'))"
cat "$TMP/summary" >> "$OUT"
log ""

# ---------- 3. strace per descriptor ----------
t ">> 3/3: strace per descriptor (%s s)…" "$DUR"
t0=$(date +%s.%N)
timeout -s INT "$DUR" strace -f -s 80 -p "$PID" -o "$TMP/trace" \
	-e trace=read,pread64,readv,write,lseek,openat,close,ioctl,epoll_wait,epoll_pwait,epoll_pwait2,poll,ppoll,clock_nanosleep,nanosleep,timerfd_settime,futex 2>/dev/null
t1=$(date +%s.%N)
DT=$(awk -v a="$t0" -v b="$t1" 'BEGIN{print b-a}')
fds >> "$TMP/fd"   # fds open during the trace
log "== 3. strace per descriptor ($(printf '%.1f' "$DT") s; $(wc -l < "$TMP/trace") lines)"
awk -v dt="$DT" '
	FNR==NR { split($0, p, " -> "); path[p[1]]=p[2]; next }
	{
		sub(/^\[pid +[0-9]+\] */, ""); sub(/^[0-9]+ +/, "")
		if ($0 ~ /^\+\+\+/ || $0 ~ /^---/) next
		if (match($0, /^<\.\.\. [a-z_0-9]+ resumed>/)) {   # end of a split call: only epoll timeouts
			name = substr($0, 6, RLENGTH-14); rest = substr($0, RLENGTH+1)
			if (name ~ /^epoll_p?wait2?$|^p?poll$/ && match(rest, /, *-?[0-9]+\) += /)) { to = substr(rest, RSTART, RLENGTH); gsub(/[^-0-9]/, "", to); wait[name " timeout " to " ms"]++ }
			next
		}
		if (!match($0, /^[a-z_0-9]+\(/)) next
		name = substr($0, 1, RLENGTH-1); rest = substr($0, RLENGTH+1)
		calls[name]++
		if (name ~ /^(read|pread64|readv|write|lseek|ioctl|close)$/) {
			split(rest, a, /[,)]/); fd=a[1]
			r = (fd in path) ? path[fd] : "fd " fd " (closed)"
			perfd[name " " r]++
		} else if (name == "openat") {
			if (match(rest, /"[^"]*"/)) perfd["openat " substr(rest, RSTART+1, RLENGTH-2)]++
		} else if (name ~ /nanosleep$/) {
			if (match(rest, /tv_nsec=[0-9]+/)) { ns = substr(rest, RSTART+8, RLENGTH-8); wait[name " " int(ns/100000)/10 " ms"]++ }
		} else if (name ~ /^epoll_p?wait2?$|^p?poll$/) {
			if (match(rest, /, *-?[0-9]+\) += /)) { to = substr(rest, RSTART, RLENGTH); gsub(/[^-0-9]/, "", to); wait[name " timeout " to " ms"]++ }
		}
	}
	END {
		print "Calls/s:"; for (k in calls) printf "  %8.1f  %s\n", calls[k]/dt, k | "sort -rn"; close("sort -rn")
		print "Per descriptor (times/s, call, path):"; for (k in perfd) printf "  %8.1f  %s\n", perfd[k]/dt, k | "sort -rn | head -40"; close("sort -rn | head -40")
		print "Waits (times/s, call and timeout):"; for (k in wait) printf "  %8.1f  %s\n", wait[k]/dt, k | "sort -rn | head -20"; close("sort -rn | head -20")
	}' "$TMP/fd" "$TMP/trace" >> "$OUT"

t ">> Done. Result: %s" "$OUT"
