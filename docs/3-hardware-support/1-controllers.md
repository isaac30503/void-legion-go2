# Controllers and gyroscope

**InputPlumber** (SteamOS's input bridge) joins the controllers (through `hidraw`), their touchpad and the
**body's gyroscope** (the tablet's, `gyro_3d`/`accel_3d` through `amd_sfh`) into one **virtual Valve
controller** (`28DE:12FB`, "Legion Go 2 Controller", the same as on SteamOS). Steam then sees every button (back
ones included), the Deck-style touchpad and the gyroscope. It is not in Void; the official binary works as is
(it needs Void's `libiio` 0.26) and does not need `hid_lenovo_go`.

## Install

```bash
sudo bash "$B/legion/install-inputplumber.sh"          # --remove undoes it
```

Then close Steam completely and open it again.

- **Binary:** `inputplumber-x86_64.tar.gz` of **v0.81.0** (GitHub `ShadowBlip/InputPlumber`), from the Release; the
  script checks its SHA-256 (`bb167707…f777b`).
- Installs `libiio` and `acl-progs` if missing; copies the package's files (binary, profiles, udev rules, hwdb,
  D-Bus and polkit policy) **except** the systemd units and `90-inputplumber-autostart.rules` (list in
  `/usr/local/share/inputplumber-void/manifest`, used by `--remove`); runit service **`inputplumber`**, log in
  **`/var/log/inputplumber/current`**.
- **Hiding the original devices** (so Steam sees one controller, not two): InputPlumber reads the `M:`/`U:` lines
  of `udevadm info`, which eudev's `udevadm` does not print, and uses `setfacl` (`acl-progs`).
  **`inputplumber-udevadm`** is installed as `/usr/local/lib/inputplumber-void/bin/udevadm`, first in the
  service's `PATH` only: for `udevadm info <device>` it adds `M:`, `U:` and `T:` from `P:`, `E: SUBSYSTEM=` and
  `E: DEVTYPE=`, and passes everything else to the real one.
- **Own profile** `/etc/inputplumber/devices.d/50-legion_go_2.yaml` (overrides
  `/usr/share/inputplumber/devices/`): the package's one with **`deck-uhid`** instead of `xbox-elite`, the two
  `imu` sources **without `blocked: true`** (otherwise the body's gyroscope never reaches Steam) and a diagonal
  `mount_matrix` of **100** (gyroscope) and **10** (accelerometer): the kernel declares scales 100× and 10× too
  small (`in_anglvel_scale` 0.000174532 for integer °/s; `in_accel_scale` 0.098 for integer m/s²), and the
  profile has no other scale option. Axes untouched (verified: the pointer goes where the console turns).

## Check

```bash
pgrep -a inputplumber
ls /sys/bus/hid/devices/ | grep 28DE           # 0003:28DE:12FB… (HID_NAME=Legion Go 2 Controller)
inputplumber device 0 capabilities | tr ',' '\n' | grep -iE 'gyro|accel'   # Gamepad:Gyro and Gamepad:Accelerometer
sh "$B/legion/diag-gyro.sh"                    # without root; turn the console for 20 s
```

In `/proc/bus/input/devices`: `InputPlumber Mouse/Keyboard/Touchpad` and, with Steam open, **a single**
`Microsoft X-Box 360 pad 0`; `grep -c 'Failed to hide' /var/log/inputplumber/current` does not grow when the
service restarts. The kernel still lists `Generic X-Box pad`, hidden (permissions `000`; InputPlumber uses it
for vibration). `diag-gyro.sh` reads what Steam receives (the Deck's report 0x09: accelerometer in bytes 24–29,
gyroscope in 30–35, 0.0625 °/s per unit): at rest ≈ 15,190 of acceleration (1 g = 16,384); turning, the gyroscope
goes from hundreds to ≈ 1500, axis by axis with the sensor.

On wake from suspend the controller reconnects over USB and InputPlumber adds it again by itself (no equivalent
of systemd's `inputplumber-suspend.service` is needed).

## Using the gyroscope

- In Steam, **the gyroscope as mouse acts only with the thumb resting on the right trackpad** (like on the Deck).
- Steam's "Probar entradas del dispositivo" ("Test Device Inputs") **does not show the gyroscope**.
- The sensor's resolution is low (1 °/s and 1 m/s² steps): fine for the pointer, it can feel stepped when aiming
  very finely. It is the same sensor and driver as on SteamOS.

## Problems

- **Steam sees two controllers, or a `Generic X-Box pad` / Xbox Elite:** `Failed to hide device` in the log means
  `acl-progs` or the `udevadm` wrapper are missing; an Xbox Elite means the own profile is missing. Run the
  installer again, then close and open Steam.
- **The gyroscope moves nothing:** thumb on the right trackpad; the capabilities above; if they lack it, the
  profile is blocking the `imu` sources again: run the installer again.
- **After installing or restarting InputPlumber the session ignores the keyboard and mouse:** InputPlumber asks
  udev to re-add every input device, and labwc can lose them (`libseat … Could not close device: Device not
  taken` in `~/.xsession-errors`). Reboot (over SSH, `sudo reboot`).

## Known limits

- **CPU:** a fixed ~3.2–3.5 % of one core and ~7100–7200 wakeups/s in every mode, mostly from reading the body's
  IMUs (it opens and closes their sysfs files ~389 times/s) and from writing the virtual controller
  (`/dev/uhid`). Left as is: lowering the IMUs' rate (`AngvelSampleRate`/`AccelSampleRate`, D-Bus) to 100 would
  save about half, but is not persistent and costs gyroscope samples. Measure with
  `sudo bash "$B/legion/diag-inputplumber-cpu.sh" <label>` (read-only, ~65 s; uses `strace` if installed; result
  in `/tmp/medir-inputplumber-<label>.txt`).
- **The gyroscope of each detached controller is not used** (only the tablet's): each controller has a full IMU,
  but it is off without `hid-lenovo-go`, and InputPlumber 0.81 filters it; making Steam use the right controller's
  would mean changing and building InputPlumber. Tools that were written to study it (read-only or reversible):
  `sudo sh "$B/legion/diag-controller-gyros.sh"` (reads the controller's three `hidraw`), `sudo sh "$B/legion/test-controller-imu.sh" [--keep]` (turns
  each controller's IMU "bypass" on and back off; command from the kernel's `drivers/hid/hid-lenovo-go.c`: output
  report `0x05`, `05 00 04 <setting> <controller> <value>`) and `right-controller-gyro.sh [--undo]` (does **not**
  work with 0.81: `Failed to set filtered events`).
- Warnings `Unable to read available scales … ENOENT` from the IMU in the log are normal.
