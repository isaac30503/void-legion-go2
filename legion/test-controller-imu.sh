#!/bin/sh
# Legion Go 2: TEST of turning on the IMU (3-axis gyroscope + accelerometer) of the RIGHT CONTROLLER,
# without hid-lenovo-go, sending the controller the same command as that driver (drivers/hid/hid-lenovo-go.c
# of the official kernel: mcu_property_out → output report 0x05, 64 bytes, through interface 2 =
# endpoint 0x83):
#   read setting:   05 00 03 <setting> <controller>          (GET_FEATURE_STATUS)
#   change:         05 00 04 <setting> <controller> <value>  (SET_FEATURE_STATUS; value 01 = yes, 02 = no)
#   setting 05 = IMU on (FEATURE_IMU_ENABLE), 03 = IMU "bypass" (FEATURE_IMU_BYPASS)
#   controller 03 = left, 04 = right
# Steps: reads the state of both settings on both controllers; measures (turning the right controller) whether
# the bytes of the right one's IMU (48–59 of the report 04 3c 74…) move: as is, with "IMU on" and
# with "bypass" as well; it stops as soon as they move. At the end it PUTS the right controller BACK as it was
# (with --keep, it leaves it on for the next step). It only touches the right controller.
# Previous (Spanish) name: probar-imu-mando.sh (its log of 2026-10-05 is archived in the private repository, archive/2026-10-14/logs/legion/).
#   sudo sh legion/test-controller-imu.sh [--keep]     
# Log: ~/test-controller-imu.log. docs/3-hardware-support/1-controllers.md, Known limits (2026-10-05).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
DEV=""
for h in /sys/class/hidraw/hidraw*; do
    grep -qiE 'HID_ID=0003:000017EF:000061E[B-E]' "$h/device/uevent" 2>/dev/null || continue
    [ -e "$h/device/../ep_83" ] && DEV=/dev/${h##*/}
done
[ -n "$DEV" ] || { t "I cannot find the controller's configuration interface (17ef:61eb…61ee, endpoint 0x83)"; exit 1; }
VL_LIB="$REPO_ROOT/lib" python3 - "$DEV" "${1:-}" "$TARGET_HOME/test-controller-imu.log" <<'EOF'
import os, sys, time, select, struct
sys.path.insert(0, os.environ.get("VL_LIB", ""))
try:
    from void_legion_i18n import _
except ImportError:
    _ = lambda s: s
dev, keep = sys.argv[1], sys.argv[2] == '--keep'
fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
log = open(sys.argv[3], 'w')
def say(t=''):
    print(t, flush=True); log.write(t + '\n'); log.flush()
SETTING = {0x05: _('IMU on'), 0x03: _('IMU bypass')}
CONTROLLER = {0x03: _('left'), 0x04: _('right')}
VALUE = {0: _('unknown'), 1: _('yes'), 2: _('no')}

def drain():
    while select.select([fd], [], [], 0)[0]:
        try: os.read(fd, 128)
        except BlockingIOError: break

def send(head, wait=0.6):
    """Sends report 0x05 (64 bytes) and returns the answers that are not controller data."""
    drain()
    pkt = bytes(head) + bytes(64 - len(head))
    n = os.write(fd, pkt)
    say(_("   → %s … (%d bytes)") % (pkt[:8].hex(' '), n))
    answers, end = [], time.time() + wait
    while time.time() < end:
        if not select.select([fd], [], [], 0.05)[0]: continue
        try: b = os.read(fd, 128)
        except BlockingIOError: continue
        if len(b) > 1 and b[1] == 0x3c: continue          # normal controller data (04 3c 74…)
        answers.append(b); say(f"   ← {b[:12].hex(' ')}")
    return answers

def read(setting, controller):
    for b in send([0x05, 0x00, 0x03, setting, controller]):
        if len(b) > 5 and b[2] == 0x03 and b[3] == setting and b[4] == controller:
            return b[5]
    return None

def measure(what, sec=6):
    say("\n▶ " + _("NOW: turn the RIGHT controller in all directions (%.0f s) — %s") % (sec, what))
    mn = mx = None; n = 0; end = time.time() + sec
    while (q := end - time.time()) > 0:
        print("\r   " + _("%4.1f s left ") % q, end='', flush=True)
        if not select.select([fd], [], [], 0.2)[0]: continue
        try: b = os.read(fd, 128)
        except BlockingIOError: continue
        if len(b) < 60 or b[0] != 0x04 or b[1] != 0x3c or b[2] != 0x74: continue
        v = struct.unpack('>6h', b[48:60]) + tuple(b[30:34])
        mn = v if mn is None else tuple(map(min, mn, v)); mx = v if mx is None else tuple(map(max, mx, v)); n += 1
    print("\r   " + _("done.") + "            ")
    if mn is None: say("   " + _("no report from the controller arrived")); return False
    r = [y - x for x, y in zip(mn, mx)]
    say("   " + _("%d reports. Variation of the right IMU (bytes 48–59: accel ×3, gyro ×3): %s") % (n, r[:6]))
    say("   " + _("Variation of the low-resolution rotation (bytes 30–33: left x,y · right x,y): %s") % (r[6:],))
    return max(r[:6]) > 20

say(_("Configuration interface: %s. Only the RIGHT controller is changed.") % dev)
say("\n" + _("== Current state"))
orig = {}
for m in (0x03, 0x04):
    for a in (0x05, 0x03):
        v = read(a, m); orig[(a, m)] = v
        say("   " + _("controller %-9s %-13s: %s") % (CONTROLLER[m], SETTING[a], VALUE.get(v, v) if v is not None else _('no answer')))

works = measure(_("as is"))
for a in (0x05, 0x03):
    if works: break
    say("\n" + _("== Right controller: %s → yes") % SETTING[a])
    send([0x05, 0x00, 0x04, a, 0x04, 0x01])
    say("   " + _("now: %s") % VALUE.get(read(a, 0x04), _('no answer')))
    works = measure(_("with %s") % SETTING[a] + ((" " + _("and IMU on")) if a == 0x03 else ""))

say("\n" + _("== Result: ") + (_("the right controller's IMU MOVES (bytes 48–59).") if works else
   _("the right controller's IMU does NOT move with either of the two commands.")))
if keep:
    say(_("--keep: the right controller stays as it is now."))
else:
    say("\n" + _("== Putting the right controller back as it was"))
    for a in (0x03, 0x05):
        v = orig[(a, 0x04)]
        if v in (1, 2):
            send([0x05, 0x00, 0x04, a, 0x04, v]); say("   " + _("%s: %s → now %s") % (SETTING[a], VALUE[v], VALUE.get(read(a, 0x04), _('no answer'))))
        else:
            say("   " + _("%s: the original state could not be read; it is left as is (to turn it off: value 02)") % SETTING[a])
say("\n" + _("Log: ~/test-controller-imu.log"))
EOF
