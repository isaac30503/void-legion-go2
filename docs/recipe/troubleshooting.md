## Troubleshooting

**The scripts do not stay on the Legion** (the user's decision, 2026-10-05: final product; see
step M of the list). To diagnose or undo, they are used from Common: with `Common` mounted on the
Legion, `sudo sh "<disk>/Backups Linux/fish/void/legion/<script>"` (the Steam ones, in `fish/void/steam/`);
with `Common` on the IdeaPad, copy it from there first: `scp "<disk>/Backups Linux/fish/void/legion/<script>" lego:`
and then `sudo sh ~/<script>` on the Legion (and delete it when done). **With this repository** they are
used from the clone on the Legion (point B of the list): `sudo sh "$B/legion/<script>"` (the common ones,
in `"$B/common/…"`); a script copied alone elsewhere does not find `lib/` (set `VOID_LEGION_REPO=<repo>`
then, `docs/i18n.md`).

Symptom → what it is → what to do. Everything here already happened on this Legion. The detail is in the step
cited, and what applies the same to the IdeaPad, in its recipe's *Troubleshooting*.

### `ssh lego` does not resolve or SSH does not get in

1. **With the dock:** avahi renamed itself to `Legion-Go-Gen-3.local` (it announced over both networks). It is
   prevented by `avahi-wifi-only.sh` (steps 2–3). Meanwhile, by IP:
   `ssh -o HostName=<IP> -o HostKeyAlias=legion-go-gen-2.local lego`.
2. **It does not even answer `ping` until the Legion transmits:** Wi-Fi power saving
   (`iw dev wlp193s0 get power_save` → `on`). Prevented by `wifi-no-powersave.sh` (steps 2–3) and the
   Steam setting ("Habilitar administración de energía para Wi-Fi" / "Enable Wi-Fi Power Management" disabled, step 14).
3. **The Wi-Fi shows as `wlan0` and "unmanaged":** udev skipped the announcement at boot. On the spot,
   `sudo udevadm trigger --action=add --subsystem-match=net`. Prevented by `udev-net` (steps 2–3).
4. **After reinstalling:** the host key changed → on the IdeaPad, `ssh-keygen -R Legion-Go-Gen-2.local`.

### The screen stays off after a mode switch

From another machine: `ssh -t lego sudo sv start lightdm` and `cat /run/switch-mode.log`. It happened with the
version of `restart-lightdm` launched with `setsid` (it died with the session). The current one runs under
runit (`sv once mode-switch`): check `ls -l /var/service/mode-switch` (step 14, "Race with
elogind").

### After a mode switch the screen flickers and the panels look different

It is the race with elogind: it deleted `/run/user/1000` with the new session's `wayland-0` and everything fell back
to X11. On the spot, reboot. Check: `ls /run/user/1000 | grep -c wayland-0` → 2. Permanent
fix: `install-passwordless-switch.sh` (step 14).

### The Legion's screen stays black (no wallpaper) when coming from Game Mode

It is `xfdesktop`'s wallpaper. On the spot, `xfdesktop --reload` or switch workspace. `wallpaper-watcher`
does it by itself: see `~/.local/state/wallpaper-watcher.log` (step 15).

### The external monitor stays black at boot

Seen once. **Without touching the cable**, from the IdeaPad: `ssh lego` and, there,
`sudo sh "$B/legion/diag-monitor.sh"` (leaves `~/diag-monitor.log`; originally the script was copied first
with `scp "<disk>/Backups Linux/fish/void/legion/diag-monitor.sh" lego:` and run as `sudo sh ~/diag-monitor.sh`).
See *Pending*.

### Steam takes ~1 min to enter Game Mode

It is installing the other client: the desktop Steam was opened without `-steamdeck` (for example,
with `steam` from an xterm). Always open it from the menu or with its launcher (step 14, "Why
Steam took…").

### Steam does the full verification on start (`Verifying all executable checksums`)

It closed dirty once. It cleans itself on the next close: nothing to do. If it happens
always, check the three pieces of the clean shutdown: `ls -l /usr/local/bin/xfce4-session
/etc/runit/shutdown.d/05-close-steam.sh` and `steamos-session-select` (step 14).

### Steam sees two controllers, or a `Generic X-Box pad` / Xbox Elite

1. `Failed to hide device` warnings in `/var/log/inputplumber/current`: `acl-progs` or the
   `inputplumber-udevadm` wrapper are missing. Repeat `sudo bash "$B/legion/install-inputplumber.sh"` (step 14).
2. If an Xbox Elite shows up, the own profile is missing (`/etc/inputplumber/devices.d/50-legion_go_2.yaml`).
3. Afterwards, close Steam completely and open it again.

### The gyroscope moves nothing

1. On the desktop, **the thumb has to rest on the right trackpad** (like on the Deck).
2. `inputplumber device 0 capabilities | tr ',' '\n' | grep -iE 'gyro|accel'` has to give
   `Gamepad:Gyro` and `Gamepad:Accelerometer`. Otherwise, the profile carries `blocked: true` again in the
   `imu` sources: repeat the installer.
3. `sh "$B/legion/diag-gyro.sh"` (without root; or copied with `scp`): what reaches Steam when turning (hundreds to ~1500).

Steam's "Probar entradas del dispositivo" ("Test Device Inputs") **does not show the gyroscope**: it is no use for this.

### On the desktop, the trackpad or the right joystick do not move the pointer (but they select text)

`extest` is missing in the running Steam. Check `grep '^N:' /proc/bus/input/devices | grep extest`.
If it does not show: make sure Steam was started with the launcher or the autostart (both carry the `LD_PRELOAD`).
If a Steam update broke it, rebuild (step 14, "Controller on the desktop").
`void-update` warns if the library lacks something.

### The trackpad clicks by itself

The click activator went back to "Pulsación suave" ("Soft Press"). Change it to "Pulsación doble" ("Double Press"), or copy the
backed-up layout (step 14, "Controller on the desktop").

### After reinstalling or restarting InputPlumber, the session does not respond to the keyboard or the mouse

It is labwc (`libseat … Device not taken`). Reboot over SSH (`sudo reboot`, step 14).

### In Game Mode there is no "Rendimiento" (Performance) (TDP, GPU clock), or nothing changes

1. `sudo sv status steamos-manager` → `run`. If it crashes: `tracefs` (its `run` mounts it), and
   `sudo sh "$B/common/steam/steamos-manager/diag-steamos-manager.sh"` launches it in the foreground.
2. `dkms status` → `installed` for the running kernel. If the kernel is from another series, the modules
   do not exist: boot 6.18 (step 14, TDP).
3. `SetManualGpuClock … Invalid argument` / `Error setting manual GPU clock` in
   `/var/log/steamos-manager/current` **with "Reloj de GPU manual" ("Manual GPU Clock") disabled** (hundreds per session;
   harmless, the GPU stays at `auto`): it is the steamos-manager **without the** `set_clocks` **patch** (step
   14, steamos-manager). `sha256sum /usr/lib/steamos-manager` → `cc464424…1586c`; otherwise, repeat
   `install-steamos-manager.sh` (installs the `-2` tarball). **Do not** remove `[gpu_performance]`. If they show up **with the manual
   clock enabled**, or "Reloj de GPU manual" does not appear in Steam: `cat
   /sys/module/amdgpu/parameters/ppfeaturemask` → `0xfff7ffff` (otherwise, `sudo sh "$B/legion/gpu-overdrive.sh"` and
   reboot) and `grep -c '^\[gpu_performance\]' /usr/share/steamos-manager/devices/legion-go-series.toml`
   → `1` (otherwise, repeat `install-steamos-manager.sh`).

### `void-update` ends with AVISO (WARNING)

Each line says what to do (what each one checks: IdeaPad recipe, step 6, `void-update`). To
see it again without updating or `sudo`: **`void-update --summary`** (summary) (2026-10-08; since 2026-10-14 it fits half a terminal: one short line per check, the detail only under the warnings; `-v` for the detail of all). The Legion's ones:

- **TDP** that does not build for the new kernel (the error, in `/var/lib/dkms/lenovo-wmi-tdp/*/build/make.log`;
  the hidden GRUB boots that kernel without fine TDP: for the previous one, `grub-hidden.sh --remove`, step 8),
  kernel not held or new series recommended by Void: step 14, TDP, "Updates". gamescope's `cap_sys_nice`:
  `sudo setcap cap_sys_nice=eip /usr/bin/gamescope` (`void-update` puts it back by itself).
- **Patched gamescope or `xdg-desktop-portal-wlr`.** Already **before confirming** the update,
  `void-update` warns if the list replaces them ("Void reemplazará … parcheado (a → b)" / "Void will replace … patched (a → b)"): to keep them,
  answer `n` and `sudo xbps-pkgdb -m hold <package>` (without Void's fixes). In the summary, an
  AVISO (WARNING) if the installed one is already Void's (**without the patch**), if Void has **the same** version and revision
  as ours (xbps does not install it, but it is a newer Void build: rebuild to have its
  changes with the patch) or a **newer** one (the next update replaces it). Rebuild: gamescope →
  `bash "$B/common/steam/gamescope-patch/build-gamescope.sh"`, install and `setcap`
  (step 14, "Screen sharing in Game Mode"); wlroots portal → `bash "$B/legion/portal-wlr-patch/build-portal-wlr.sh"`, install and restart the portal (step 14,
  "Portals", point 4). If `~/src/void-packages` already exists, delete it first: the scripts do not update it.
  **Since 2026-10-09 each line also says the result of testing the patch** against Void's code
  (also `xfdesktop` and `Thunar`, step 15): "el parche sigue haciendo falta" ("the patch is still needed") (rebuild when due),
  "Void ya lo trae: se puede volver al de Void con …" ("Void already has it: you can go back to Void's with …") (NOTA (NOTE), with the exact command), "el parche no se puede
  usar tal cual" ("the patch cannot be used as is") (AVISO (WARNING): upstream rewrote that part, review the patch by hand) or "sin comprobar" ("not checked") (no
  network). Before confirming, the same. If the test is not installed: `bash "$B/common/patch-test/install-patch-test.sh"` (without root; IdeaPad recipe, step 6).
- **InputPlumber or gamescope's portal** missing some library (`ldd`): install it or bring another version
  and repeat `install-inputplumber.sh` / `install-portal-gamescope.sh` (step 14).
- **`steamos-manager`**: missing some library → rebuild (`build-steamos-manager.sh`, step 14,
  steamos-manager; its build dependencies are kept on purpose) and install; "NO es el de
  referencia" ("is NOT the reference one") → repeat `install-steamos-manager.sh`; "sin sha256 de referencia" ("no reference sha256") → repeat
  `install-steamos-manager.sh` (since 2026-10-08 it writes `/usr/local/share/steamos-manager-void/sha256`);
  "para recompilarlo falta" ("to rebuild it, missing") → the command it gives. The line starts with the **installed package** (file
  `package` of that folder, written by the installer; `paquete` on an older installation); it is not an AVISO by itself: "paquete desconocido" ("unknown package") =
  installed before 2026-10-08 (repeat the installer to register it); "el oficial, SIN el parche de
  set_clocks" ("the official one, WITHOUT the set_clocks patch") = `…-void` (valid option, to go back; with it the `Error setting manual GPU
  clock` come back, *Troubleshooting* point 3).
- **`extest`**: missing some library → rebuild (step 14, "Controller on the desktop"); "para recompilarlo
  falta" → whatever it says (`~/.cargo`, target `i686`, `~/src/extest`, `gcc-multilib`).

### Screen sharing on the desktop: nothing shows up, it asks twice or Vesktop does not respond

1. **When pressing share, the chooser does not show up:** `cat ~/.config/xdg-desktop-portal-wlr/config` (it must
   point to `screen-share`) and `tail ~/.cache/screen-share.log`. If the log has
   nothing new, Vesktop did not reach the portal. First, is there a chooser open? (`pgrep -af
   'screen-share$'`; the portal does not attend another request meanwhile): it should be seen in front because of
   the labwc rule (`grep -c screen-share ~/.config/xfce4/labwc/rc.xml` → 1). If there is none:
   **quit Vesktop from the tray and open it** (canceling in the chooser leaves it unable to share).
   Repeat `screen-share/install.sh`.
2. **It asks two (or three) times:** the portal does not have the variable: `tr '\0' '\n' <
   /proc/$(pgrep -n -f '^/usr/libexec/xdg-desktop-portal-wlr')/environ | grep XDPW` must give
   `XDPW_PERSIST_MODE=permanent` (the user's D-Bus service that `install.sh` sets). With windows,
   also, the patched portal: `xbps-query -p pkgver,repository xdg-desktop-portal-wlr` → `0.8.4_2` and
   `hostdir/binpkgs`. If everything is there and it goes on: reboot (the first time it was needed). To see what happens:
   the portal with `-l DEBUG` (step 14, "Portals", point 4): if the repeated request arrives without
   `restore data available`, it is a new stream for the portal.
3. **You choose a window and the Vesktop window does not appear** (or the previous stream continues): that
   window is not giving an image (it happened with Steam and with Thunar on another workspace): go see it for a moment
   and come back.
4. **The chooser shows up by itself when entering the desktop:** it is Steam; the rule `"steam":
   "pantalla"` must resolve it (in the log, `steam: regla 'pantalla'`). If it says another program, adjust `REGLAS`.

Detail in step 14, "Desktop portals and screen sharing".

### Screen sharing in Game Mode: black, or gamescope crashes and goes back to the desktop

1. **Black or no stream:** check that gamescope's portal is there: `grep "portal de gamescope"
   ~/.local/state/steam-game-mode.log` and `cat ~/.local/state/portal-gamescope.log` ("started"). If it
   crashed on entering, leave and come back to Game Mode (the main portal only looks for it on start). And
   Vesktop's launch options with `--env=XDG_SESSION_TYPE=wayland` (step 14).
2. **gamescope crashes** (back to Xfce; `Segmentation fault` in `steam-game-mode.log`, after `out of
   buffers`): is the patched gamescope still there? `xbps-query -p pkgver,repository gamescope` →
   `3.16.30_2` and `hostdir/binpkgs` (`void-update` warns). Otherwise, rebuild (`build-gamescope.sh`,
   install and `setcap`). If with the patch it crashes again: `diag-gamescope-pipewire.sh` (with `gdb` and
   `gamescope-dbg`) and look at the trace.
3. **Only Steam's menu is heard:** audio source "Todo el sistema" ("Entire system") in the stream's configuration
   window.

### Remote Play in Game Mode: the guest only sees the waiting screen

In `~/.local/share/Steam/logs/streaming_log.txt`: `Failed to create PipeWire main loop` → missing
`pipewire-32bit`; `Could not connect receiving stream` → missing `libspa-videoconvert-32bit`; `Capture
method set to Desktop Placeholder` continuously (not only with Steam's menu open) → one of
the two. Fine: `Desktop PipeWire NV12 DMABUF + VAAPI H264`. Step 14, "Remote Play in Game Mode".

### The screen's brightness changes when coming back from hibernation or suspend

See `/run/brightness-on-wake.log` and that `/etc/elogind/system-sleep/brightness` exists (step 14,
"Hibernation and brightness on wake").

### Steam's on-screen keyboard comes out huge or with a border

The `type="utility"` exception is missing in `~/.config/xfce4/labwc/rc.xml` (step 15).

### After closing Steam's on-screen keyboard, the trackpad and the sticks do not move the pointer

Seen on the desktop on 2026-10-09 (15:35 and 15:37, shortly after starting Steam); **intermittent**: in
two tests that day it did not reproduce. Cause seen in `~/.local/share/Steam/logs/controller_ui.txt`:
when opening the keyboard Steam records `Set OSK active 1` and switches the controller to the keyboard's action set
(`basicui_neptune.vdf`, where trackpad and sticks handle the keyboard); when closing it, it **did not record**
`Set OSK active 0` (it went back to the desktop layout, `413080`, 6 min later). `extest`,
InputPlumber and labwc, fine (the external mouse works; the `extest fake device` was still there). Why Steam
does not notice the close: **not found out**. Try recovering it by opening and closing the
keyboard again (RT+X). If it repeats, capture (read-only, event-driven, no idle cost):

```bash
cp "$B/legion/diag-steam-keyboard.sh" /tmp/ && bash /tmp/diag-steam-keyboard.sh
bash /tmp/diag-steam-keyboard.sh --stop       # results in /tmp/diag-steam-keyboard/
grep -E 'OSK active|OnFocusWindowChanged' /tmp/diag-steam-keyboard/controller_ui.txt
```

### Bluetooth headphones "connect" and drop (`br-connection-create-socket`)

They only keep the last pairing properly: pair them again here (steps 5–12).

### Steam's FPS limit gives half (30 → 15)

Without VRR, the screen modes that gamescope fabricates (everything that is not 144 Hz) lose one of every
two refreshes. Enable **"Habilitar VRR"** ("Enable VRR") in Rendimiento (Performance), or use limits that divide 144 (36, 48,
72). See step 14, "SteamOS settings".

### A game looks bad or runs worse since the SteamOS settings

The first suspect is gamescope's Vulkan layer (`ENABLE_GAMESCOPE_WSI=1`, Game
Mode). For that game, in its Steam launch options: `DISABLE_GAMESCOPE_WSI=1 %command%`
(it disables it only there). If it is the whole system: `sudo bash "$B/legion/like-steamos.sh" --remove` and
reboot (step 14, "SteamOS settings").

### The fallback kernel or the Windows on the XS1000 is needed

With the hidden GRUB there is no menu. The Windows on the XS1000 is chosen in the firmware's boot menu.
The fallback kernel: `sudo sh "$B/legion/grub-hidden.sh" --remove` (or, if it does not boot, from a live).
See step 8.

### The microSD games show as not installed

`findmnt /mnt/microsd`: if it is not mounted, is the card in? Mount it: `sudo mount
/mnt/microsd`, and close and open Steam. Check that Steam has it with that path: `grep '"path"'
~/.local/share/Steam/config/libraryfolders.vdf`; in `logs/content_log.txt`, `Mounted library
folder "/mnt/microsd"`. If it came out in another path, repeat `microsd-at-boot.sh` with Steam closed
(step 14, "microSD").

### In Xfce Wayland, choosing a wallpaper does nothing

The dialog writes to `monitorUnknown` and `xfdesktop` reads `monitor<connector>` (`eDP-1`, `DP-1`): step 15,
*Desktop wallpaper on Wayland*. Fix: the patched xfdesktop (or Void's, if `void-update` says it already has it). On the spot,
without root: `xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor<connector>/workspace0/last-image -n -t
string -s <image>` (without `-n -t string` if the key already exists).

### In Xfce Wayland, Thunar's "Establecer como fondo de pantalla" ("Set as wallpaper") does nothing

Thunar writes to `monitorUnknown` (step 15, *Wallpaper from Thunar on Wayland*). Fix: the patched
Thunar and `thunar -q`. If it stays the same: `xbps-query -p pkgver Thunar` (did an update replace it?
`void-update --summary`) and that no old Thunar is left open (`pgrep -a thunar`).

### `Common` does not mount (`wrong fs type…`, `volume is dirty`)

It was left dirty. The same as on the IdeaPad (its *Troubleshooting*): read it with
`udisksctl mount -b /dev/sda4 -o ro`; fix with the disk unmounted: `sudo ntfsfix -d /dev/sda4`,
and `chkdsk D: /f` in its Windows. Unmount it before rebooting, hibernating or booting that Windows.

### Known noise in the logs (harmless)

Reviewed on 2026-10-08; everything **is left as is** on purpose (decided with the user). Message → cause →
why it is not touched.

- **`SetWifiBackend … Wi-Fi backend not found in config`** (`/var/log/steamos-manager/current`, every time
  Steam starts) → steamos-manager looks for `wifi.backend=` in
  `/etc/NetworkManager/conf.d/99-valve-wifi-backend.conf`, which does not exist here, and Steam asks it for iwd
  (`Set wifi force wpa supplicant: 0`). **Do not create that file to silence it:** steamos-manager would see
  that it does not match what Steam asks, it would try to switch to iwd (here there is no iwd: it runs with
  `wpa_supplicant`) and after rebooting the Wi-Fi would not work. The error is what protects the network. The
  warnings from `org.freedesktop.systemd1`, the same: there is no systemd here.
- **`task … panicked with message "all branches are disabled and there is no else branch"`**
  (steamos-manager, when powering off or rebooting) → it falls in the same second as InputPlumber's `SIGTERM`:
  steamos-manager loses its connection with it when shutting down. It only happens at shutdown; if InputPlumber
  restarted with the session open, runit brings steamos-manager up by itself.
- **`Can't query initial InputPlumber devices: … ServiceUnknown`** (steamos-manager, on start) →
  it starts before InputPlumber is on D-Bus; the controller works anyway (`deck-uhid`). Waiting for it
  event-driven in the `run` would be one more own piece to remove a warning.
- **SteamOS pieces that are not here** (Steam's logs): `steamos-select-branch: not found`,
  `timedatectl: not found` (`console-linux.txt`), `telemetry`, `atomupd proxy`,
  `steamos-mandatory-update` / `jupiter-initial-firmware-update` (127), `invalid screen reader locale:
  auto` (`steamui_steamos.txt`), and `xfce4-notifyd` "cannot open display" when entering Game Mode
  (Steam uses its own notifications). Empty substitutes would be own pieces with nothing gained.
  **`invalid profile: balanced`** and `SteamOSManager: daemon not present` show **only on the desktop**:
  the steamos-manager user process is only started by the Game Mode launcher, on purpose (on
  the desktop Steam does not touch profile or TDP).
- **`ld.so: object '…/libextest.so' from LD_PRELOAD cannot be preloaded (wrong ELF class: ELFCLASS32)`**
  (`~/.xsession-errors`) → `extest`'s library is 32-bit and the 64-bit processes also try to load it
  (step 14, "Controller on the desktop"). It costs nothing.
- **`[libseat] … Could not close device: Unknown object '/org/freedesktop/login1/session/cN'`** and
  `Failed to close device` (labwc in `~/.xsession-errors.old`, and gamescope, when closing the session) → the
  elogind session no longer exists when the compositor releases its devices; the kernel frees them when
  the process exits. Do not confuse with `Device not taken` when restarting InputPlumber (above).
- **`[MANGOHUD] … Unknown option 'nis_steam_sharpness'`** (`steam-game-mode.log`, once per entry
  into Game Mode) → Void's `mangoapp` 0.8.4 does not know that option (it does know `fsr_steam_sharpness`). The only
  thing lost is that the overlay shows NIS sharpness. It fixes itself when Void updates MangoHud.
- **Steam's adaptive brightness** (`== …: brightness N (amdgpu_bl0)` in `steam-game-mode.log`: about 170 in
  the first minute and then ~5/min; in `console_log.txt`, `steamos-priv-write failed
  …/brightness` and `failed to make file writeable`) → Steam first tries SteamOS's helper
  (`/usr/bin/steamos-polkit-helpers/steamos-priv-write`, which does not exist here) and `chmod`, and then `echo N |
  sudo -n tee`, which Game Mode's `sudo` turns into elogind's `SetBrightness` (step 14). It costs very
  little.
- **`xfce4-pulseaudio-plugin-WARNING … pa_context_connect() failed: Access denied`** (once or twice when
  the desktop session starts) → race with `pipewire-pulse`, which is not ready yet; the plugin
  retries every 5 s and connects. The same on the IdeaPad.
- **WirePlumber: `optional component 'support.logind' … failed to load`** and `skipping component
  'monitor.bluez.seat-monitoring'` (every session) → `wireplumber-elogind` is missing; the component is optional
  and Bluetooth works. **Do not install `wireplumber-elogind`:** it would make WirePlumber release
  Bluetooth when the seat is not active, and with lightdm's session switches (Game Mode ↔
  desktop) it could cut the headphones. The same on the IdeaPad.

