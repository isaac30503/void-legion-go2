#!/bin/sh
# Legion Go 2: TEST (until reboot) of Steam receiving the gyroscope of the RIGHT CONTROLLER instead of
# the tablet's. The right one works attached (it moves with the tablet) and detached: a single source,
# without changing depending on the case. Without rebuilding anything:
#  1. Right controller with "IMU bypass: yes" (hid-lenovo-go's command, see test-controller-imu.sh): its
#     full IMU comes out in the controller's report.
#  2. InputPlumber, running, over D-Bus (property FilteredEvents of CompositeDevice0, writable;
#     src/dbus/interface/composite_device.rs of v0.81): in the controller's hidraw source it lets through
#     Gyroscope:Right and Accelerometer:Right (without hid-lenovo-go it discards the controller's six) and in
#     the tablet's iio sources it discards Gyroscope:Center and Accelerometer:Center.
# It is lost on reboot, when the controller reconnects or when InputPlumber restarts (then, repeat).
# Result on 2026-10-05: it does NOT work like this (InputPlumber 0.81 does not apply the whole filter;
# Legion recipe, Pending → Decided).
# Previous (Spanish) name: giro-mando-derecho.sh (its log of 2026-10-05 is archived in logs/legion/).
#   sudo sh legion/right-controller-gyro.sh          # apply
#   sudo sh legion/right-controller-gyro.sh --undo   # back to the tablet (saved filter + bypass: no;
#                                                    #  --deshacer also works)
# Check: sh legion/diag-gyro.sh turning the right controller DETACHED (what reaches Steam must move)
# and, in Steam, the gyroscope as mouse. Log: ~/right-controller-gyro.log.
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
DEV=""
for h in /sys/class/hidraw/hidraw*; do
    grep -qiE 'HID_ID=0003:000017EF:000061E[B-E]' "$h/device/uevent" 2>/dev/null || continue
    [ -e "$h/device/../ep_83" ] && DEV=/dev/${h##*/}
done
[ -n "$DEV" ] || { t "I cannot find the controller's configuration interface (endpoint 0x83)"; exit 1; }
case "${1:-}" in --deshacer) set -- --undo ;; esac
VL_LIB="$REPO_ROOT/lib" python3 - "$DEV" "${1:-}" <<'EOF' 2>&1 | tee "$TARGET_HOME/right-controller-gyro.log"
import os, sys, time, select, json, subprocess
sys.path.insert(0, os.environ.get("VL_LIB", ""))
try:
    from void_legion_i18n import _
except ImportError:
    _ = lambda s: s
dev, undo = sys.argv[1], sys.argv[2] == '--undo'
SAVED = '/run/right-controller-gyro.filter-before'
BUS = ['busctl', '--system', '--json=short']
DEST = ['org.shadowblip.InputPlumber', '/org/shadowblip/InputPlumber/CompositeDevice0',
        'org.shadowblip.Input.CompositeDevice']

def prop(name):
    return json.loads(subprocess.check_output(BUS + ['get-property'] + DEST + [name]))['data']
def set_filter(f):
    args = [str(len(f))]
    for source, caps in f.items(): args += [source, str(len(caps))] + caps
    subprocess.check_call(['busctl', '--system', 'set-property'] + DEST + ['FilteredEvents', 'a{sas}'] + args)

fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
def right_bypass(value):          # 01 = yes, 02 = no; returns the value read afterwards
    for pkt in ([0x05, 0x00, 0x04, 0x03, 0x04, value], [0x05, 0x00, 0x03, 0x03, 0x04]):
        while select.select([fd], [], [], 0)[0]:
            try: os.read(fd, 128)
            except BlockingIOError: break
        os.write(fd, bytes(pkt) + bytes(64 - len(pkt)))
        end, read = time.time() + 0.6, None
        while time.time() < end:
            if not select.select([fd], [], [], 0.05)[0]: continue
            try: b = os.read(fd, 128)
            except BlockingIOError: continue
            if len(b) > 5 and b[1] == 0x00 and b[2] == 0x03 and b[3] == 0x03 and b[4] == 0x04: read = b[5]
    return {1: _('yes'), 2: _('no')}.get(read, _('no answer (%s)') % read)

print(_("InputPlumber's filter before:"), json.dumps(prop('FilteredEvents')))
if undo:
    # First the controller (what may stay saved in it); InputPlumber's filter is lost
    # anyway on reboot. The saved filter is no use if the controller reconnected (the sources
    # change): the factory one is set with the current sources.
    print(_("Right controller, IMU bypass →"), right_bypass(0x02))
    f = {k: [c for c in v if c.startswith(('Gyroscope:', 'Accelerometer:'))]
         for k, v in prop('FilterableEvents').items() if k.startswith('hidraw://')}
    f = {k: v for k, v in f.items() if v}
    try: set_filter(f)
    except subprocess.CalledProcessError as e: print(_("The filter could not be set:"), e)
    print(_("InputPlumber 0.81 fails when changing filters (\"failed to send command to device\") and may"))
    print(_("leave something half done: rebooting the Legion leaves everything as from the factory."))
    try: os.remove(SAVED)
    except OSError: pass
else:
    if not os.path.exists(SAVED):
        json.dump(prop('FilteredEvents'), open(SAVED, 'w'))
    filterable = prop('FilterableEvents')
    f = {}
    for source, caps in filterable.items():
        if source.startswith('hidraw://') and 'Gyroscope:Right' in caps:
            f[source] = ['Gyroscope:Left', 'Gyroscope:Center', 'Accelerometer:Left', 'Accelerometer:Center']
        elif source.startswith('iio://'):
            f[source] = [c for c in caps if c in ('Gyroscope:Center', 'Accelerometer:Center')]
    if not any(k.startswith('hidraw://') for k in f):
        sys.exit(_("InputPlumber does not have the controller's source with Gyroscope:Right: nothing is changed"))
    print(_("Right controller, IMU bypass →"), right_bypass(0x01))
    set_filter(f)
print(_("InputPlumber's filter now:"), json.dumps(prop('FilteredEvents')))
print(_("Done.") + ("" if undo else " " + _("Test: sh legion/diag-gyro.sh turning the right controller detached.")))
EOF
