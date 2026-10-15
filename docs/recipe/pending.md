## Pending

**To test:** nothing (2026-10-08). The manual GPU clock brought back and the `set_clocks` patch
were verified that day (step 14, steamos-manager, and *Verified*, above).
The Game Mode items (game sound, Vesktop shortcut, gamescope
patch with settings changes and Borderlands 3) were verified and decided (step 14, "Screen
sharing in Game Mode").

**Decided** (studied and left as is on purpose)

- **InputPlumber's consumption: LEFT AS IS** (the user's decision, 2026-10-08). ~3.2–3.5 % of one core
  and ~7100–7200 wakeups/s, fixed in Game Mode, on the desktop and moving the controller; mostly
  from reading the body's IMUs by opening and closing their sysfs files ~389 times/s and from the virtual
  Valve controller (`/dev/uhid`). Lowering the IMUs' frequency to 100 over D-Bus would save more or less
  half at the cost of gyroscope samples (and without knowing if the sensor accepts it, nor persisting): not
  worth it. Detail and measurements in step 14, InputPlumber. The ~10 % average since boot
  is still unexplained: if wanted, repeat `diag-inputplumber-cpu.sh` when higher usage is noticed.
- **steamos-manager's build dependencies: KEPT** (the user's decision, 2026-10-08:
  "no me es prioritario borrar dependencias de compilación si se requieren para el mantenimiento tras
  actualizaciones" — "deleting build dependencies is not a priority for me if they are needed for maintenance after
  updates"). `glib-devel`, `eudev-libudev-devel`, `speech-dispatcher-devel`, `clang` and
  `pkg-config` (34 packages with their dependencies, ≈ 470 MB; `void-update` updates them too) are
  used by `build-steamos-manager.sh`; gamescope and the wlroots portal are not (`xbps-src` brings its own in
  its environment), nor `extest` (Rust and `gcc-multilib`). How to remove them if one day wanted: step 14,
  steamos-manager, "How it is built".
- **Noise in the logs: LEFT AS IS** (2026-10-08): one line per warning, with the cause, in
  Troubleshooting, *Known noise in the logs (harmless)*.
- **Gyroscope of each detached controller: LEFT AS IS, on purpose** (the user's decision,
  2026-10-05, after the tests below: it would require patching and building InputPlumber). Today, detached, the rotation comes only from the tablet (step 14,
  InputPlumber). What was known before testing it: the **gyroscope of each controller**, which without `hid_lenovo_go` (Valve's patch) is not
  activated (its udev rule sets `imu_bypass_enable`, `os_mode` and the touchpad vibration).
  **They do have a gyroscope** (checked in InputPlumber v0.81's source, 2026-10-05): the report
  of the Go 2's controller (`src/drivers/lego/hid_report.rs`, `XInputDataReport`, 60 bytes) carries
  accelerometer and gyroscope **of each controller** (`left_accel_*`/`left_gyro_*`, bytes 35–46;
  `right_*`, 48–59), and `hid-lenovo-go` has `left_handle/` and `right_handle/imu_bypass_enable`.
  **InputPlumber discards them** without `hid-lenovo-go` (`src/drivers/lego/mod.rs`:
  `DEFAULT_EVENT_FILTER` filters the six: center, left and right); with it, it lets through only the
  "center" (the average of the two controllers). Its own comment says that turning the IMU on in the
  kernel driver "is broken for now" (it talks about the Go 1). That is: the hardware is there, but not even
  with Valve's kernel is it clear it would work.
  **Diagnosis of 2026-10-05** (`sudo sh "$B/legion/diag-controller-gyros.sh"`, in `legion/`; it only
  reads the controller's three `hidraw` interfaces and keeps saying what to do: still → turn the left one →
  the right one → the tablet; output saved in `logs/legion-diagnostics-2026-10-04/diag-giroscopio-mandos-2026-10-05.log`).
  Through interface 2 arrives the XInput report (`04 3c 74…`; `read` gives 64 bytes, the report is the first
  60), ~175 per second:
  - **The full IMU of each controller is OFF:** bytes 35–59 (3-axis accelerometer and gyroscope
    of each controller) are at zero and do not change when turning. The power-on command that
    `hid-lenovo-go` sends (`imu_bypass_enable`) is needed.
  - **But each controller does send a low-resolution rotation** that InputPlumber does not use
    (`left_gyro_lq_x/y` = bytes 30–31, `right_gyro_lq_x/y` = 32–33; `u8`, center `0x80`): when turning the
    left one 30 and 31 changed (up to ±255), when turning the right one 32 and 33; with the tablet, nothing.
    They are 2 axes per controller and 8-bit.
  - Everything else that changed came from touching the sticks or the touchpad: byte 14 (left stick), 16–17 (right
    stick), 27–29 (touchpad) and interface 1 (touchpad messages, 20 bytes).
  **Paths:** (a) send the IMU power-on command through `hidraw`, like `hid-lenovo-go` (the protocol has to be
  taken from its source; it writes to the controller); (b) use the low-resolution bytes, which
  requires changing InputPlumber's code. Neither done.
  **Power-on, tested on 2026-10-05** (`sudo sh "$B/legion/test-controller-imu.sh" [--keep]`, in
  `legion/`; output in `logs/legion-diagnostics-2026-10-04/probar-imu-mando-2026-10-05.log`). The command
  comes from `drivers/hid/hid-lenovo-go.c`, **which is already in the official kernel** (git.kernel.org; Valve's
  kernel is not needed to read it): 64-byte output report `0x05` through interface 2
  (the one of endpoint `0x83`, here `hidraw1`), `05 00 03 <setting> <controller>` to read and `05 00 04 <setting>
  <controller> <value>` to change; setting `05` = IMU on, `03` = IMU bypass; controller `03` = left,
  `04` = right; value `01` = yes, `02` = no; the controller answers `04 00 …` with the value.
  - **From the factory:** both controllers with "IMU on: yes" and "bypass: no".
  - "IMU on" alone changes nothing (bytes 48–59 at zero). **With "bypass: yes" the full IMU of the
    right one shows in the report** (when turning it, variations from 400 to 6600 in bytes 48–59) and the
    controller starts sending about 125 reports per second instead of ~42.
  - The script set it back to "bypass: no" (checked by reading the setting).
  **Having Steam listen to the right controller instead of the tablet: tested on 2026-10-05, it does NOT work like this**
  (`right-controller-gyro.sh`, in `legion/`; `--undo`). The idea, without rebuilding: "bypass:
  yes" on the right one and, over D-Bus, the writable property `FilteredEvents` of `CompositeDevice0`
  (let through `Gyroscope:Right`/`Accelerometer:Right` from the controller and discard the `:Center` ones of the
  tablet's `iio` sources). The right one would work attached and detached: a single source. What happened:
  - **InputPlumber 0.81 does not apply the whole filter:** in the log, `Failed to set filtered events:
    failed to send command to device`. `set_filtered_events` (`src/input/composite_device/mod.rs`)
    sends the filter to **all** the sources one by one and stops at the first that does not answer
    (here it always fails; with 9 sources, among them the blocked `evdev` ones); those that come before in the
    loop do receive it. Result: the tablet was discarded and **the controller was not unblocked: Steam
    was left without a gyroscope**. It was repeated as is with `busctl` from SSH: same error.
  - **Detaching or attaching the controllers reconnects the controller over USB** with another identifier (`17ef:61eb` →
    `61ed`, and one more interface: endpoint `0x83` moved to `hidraw2`): InputPlumber redoes its sources
    and the controller's filter goes back to the factory one. Any fix would have to be reapplied on every
    reconnection.
  - **Fix on the spot:** the tablet's gyroscope, allowed again through `busctl` (it went in
    because it comes before in the loop); its accelerometer stayed discarded until rebooting (the
    gyroscope as mouse does not use it). **Rebooting leaves InputPlumber as from the factory.**
  **Conclusion:** without touching InputPlumber it cannot be done. Its code would have to change (so that without
  `hid-lenovo-go` it lets the right controller's gyroscope through, and the tablet's `iio` sources
  do not arrive, or choose it through the profile) and be built (Rust is already on the Legion), plus a service that
  sets "bypass: yes" when the controller connects. Not done.

**Wallpaper on Wayland (2026-10-09): xfdesktop and Thunar patched, installed** (step 15) and verified that
day on the Legion's screen: the dialog and "Establecer como fondo de pantalla" ("Set as wallpaper") write `monitoreDP-1` and
the wallpaper changes; `void-update --summary` → 14 × OK. On the external monitor, too (`monitorDP-1`, each
screen with its wallpaper). Remaining limit: the dialog takes the screen when it opens (close it and open it on the
other one); Thunar follows its window. **Done.**

**Before, to do:** nothing (2026-10-08). **Done that day** by the user: registering the name of the package of
the already installed steamos-manager, without reinstalling (`echo steamos-manager-v26.4.1-void-2 | sudo tee
/usr/local/share/steamos-manager-void/paquete`; the installer records it by itself since that day): `void-update
--resumen` gives 12 × OK with `steamos-manager, paquete steamos-manager-v26.4.1-void-2`; `sudo xbps-pkgdb -m manual
speech-dispatcher` (checked: `xbps-query -m` lists `speech-dispatcher-0.12.1_1`) and the empty
folders of the live `/mnt/home` and `/mnt/steamos-home` no longer exist (in `/mnt` only `microsd` remains; the
`rmdir` that time said "No existe" ("Does not exist"): they had already been deleted, `/mnt` modified at 22:33).
`strace` (3.3 MB; installed by the InputPlumber measurement, step 14): removed (checked over SSH on
2026-10-08: `xbps-query strace` does not find it). The Flatpak portals,
the previous item, are installed and verified (step 14, "Discord (Vesktop)", *Desktop portals and
screen sharing*).

**Watch** (nothing to do unless it happens; what to do, in *Troubleshooting*)

- **Black monitor at boot with it connected** (seen once, 2026-10-04): gamescope chose `DP-1`
  at 1920×1080@60 without errors, but no image came out (and the fans sped up) until
  disconnecting and connecting the cable; with the same mode, then it did. After a while it stopped happening with no
  known change. If it comes back: without touching the cable, from the IdeaPad `ssh lego` and `sudo sh "$B/legion/diag-monitor.sh"` (originally copied first with `scp`)
  (in `legion/`; leaves `~/diag-monitor.log` with connectors, GPU, processes and `dmesg`).
- **`udev-net`** (steps 2–3): **it already acted twice** — `/var/log/udev-net/current`: `2026-10-05_02:36:46
  wlan0 sin procesar por udev: se repite el aviso` ("wlan0 not processed by udev: repeating the announcement") (20:36:46 local time on 2026-10-04) and
  `2026-10-08_03:47:11` (21:47:11 local time on 2026-10-07; the log goes in UTC): the Wi-Fi fell again
  into udev's gap in those boots and came out as `wlp193s0` without it being noticed. Keep
  looking from time to time. On the IdeaPad also installed (2026-10-04).
- **`rtkit` in a loop (found on 2026-10-07; solved and verified after rebooting on 2026-10-08):** in this boot D-Bus started
  `rtkit-daemon` before runit (its parent is init, not `runsv rtkit`); runit's exits with code 1
  because the D-Bus name is already taken and runit relaunches it every second (`sudo sv status rtkit` →
  `down: 1s, normally up, want up`, five times in a row). Real-time audio works (the
  D-Bus one provides it). On the IdeaPad runit's won the race, but it could happen just the same. **Done (2026-10-08, approved
  by the user):** `like-steamos.sh` no longer links `rtkit` in runit (and if it finds the link, it stops it and
  removes it) and on both machines it is removed with `sudo sh /tmp/quitar-rtkit-runit.sh` (`sv -w 5 down rtkit` and deletes
  `/var/service/rtkit`; it does not kill D-Bus's `rtkit-daemon`). Now only D-Bus starts it on demand.
  **Verified after rebooting on 2026-10-08** (boots at 00:11 and 00:48; on the IdeaPad, at
  00:14 and 00:41), with the lines of *Verification*: no `/var/service/rtkit`, a single
  `rtkit-daemon` with parent `runit` (D-Bus started it; never `runsv rtkit`) and the four `data-loop`
  of PipeWire and WirePlumber in RR 20. If it came back, it is detected by
  `common/agent/audit-void.sh`.
- **gamescope patch**: if `Segmentation fault` shows up again in `~/.local/state/steam-game-mode.log`
  when streaming, repeat the diagnosis (`legion/diag-gamescope-pipewire.sh`, step 14); and after
  a Void update, `void-update` warns if it has to be rebuilt.
- **`extest`**: if a Steam update breaks it, rebuild (step 14); Rust and `gcc-multilib` are
  kept for that (see *Cleanup*).
  `void-update` warns if `extest`, InputPlumber or `steamos-manager` lack a library.

**Cleanup** (2026-10-05, the user's decision: everything except what may be needed later)

- **Done:** deleted the stray `.bak` (`~/.config/autostart/steam-background.desktop.bak`,
  `~/.local/share/applications/steam.desktop.bak`, `~/.local/bin/window-snap.bak`,
  `~/.local/bin/window-focus.bak`, `~/.config/xfce4/labwc/rc.xml.bak`, `~/.Xresources.bak`) and the
  diagnostic outputs of `~` (`diag-edp-bien.txt`, `diag-edp-negra.txt`, `dmesg-arranque.txt`,
  `diag-steamos-manager.log`), **copied first** to `logs/legion-diagnostics-2026-10-04/`
  (identical, checked with `md5sum`). `~/xfce-wayland/labwc/rc.xml` brought up to date from Common
  (equal to the installed one). `~/.bashrc.bak` is made by the recipe (step 5–12): it stays.
- **Also done** (root, by the user, 2026-10-05): the rest of Plymouth, `sudo rm -r /etc/plymouth`
  (step 8); checked that it no longer exists.
- **Kept on purpose**, in case they are needed: **Rust** (`~/.rustup`, `~/.cargo`, ~770 MB),
  **`~/src/extest`** (78 MB) and **`gcc-multilib`**, to rebuild `extest` if a Steam update
  breaks it (step 14, "Controller on the desktop"); **`drm_info`** and **`wlr-randr`** (step 15)
  and the `diag-*.sh` scripts in `~`, to diagnose screens and the gyroscope.
  → **Changed the same day** (second cleanup, below): the diagnosing things, only in Common.
- **Second cleanup, "final product"** (the user's decision, 2026-10-05: the scripts and all the
  diagnostics, only in Common). First it was checked that **the 63 pieces** of `~` (the `*.sh`,
  `inputplumber-udevadm`, `inputplumber-x86_64.tar.gz` and the folders `steam/`, `tdp/`,
  `xfce-wayland/`) had an **identical** copy in Common (`cmp`, file by file: `legion/`,
  `legion/tdp/`, `legion/steam/installed-packages.txt`, `steam/`, `xfce-wayland/`) and that **nothing of what
  runs uses them** (no reference from `/etc`, `/usr/local`, the services, `~/.config`,
  `~/.local`). The 8 logs (`pasos-1-a-3.log`, `escritorio-1-root.log`, `escritorio-2-root.log`,
  `grub-root.log`, `como-steamos.log`, `giro-mando-derecho.log`, `probar-imu-mando.log`,
  `diag-giroscopio-mandos.log`) were archived in **`fish/void/logs/legion/`** (`md5sum`
  identical) and the 7 `.bak` of `/etc` (`fstab`, `rc.conf`, `avahi-daemon.conf`, `default/grub`,
  `grub.d/10_linux`, `lightdm.conf`, `lightdm-gtk-greeter.conf`: the configuration before each
  change, partly from the factory) in **`logs/legion/etc-bak/`**. Deleted from `~`: the 29 files and
  the 3 folders. **Also done (root, by the user; checked on 2026-10-06):** deleting those `.bak`
  of `/etc` (none is left) and the diagnostic tools (they are reinstalled if needed, step 15):

  ```bash
  sudo rm -f /etc/fstab.bak /etc/rc.conf.bak /etc/avahi/avahi-daemon.conf.bak /etc/default/grub.bak \
      /etc/grub.d/10_linux.bak /etc/lightdm/lightdm.conf.bak /etc/lightdm/lightdm-gtk-greeter.conf.bak
  sudo xbps-remove drm_info wlr-randr
  ```

  Kept, on purpose: `~/src/extest`, `~/.rustup`, `~/.cargo` and `gcc-multilib` (to build `extest`),
  `~/.bashrc.bak` (from the recipe), `/etc/modules-load.d/dm-raid.conf.desactivado` (step 8: it is the
  fix, not a leftover), `~/Projects` (empty, the user's) and the services' logs in
  `/var/log/` and `~/.local/state/`. To diagnose or undo: *Troubleshooting* (scripts from Common).
  **Stray launch option in Borderlands 3:** `VRR_CAPABLE = 1` (from the tests; without
  `%command%`, Steam passes it to the game as arguments): deleted by the user (checked on
  2026-10-06: no game has launch options).

**Optional** (it is not cleanup; it can be done or not)

- **A/B test of the gyroscope's ×100** (step 14, InputPlumber, point 4): with the risk of locking up the
  session when reinstalling InputPlumber.

