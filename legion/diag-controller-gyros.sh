#!/bin/sh
# Legion Go 2: do the gyroscopes/accelerometers of EACH CONTROLLER send anything? Read-only (it writes
# nothing to the controller). It listens at the same time to the controller's three hidraw interfaces
# (17ef:61eb…61ee) and keeps saying what to do in each phase (everything still → turn the left
# controller → the right one → the tablet). At the end, per interface and message type, which bytes change
# in each phase and not at rest: those that change only when turning a controller are its IMU.
# If XInput reports arrive with InputPlumber v0.81's format (id 0x04, command 0x74, 60 bytes;
# src/drivers/lego/hid_report.rs: left accel 35–40, gyro 41–46; right accel 48–53, gyro
# 54–59, int16 big endian), it also shows them by name. The first test (2026-10-05) gave 1251
# messages through interface 2 and none with that format: that is why everything is looked at raw.
# Previous (Spanish) name: diag-giroscopio-mandos.sh (its log of 2026-10-05, diag-giroscopio-mandos.log,
# is archived in the private repository, archive/2026-10-14/logs/legion/).
#   sudo sh legion/diag-controller-gyros.sh [seconds per phase]     (8 by default)
# Log: ~/diag-controller-gyros.log. Legion recipe, Pending (2026-10-05).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
SEC=${1:-8}
DEVS=""
for h in /sys/class/hidraw/hidraw*; do
    grep -qiE 'HID_ID=0003:000017EF:000061E[B-E]' "$h/device/uevent" 2>/dev/null || continue
    DEVS="$DEVS /dev/${h##*/}:$(cat "$h/device/../bInterfaceNumber" 2>/dev/null)"
done
[ -n "$DEVS" ] || { t "I cannot find the controller (17ef:61eb…61ee)"; exit 1; }
VL_LIB="$REPO_ROOT/lib" python3 - "$SEC" "$TARGET_HOME/diag-controller-gyros.log" $DEVS <<'EOF'
import os, sys, time, select, struct, collections
sys.path.insert(0, os.environ.get("VL_LIB", ""))
try:
    from void_legion_i18n import _
except ImportError:
    _ = lambda s: s
sec = float(sys.argv[1])
fds = {}
for d in sys.argv[3:]:
    path, intf = d.rsplit(':', 1)
    fds[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = _("%s (interface %s)") % (path.split('/')[-1], intf)
log = open(sys.argv[2], 'w')
def say(t=''):
    print(t, flush=True); log.write(t + '\n'); log.flush()

PHASES = [
    ('rest',  _('leave BOTH controllers detached and still on the table, and the tablet still')),
    ('left',  _('turn the LEFT controller in all directions (the right one and the tablet, still)')),
    ('right', _('turn the RIGHT controller in all directions (the left one and the tablet, still)')),
    ('tablet', _('turn the TABLET (the controllers, still on the table)')),
]
# per phase and per (interface, size, first 3 bytes): minimum and maximum of each byte, and how many
data = {f: {} for f, _x in PHASES}
example = {}
FIELDS = {'left_accel': 35, 'left_gyro': 41, 'right_accel': 48, 'right_gyro': 54}
xinput = {f: {} for f, _x in PHASES}

say(_("Interfaces: %s. %.0f s per phase. Read-only.") % (', '.join(fds.values()), sec))
for i in (3, 2, 1):
    print("\r" + _("Starting in %d…  (detach both controllers)   ") % i, end='', flush=True); time.sleep(1)
print()
for phase, what in PHASES:
    say("\n▶ " + _("NOW: %s") % what)
    end = time.time() + sec
    while (left := end - time.time()) > 0:
        print("\r   " + _("%4.1f s left ") % left, end='', flush=True)
        for fd in select.select(list(fds), [], [], 0.2)[0]:
            try: b = os.read(fd, 256)
            except BlockingIOError: continue
            k = (fds[fd], len(b), b[:3].hex(' '))
            mn, mx, n = data[phase].get(k, (list(b), list(b), 0))
            data[phase][k] = ([min(x, y) for x, y in zip(mn, b)], [max(x, y) for x, y in zip(mx, b)], n + 1)
            example.setdefault(k, b)
            if len(b) == 60 and b[0] == 0x04 and b[2] == 0x74:
                for c, o in FIELDS.items():
                    v = struct.unpack('>hhh', b[o:o+6])
                    a = xinput[phase].get(c, (v, v))
                    xinput[phase][c] = (tuple(map(min, a[0], v)), tuple(map(max, a[1], v)))
    print("\r   " + _("done.") + "            ")
say("\n✔ " + _("Finished: you can leave everything now.") + "\n")

def spread(phase, k):
    if k not in data[phase]: return None
    mn, mx, _n = data[phase][k]
    return [y - x for x, y in zip(mn, mx)]

keys = sorted({k for f in data for k in data[f]})
for k in keys:
    total = sum(data[f][k][2] for f in data if k in data[f])
    say(_("== %s: %d messages of %d bytes, starting with %s") % (k[0], total, k[1], k[2]))
    say("   " + _("example: ") + example[k].hex(' '))
    r0 = spread('rest', k) or [0] * k[1]
    for phase, _x in PHASES[1:]:
        r = spread(phase, k)
        if r is None: say("   %-9s: " % phase + _("(none arrived)")); continue
        moving = [(i, v) for i, v in enumerate(r) if v > 3 * r0[i] + 2]
        txt = ', '.join(_("byte %d (±%d)") % (i, v) for i, v in moving[:24]) or _('nothing')
        say("   %-9s: " % phase + _("change more than at rest → %s") % txt)
    say("   %-9s: " % 'rest' + _("bytes that already change when still → %s") %
        (', '.join(f"{i}" for i, v in enumerate(r0) if v > 2) or _('none')))
if any(xinput[f] for f in xinput):
    say("\n" + _("== XInput report (InputPlumber's format), variation per phase:"))
    for phase, _x in PHASES:
        for c, (a, b) in xinput[phase].items():
            say(f"   {phase:9} {c:11}: {tuple(y - x for x, y in zip(a, b))}")
else:
    say("\n" + _("(No report with InputPlumber's XInput format: id 0x04, command 0x74, 60 bytes.)"))
say("\n" + _("Reading: if in the 'left' phase bytes change that do not change in 'right' (and the other way round), each\n"
             "controller sends its IMU. If nothing changes when turning a controller, its IMU is off."))
EOF
