#!/bin/sh
# Diagnosis of the Legion Go 2's body gyroscope (docs/3-hardware-support/1-controllers.md). Without root.
# During the 20 s, TURN the console. It compares, second by second, the kernel's raw sensor
# (amd_sfh's gyro_3d, integer °/s) with what InputPlumber's virtual Valve controller sends to
# Steam (hidraw of 28DE:12FB, the Deck's report 0x09: int16 gyroscope in bytes 30-35,
# 0.0625 °/s per unit; accelerometer in 24-29, 1 g = 16384). Before that, InputPlumber's capabilities.
# Previous (Spanish) name: diag-giroscopio.sh.
# Usage: sh legion/diag-gyro.sh   (over SSH or on the Legion)
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
t "== capabilities (Gamepad:Gyro and Gamepad:Accelerometer must show)"
inputplumber device 0 capabilities 2>/dev/null | tr ',' '\n' | grep -iE 'gyro|accel' || t "  NONE: imu sources with blocked: true in the profile?"
g=$(grep -l gyro_3d /sys/bus/iio/devices/iio:device*/name 2>/dev/null | xargs -r dirname)
[ -n "$g" ] || { t "there is no gyro_3d (amd_sfh)"; exit 1; }
t "== sensor: %s, declared scale %s" "$g" "$(cat "$g/in_anglvel_scale")"
h=; for d in /sys/class/hidraw/*; do grep -q 'HID_ID=.*000028DE:000012FB' "$d/device/uevent" 2>/dev/null && h=/dev/${d##*/}; done
[ -n "$h" ] || { t "the virtual controller 28DE:12FB is not there (InputPlumber stopped?)"; exit 1; }
t "== virtual controller: %s. TURN THE CONSOLE for 20 s" "$h"
VL_LIB="$REPO_ROOT/lib" python3 - "$g" "$h" <<'PY'
import os, struct, time, select, sys
sys.path.insert(0, os.environ.get("VL_LIB", ""))
try:
    from void_legion_i18n import _
except ImportError:
    _ = lambda s: s
g, h = sys.argv[1], sys.argv[2]
fd = os.open(h, os.O_RDONLY | os.O_NONBLOCK)
t0 = time.time(); sec = -1; mx = [0, 0, 0]; acc = None
while time.time() - t0 < 20:
    r, _w, _x = select.select([fd], [], [], 0.2)
    if r:
        try: d = os.read(fd, 64)
        except BlockingIOError: d = b''
        if len(d) >= 36:
            v = struct.unpack_from('<3h', d, 30); mx = [max(mx[i], abs(v[i])) for i in range(3)]
            acc = struct.unpack_from('<3h', d, 24)
    s = int(time.time() - t0)
    if s != sec:
        if sec >= 0:
            raw = [open(f"{g}/in_anglvel_{a}_raw").read().strip() for a in "xyz"]
            print(_("s%02d  to Steam: max rotation %s  acceleration %s  | sensor (°/s): %s") % (sec, mx, acc, raw))
        sec = s; mx = [0, 0, 0]
PY
t "Fine: when turning, 'max rotation' from hundreds to ~1500; acceleration with magnitude ~16384 (1 g)."
t "If the rotation stays at ~15: the profile's ×100 mount_matrix is missing (the kernel's scale)."
