### InputPlumber: the Legion's controller as a Valve controller (2026-10-04)

SteamOS's bridge: it joins the controller (through `hidraw`), its touchpad and the body's gyroscope
(`gyro_3d`/`accel_3d`, `amd_sfh`) into a virtual Valve controller. **"Body" = the tablet, the part
with the screen:** it is the only gyroscope that reaches Steam (the emulated Deck controller has only one;
InputPlumber's capabilities are `Gamepad:Gyro` and `Gamepad:Accelerometer`, without one per controller).
With the controllers attached it makes no difference (everything moves together); **with the controllers detached, moving them does
nothing**: only moving the tablet counts (observed by the user on 2026-10-05; see *Pending*). With it Steam sees all the buttons
(back ones included), the Deck-style touchpad and the gyroscope, and on the desktop Steam handles it
with its desktop layout. **It is not in Void**, but the official binary works as is (it only
lacks `libiio.so.0` = Void's `libiio` 0.26) and **it does not need `hid_lenovo_go`**.

```bash
cp "$B/legion/"{install-inputplumber.sh,inputplumber-x86_64.tar.gz,inputplumber-udevadm} ~/
sudo bash "$B/legion/install-inputplumber.sh"          # remove: --remove
# afterwards: close Steam completely and open it again
```

- **Download:** `inputplumber-x86_64.tar.gz` of **v0.81.0** (GitHub `ShadowBlip/InputPlumber`,
  14-09-2026), copy in `legion/`; the script checks its SHA-256 (`bb167707…f777b`).
- **What it does:** installs `libiio` and `acl-progs` if missing; copies the package's files (binary, profiles, udev
  rules, hwdb, D-Bus and polkit policy) **except** the systemd units and
  `90-inputplumber-autostart.rules` (list in `/usr/local/share/inputplumber-void/manifest`, used
  by `--remove`); reloads udev and D-Bus; runit service **`inputplumber`** (`sv check dbus` and
  `LOG_LEVEL=info`), with a readable log in **`/var/log/inputplumber/current`** (`svlogd`).
- **Hiding the original devices (2026-10-04).** InputPlumber hides the original controller from the other
  programs (`chmod 000` + `setfacl -b` with its own rules in `/run/udev/rules.d/`). On Void
  it failed with `WARN … Failed to hide device '…': "Unable to create match rule for device"` because of
  **two differences with SteamOS**: it reads the name and the subsystem from the `M:` and `U:` lines of
  `udevadm info` (`src/udev/mod.rs`, `get_device`), which **eudev's `udevadm` does not print** (only
  `P:`/`N:`/`E:`), and its rules use **`setfacl`**, which was not there (`acl-progs`). Consequence:
  Steam also saw the `Generic X-Box pad` and created **two** controllers (`Microsoft X-Box 360 pad 0` and
  `1`). Fix without touching packages: **`inputplumber-udevadm`** (in `legion/`) installed
  as `/usr/local/lib/inputplumber-void/bin/udevadm` and put **first in the service's `PATH`**
  (only for InputPlumber): for `udevadm info <device>` it adds `M:`, `U:` and `T:` from
  `P:`, `E: SUBSYSTEM=` and `E: DEVTYPE=`; everything else goes to the real `udevadm`. **Verified on 2026-10-04,
  also after rebooting:** 0 `Failed to hide` warnings, originals (`Generic X-Box pad`, keyboard,
  mouse and touchpad of the "Legion Controller", the controller's `hidraw`) with permissions `000`, **a single
  controller** in Steam (Ajustes → Mando / Settings → Controller) and all buttons in the button test.
- **Own profile** `/etc/inputplumber/devices.d/50-legion_go_2.yaml` (takes priority over
  `/usr/share/inputplumber/devices/`): the package's one with `deck-uhid` instead of `xbox-elite`. Without
  it Steam would see an Xbox Elite.
- **The body's gyroscope and accelerometer** (`gyro_3d`/`accel_3d` through `amd_sfh`, InputPlumber's `iio`
  sources): 0.81 declares them in its Go 2 profile (SteamOS's 0.78 does not, and there it did not
  work), but they did not reach Steam. **Debugging of 2026-10-04**, in order:
  1. **Symptom:** with "Uso: Giroscopio" ("Usage: Gyro") as mouse in the desktop layout, turning the
     console moved nothing. Steam's "Probar entradas del dispositivo" ("Test Device Inputs") **does not show the gyroscope**
     (it is no use for this).
  2. **The sensor does work:** `/sys/bus/iio/devices/iio:device*/in_anglvel_{x,y,z}_raw` (the one
     named `gyro_3d`) changes when turning: integers of up to ±60 in a normal turn.
  3. **Cause 1 — essential, checked:** `inputplumber device 0 capabilities` did not have
     `Gamepad:Gyro` or `Gamepad:Accelerometer`. The profile's two `imu` sources carry **`blocked:
     true`**: InputPlumber opens them but discards their data. The profiles of other consoles with a
     gyroscope (Ayaneo, GPD, AYN) do not carry it. The installer removes it from the own profile (only from
     those two; the other 4 `blocked`, the ones that hide the original keyboard, mouse and touchpad,
     stay). Afterwards, the capabilities do include `Gamepad:Gyro` and `Gamepad:Accelerometer`.
  4. **Cause 2 — the scale the kernel declares:** the gyroscope gives raw **integer °/s** (a
     slow turn ≈ 28) but declares `in_anglvel_scale` 0.000174532 (0.01 °/s in rad/s), **100 times
     less**; the accelerometer gives **integer m/s²** (gravity ≈ 9) and declares `in_accel_scale` 0.098
     (gravity 0.9: **10 times less**). InputPlumber does `(raw + offset) × scale`, then the
     **`mount_matrix`** (linear) and then ×916.73 to Deck units (code of v0.81:
     `src/drivers/iio_imu/driver.rs`, `src/input/source/iio/accel_gyro_3d.rs`; there is no scale
     option in the profile, `ImuConfig`/`IIO` only accept `mount_matrix`). The installer puts a
     diagonal `mount_matrix` **100** (gyroscope) and **10** (accelerometer), axes untouched.
     **Need of the ×100: deduced, not proven with an A/B test** — without it ≈15
     units would arrive when turning (≈1 °/s, noise) instead of ≈1500; the test after unblocking is no use
     to rule it out because it was done **without touching the trackpad** (see 6). **The accelerometer's ×10
     is not necessary for the gyroscope as mouse** (it does not use the accelerometer); it corrects gravity
     for Steam's modes that orient themselves with it. To prove the ×100: `GYRO=1` in the
     installer, reinstall (see warning below) and check that the pointer barely moves.
  5. **Check of what Steam receives:** reading the virtual Valve controller (the `/dev/hidraw*`
     of `28DE:12FB`; the Deck's report 0x09: accelerometer `int16` in bytes 24–29, gyroscope in
     30–35, 0.0625 °/s per unit): accelerometer ≈ 15,190 (1 g = 16,384), gyroscope from hundreds to
     ≈ 1500 when turning, following the sensor second by second. Script: **`diag-gyro.sh`** (in
     `legion/`, without root: `sh "$B/legion/diag-gyro.sh"` and turn the console for 20 s).
     **Reference result (2026-10-04):** capabilities with `Gamepad:Gyro` and
     `Gamepad:Accelerometer`; when turning, rotation towards Steam from hundreds to 1535 following the sensor
     **axis by axis** (sensor x = 60 °/s → first axis 1135; y = 49 → second axis 1023: X→X, Y→Y, Z→Z);
     at rest, acceleration (0, −14409, −4803), magnitude ≈ 15,190 (0.93 g). **The sensor has low
     resolution:** the gyroscope goes 1 °/s at a time and the accelerometer 1 m/s² at a time (steps of 1601
     Deck units); enough for the pointer, it can feel stepped when aiming very finely.
     It is the same sensor and driver as in SteamOS.
  6. **In Steam, the gyroscope as mouse only acts with the thumb resting on the right trackpad**
     (like on the Deck, so the pointer does not move when picking up the console): it was not a failure, nothing had to be
     changed. With that, **it works** (verified by the user on 2026-10-04). "Uso: Giroscopio" ("Usage: Gyro")
     as mouse stayed in the desktop layout (copy in Common); "Ninguno" ("None") removes it.
  **Correct axes** (the pointer goes where you turn; verified by the user on 2026-10-04):
  the `mount_matrix` does not need to reorder them. **In a game it also works:** Borderlands 3
  (verified by the user on 2026-10-04). The gyroscope of each detached controller is something else
  (without `hid_lenovo_go` it is not activated). In the log there are warnings `Unable to read available scales
  … ENOENT` from the IMU: they are normal.
- **Reinstalling or restarting InputPlumber can leave the session unresponsive:** on start it asks
  udev to remove and add again all the input devices (to hide the originals) and
  labwc can be left without keyboard or mouse (in `~/.xsession-errors`: `libseat … Could not close
  device: Device not taken`). It happened once on 2026-10-04: reboot (over SSH, `sudo reboot`).
- **Check:** `pgrep -a inputplumber`; `ls /sys/bus/hid/devices/ | grep 28DE` →
  `0003:28DE:12FB…` with `HID_NAME=Legion Go 2 Controller` (**the same virtual controller as in
  SteamOS**); in `/proc/bus/input/devices`, `InputPlumber Mouse/Keyboard/Touchpad` and, with Steam
  open, **a single** `Microsoft X-Box 360 pad 0`; `grep -c 'Failed to hide'` in the log does not
  grow when restarting the service. The kernel still sees `Generic X-Box pad`, hidden (permissions
  `000`; InputPlumber only uses it for vibration).
- **Verified by the user on 2026-10-04** on the desktop (Xfce Wayland, Steam open).
  In Game Mode, all the buttons (2026-10-04). **Suspend:** systemd's `inputplumber-suspend.service`
  (HookSleep/HookWake) has no equivalent here and **is not needed**: on wake the
  controller reconnects over USB and InputPlumber adds it again by itself (`Found missing hidraw device
  … adding source device`); the controller works entirely (2026-10-04). The gyroscope in a game, verified later
  (Borderlands 3, point 6 above).
- **CPU usage: measured on 2026-10-08 and left as is** (the user's decision). Tool:
  **`legion/diag-inputplumber-cpu.sh`** (read-only; it does not restart InputPlumber or touch the
  profile). It does **three passes of 20 s, ~65 s in total** (`DUR=30 sudo -E …` changes the duration): 1)
  **without strace** (the reliable figure): CPU of the process and per thread, context switches and reads and
  writes per second; 2) `strace -f -c`, call summary; 3) trace counted **per descriptor
  translated to its path** (which `/sys/bus/iio/…`, `/dev/hidraw*`, `/dev/uhid` or `/dev/input/event*` is read
  or written and how many times per second) and the wait timeouts. It needs root and `strace` (`sudo
  xbps-install -S strace`; without it, it does only pass 1; remove it when done): `sudo bash
  diag-inputplumber-cpu.sh <label>` (`modojuego` and `escritorio` without touching the controller;
  `modojuego-mando` moving it all the time); result in `/tmp/medir-inputplumber-<label>.txt`
  (644; the script's header explains how to read it). While strace is attached (passes 2 and 3) the
  input can be somewhat slower.
  **Results of 2026-10-08** (pass without strace; the three files, archived in
  `fish/void/logs/legion/medir-inputplumber-{modojuego,escritorio,modojuego-mando}-2026-10-08.txt`):

  | Situation | CPU (% of one core) | Wakeups/s |
  |---|---|---|
  | Game Mode, idle | 3.2 | ~7170 |
  | Desktop (Xfce Wayland, Steam in the background and `extest`) | 3.5 | ~7110 |
  | Game Mode, moving the controller | 3.3 | ~7200 |

  **It is a fixed cost, the same in all modes.** Where it comes from: (1) **the body's IMUs**
  (`iio:device1` `gyro_3d` and `iio:device2` `accel_3d`, with the iio buffer off, at 200 Hz):
  InputPlumber **opens, reads and closes** each of the 6 `in_*_raw` files about 389 times per second
  (double the sensor's 200 Hz), ~9000 calls/s, with a `clock_nanosleep` loop of 2.1–2.4
  ms; (2) **the virtual Valve controller:** ~830–920 `write`/s to `/dev/uhid` (necessary: it is what
  Steam sees); (3) little from the physical controller (`/dev/hidraw1` 33/s, `event10` ~190–310/s). **Unexplained:** the
  average since the process started is around 10 % (there were periods of higher usage that the measurement did not catch).
  **Option studied and NOT applied:** lowering `AngvelSampleRate`/`AccelSampleRate` (writable D-Bus
  properties of `org.shadowblip.Input.Source.IIOIMUDevice`, today 200) to 100 live. It would save more
  or less half, at the cost of fewer gyroscope samples, without knowing whether the sensor accepts it (it does not
  publish available frequencies) and without persisting (it is lost when InputPlumber restarts). Blocking
  the IMUs again, as it comes from the factory, would remove the body's gyroscope: discarded. See
  *Pending → Decided*.

