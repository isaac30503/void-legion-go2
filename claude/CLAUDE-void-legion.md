# Context of this machine and of the network

Written on 2026-10-03. This machine is the **Legion Go 2** (`lego`). The network's **debugging station**
is the IdeaPad (`ssh ideapad`): its context is in `Backups Linux/CLAUDE-void-ideapad.md` (external disk)
and its recipe, `void-ideapad-100.md`, is the base of the one here.

> **This repository** (English version of this file; installed as `~/Work/CLAUDE.md`, recipe step 7). The
> documentation and the pieces that lived in `Backups Linux` on the external disk are in the repository
> `void-legion-go2`, cloned on this machine at **`<repo>`** (normally `~/src/void-legion-go2`; recipe,
> point B), with `build/` = the clone with the real values of `local.env` filled in. Paths below are the
> repository's; the old Spanish names (`fish/void/legion/`, `pasos-1-a-3.sh`, `cambiar-modo-root`…) are in
> `<repo>/docs/glossary.md`. Scripts' messages follow the system's language; the logs that programs read are
> in English.

## This machine

Lenovo **Legion Go 2** (83N0, Ryzen Z2 Extreme, Radeon 890M, 32 GB), **Void Linux** (glibc,
x86_64, rolling) with **Xfce**, installed on 2026-10-03 **wiping SteamOS**. The normal desktop is
**Xfce on Wayland (labwc)**; Xfce X11 stays as a backup; on power-on it enters the last mode used
(Game Mode or desktop). User
`isaac` (in `wheel`), hostname `Legion-Go-Gen-2` (`Legion-Go-Gen-2.local` over mDNS).
**Recipe: `<repo>/docs/void-legion-go2.md`** (the index; one file per step in `<repo>/docs/recipe/`, `step-NN-….md`, since 2026-10-14) (originally `Backups Linux/void-legion-go2.md`), which copies the
IdeaPad's and only explains what changes; own pieces in `<repo>/legion/` (originally `fish/void/legion/`).
**Ordered for reinstalling** (2026-10-05): it starts with the full list in order (also what is done by hand in
Steam), it has *Troubleshooting* (symptom → what to do) and the step numbers are the IdeaPad's.

**The login shell is `/bin/bash`, and it jumps to fish** from `~/.bashrc.d/99-exec-fish.sh`, as on
all the machines of the network. **Do not set fish with `chsh`.**

- **Void is not atomic** and the init is **runit**: `sudo ln -s /etc/sv/<svc> /var/service/`;
  `sudo sv status|restart <svc>` (without root, `sv status` gives "access denied"). Software with `xbps`
  (`install-pkg`, `remove-pkg`, the same fish functions as the IdeaPad, and **`void-update`** —since 2026-10-11, it replaced
  `update-system`: a bash command like CachyOS's cachy-update, with a panel icon that checks without root on network
  connect and every 6 h, notifications, Void's news, services with old code; `common/void-update/`, recipe step 5–12—; and since
  2026-10-05 `audio-ctrl` and `audio-priority`, adapted to Void: `pw-dump` with `python3`, WirePlumber is
  restarted without systemd —the one PipeWire starts inherits `SIGTERM` blocked, so after 3 s `SIGKILL`
  goes—; `audio-priority` in a terminal of the session, not over SSH). The order chosen here
  (`~/.config/wireplumber/wireplumber.conf.d/51-audio-priority.conf`) has a copy in
  `<repo>/legion/wireplumber/` (recipe, point K.12): after changing it, copy it again (with its MAC and
  serial number as `@NAME@`: docs/sanitization.md).
- **Active runit services** (2026-10-04): NetworkManager, lightdm, dbus, polkitd, chronyd,
  udevd, sshd, avahi-daemon, bluetoothd, decky, **inputplumber**, **steamos-manager**, **udev-net** (`udev-red`
  before this repository), **earlyoom** (2026-10-05), `mode-switch` (`cambio-modo` before; with `down`: only
  with `sv once`) and agetty-tty1…6. `sv status` asks for root.
  **`rtkit` is not in runit** (since 2026-10-08): D-Bus starts it on demand
  (`org.freedesktop.RealtimeKit1.service`); with both they clashed (see below, agent).
- **Focus without raising** (2026-10-06, the same on the IdeaPad): it follows the mouse, but raises only with a click
  (`<raiseOnFocus>no` in the common `rc.xml`, `raise_on_focus` false in xfwm4). Exception: the screen-share
  chooser, **always on top** (rule `identifier="screen-share"` → `ToggleAlwaysOnTop`,
  2026-10-07; `compartir-pantalla` before): behind Vesktop, the portal stayed waiting for it and did not
  attend another request.
- **Sharing a window that is not visible** (another workspace; it always happened with Steam, once with Thunar):
  sometimes it gives no image and Vesktop does not open its settings window until it is visible: go look at it for a
  moment and come back (fixed note in the chooser; there is no reliable signal to detect it). Canceling in the chooser leaves Vesktop unable to share until
  it is restarted (Vesktop/Electron bug). "Who is asking": the patched portal (`0003`) passes the chooser
  the exact request (`XDPW_REQUEST_HANDLE`); before, a hung one from Firefox also showed up. The chooser goes
  without bar or buttons (labwc rule), with rounded corners.
- **`<xwaylandPersistence>yes`** in labwc's `rc.xml` (common, 2026-10-06): Xwayland does not shut down without
  X programs (on the IdeaPad, xterm lost its theme); here Steam in the background kept it alive.
- **Flatpak** (since 2026-10-05): store **GNOME Software** (xbps), Flathub `--user`, **Vesktop**
  (Discord; also in Steam, with its logo recolored in Discord blue on a background of Discord grays with a blue halo and faint bubbles, made by
  `<repo>/common/steam/art-vesktop/generate.py` (`arte-vesktop/generar.py` before); the original pink art, in
  `~/.cache/art-vesktop-previous/` (`~/.cache/arte-vesktop-anterior/` if it was made before this repository)).
  The same script puts that icon in Xfce: `~/.local/share/applications/dev.vencord.Vesktop.desktop` (copy
  of the Flatpak's launcher with `Icon=~/.local/share/icons/vesktop-discord.svg`; Papirus brings its own
  Vesktop icon and it won) and in the tray (Vesktop draws it: `~/.var/app/dev.vencord.Vesktop/config/
  vesktop/userAssets/tray` and `trayUnread`, its PNGs with the pink changed). After updating Vesktop, if
  its launcher changes, run it again.
  `void-update` does `flatpak update`. New apps show up in the menu with a new session.
  **Portals** (2026-10-06): `xdg-desktop-portal`, `-gtk` and `-wlr` (Void brings `xfce-portals.conf`:
  screen sharing through `wlr`). Screen sharing uses an **own chooser with previews**
  (`~/.local/bin/screen-share`, from `<repo>/legion/screen-share/`, with `grim`; configured in
  `~/.config/xdg-desktop-portal-wlr/config`; `fuzzel` as a backup). Vesktop asks to choose twice (preview
  + stream, sometimes three, on purpose in Chromium): the portal's token solves it
  (`XDPW_PERSIST_MODE=permanent` in `~/.local/share/dbus-1/services/…desktop.wlr.service`; xdpw without the
  variable never gives it), and for windows **`xdg-desktop-portal-wlr` 0.8.4_2 with three own patches**
  (`legion/portal-wlr-patch/`: 0001, `restore_data` with `toplevel_identifier`, out of the box only screens;
  0002, when switching streams it reuses the source of a restored session that Vesktop closed without
  starting, because the token is single-use and the next request arrived without it; 0003, passes the
  chooser `XDPW_REQUEST_HANDLE`/`XDPW_APP_ID`). No
  memory and no timings in the chooser (the user's decision: nothing that depends on timings). `void-update`
  warns if Void replaces the portal → `build-portal-wlr.sh`, install and restart. The desktop Steam (`-pipewire`)
  asks for the screen when starting and does not keep the token: the chooser knows who is asking (pending request in
  D-Bus → PID → `/proc/PID/comm`) and with `RULES = {"steam": "screen"}` grants it without a dialog (Steam
  only takes the permission and closes the capture: no cost; do not remove `-pipewire` nor reject it: the
  user's decision, "no mutilar" ("do not mutilate")). In Game Mode, **out of the box**, Vesktop would use its X11 chooser (black
  full screen; Vulkan games black unless `ENABLE_GAMESCOPE_WSI=0 %command%`): that is why it goes through the
  gamescope portal, below.
  **Game Mode like SteamOS (2026-10-07):** its `xdg-desktop-portal-gamescope` (Valve's, in
  `/usr/local`, `<repo>/common/steam/portal-gamescope/`; full screen only) with a wrapper that gives it its own
  journal socket in `bwrap` (without it, it crashes: Void has no systemd); the Game Mode launcher activates it
  (`XDG_DESKTOP_PORTAL_DIR`). Vesktop uses it with `--env=XDG_SESSION_TYPE=wayland
  --env=WAYLAND_DISPLAY=gamescope-0 … --ozone-platform=x11` in its shortcut: it streams the screen with
  the game (audio: "Todo el sistema" ("Entire system")). A single shortcut, like that (the user's decision; the
  out-of-the-box one forced `ENABLE_GAMESCOPE_WSI=0` per game). Verified with Borderlands 3 and changing settings, and again
  on 2026-10-07 after the wlroots portal's patches (they do not affect it). **gamescope 3.16.30_2 with an own patch**
  (`<repo>/common/steam/gamescope-patch/`: race
  `request_buffer`/`remove_buffer` in `src/pipewire.cpp`, which brought gamescope down when starting/reconfiguring
  a stream); `void-update` warns if Void replaces it → `build-gamescope.sh` + `setcap`. Restarting the wlroots
  portal cuts an ongoing stream.
- **Remote Play in Game Mode** (2026-10-07): Steam's client is 32-bit and needs
  `pipewire-32bit` and `libspa-videoconvert-32bit` to capture gamescope's PipeWire node (without them,
  the guest sees the waiting screen: `Failed to create PipeWire main loop` / `Could not connect
  receiving stream` in `streaming_log.txt`), and `mesa-vaapi`(`-32bit`) to encode in hardware. Fine:
  `Capture method set to Desktop PipeWire NV12 DMABUF + VAAPI H264`. `install-steam.sh` includes them.
- **Firefox in Game Mode** (2026-10-05): Steam shortcut with Target
  `~/.local/bin/firefox-steam` (`MOZ_GTK_TITLEBAR_DECORATION=system` + `xdotool windowsize 100% 100%`):
  without frame or resize borders, at gamescope's screen size. Without it, Firefox draws its frame (because of the
  "Barra de título" ("Title Bar") unchecked for labwc) and in gamescope nobody can maximize it.
- **`mantenedor-void` agent** (2026-10-07, `~/Work/.claude/agents/`; called `void-maintainer` in this repository,
  `<repo>/claude/agents/void-maintainer.md`; originally a copy in `Backups Linux/claude-agentes/`,
  the same on the IdeaPad): audits (`<repo>/common/agent/audit-void.sh`), proposes and maintains the recipes. Its
  first audit found here **`rtkit` relaunched by runit every second** (D-Bus had already started
  another one when entering Game Mode directly). **Fixed on 2026-10-08** (approved by the user, on both
  machines): `rtkit` out of runit, only D-Bus starts it; `like-steamos.sh` no longer links it and removes the
  old link (`sudo sh /tmp/quitar-rtkit-runit.sh` on those already installed). **Verified after rebooting
  on 2026-10-08** on both: a single `rtkit-daemon`, child of `runit` (not `runsv rtkit`), and PipeWire in
  RR 20 (recipe, *Watch* and *Verification*).
- **No scripts in `~` (final product, 2026-10-05):** the installers and diagnostics are only in Common
  (`fish/void/legion/`, `fish/void/steam/`); installation logs in `legion/registros-legion/`.
  To use one: run it from Common or copy it with `scp` and delete it when done.
  **With this repository:** they are in the clone (`<repo>/legion/`, `<repo>/common/`) and are run from
  `<repo>/build/` (`sudo sh <repo>/build/legion/<script>`): a script copied alone elsewhere does not find
  `lib/`. The logs are archived in `<repo>/logs/legion/`.
- **What needs root is run by the user here** (`sudo` asks for a password): a script is left for them in
  `~` and they launch it with `sudo bash ~/script.sh`, which leaves its log in `~/<script>.log`; **when done they are
  deleted from `~`** (final product, 2026-10-05: the scripts live in Common; the logs, in
  `fish/void/legion/registros-legion/`). Below, `~/x.sh` = the script from `fish/void/legion/` copied like that.
  **With this repository:** a one-off script is written to `/tmp` (outside the clone, so it must not depend on
  `lib/`) or the user runs the repository's own from `<repo>/build/`; below, `~/x.sh` = that script of
  `<repo>/legion/`.
- **After updating OpenSSH `sshd` has to be restarted** (new connections drop with
  "Connection reset by peer"). **The `.new-*` of `/etc` are not applied.**
- Disk: `nvme0n1` with EFI 500M · **swap 32G** · `/` btrfs (`/home` is a folder). microSD
  `mmcblk0p1` (953 GB, ext4, from the SteamOS days): its **Steam library** (44 apps) and emulator
  games; **always mounted at boot on `/mnt/microsd`** (`fstab` with `nofail`,
  `~/microsd-at-boot.sh` (`microsd-al-arrancar.sh` before), 2026-10-05; recipe step 14, "microSD").
- **avahi announces only over the Wi-Fi** (`allow-interfaces=wlp193s0`; `~/avahi-wifi-only.sh`): with the
  dock, over the two networks it renamed itself to `Legion-Go-Gen-3.local`.
- **Wi-Fi without power saving** (`wifi.powersave = 2` in `/etc/NetworkManager/conf.d/`,
  `~/wifi-no-powersave.sh`): with it, the sleeping radio did not answer and SSH did not get in in either
  direction. Backend: **wpa_supplicant** (not iwd: here there are no continuous scans).
- **US international keyboard** (`us` + `intl` on X, `us-acentos` on the console), not `latam`.
- **Void's 6.18 kernel** (without Valve's patches). Working: screen (1920×1200, comes out upright),
  Wi-Fi MT7922, controllers (`xpad`), gyroscope (`amd_sfh`), speakers, battery, Bluetooth and
  `platform_profile`. `hid_lenovo_go` (Valve's patch, not there) is not needed for the buttons;
  without it the gyroscope of each controller is not activated (tested on 2026-10-05: left like that; see below).
- **Fine TDP** (2026-10-04, recipe step 14, `tdp/install-tdp.sh`): `lenovo-wmi-gamezone`/`-other`
  (+ helpers, events, capdata01) are in the normal 6.18 but Void does not enable them; they go through **DKMS**
  (`lenovo-wmi-tdp/6.18.55`, only 6.18 kernels). Profile `custom` and
  `/sys/class/firmware-attributes/lenovo-wmi-other-0` (`ppt_pl1_spl` 5–35, `ppt_pl2_sppt` 5–37,
  `ppt_pl3_fppt` 5–45 W). With a 6.19 kernel they do not build: that is why
  `linux` and `linux-headers` are **held** (6.18 is LTS; `xbps-query -H`). `void-update` ends with a **summary
  OK/REPAIRED/WARNING** (OK/REPARADO/AVISO in Spanish) (TDP for the new kernel, hold, gamescope and its PipeWire
  patch, the `xdg-desktop-portal-wlr` patch, libraries of InputPlumber, `steamos-manager` and `extest`). **Since
  2026-10-08:** it warns **before confirming** if the update replaces the patched gamescope or wlroots portal
  (any package from a local repository), compares each one with Void's (same revision
  = WARNING: it is a newer Void build that xbps does not install), `ldd` of the gamescope portal, and
  `steamos-manager` (`ldd`, reference sha256, build dependencies) and `extest` (`ldd` and what is
  needed to rebuild it). **`void-update --summary`**: only the summary, without syncing or `sudo`.
  **Testing own patches (2026-10-09):** `void-update` no longer assumes from the version whether an own
  patch is still needed: it **tests** it against the code of Void's template (or of the latest
  upstream tag, for steamos-manager) with `~/.local/bin/patch-still-needed`
  (`<repo>/common/patch-test/patch-still-needed.sh`; patches in `~/.local/share/void-update/patches/`, put there by
  `install-patch-test.sh`, without root; cache in `~/.cache/void-update/patches/`; before this repository:
  `parche-sigue-haciendo-falta`, `…/parches/`): STILL_NEEDED /
  ALREADY_INCLUDED (NOTE with `sudo xbps-install -Sf <package>` to go back to Void's) / PARTIAL / CONFLICT
  (review the patch) / UNCHECKED (without network) (HACE_FALTA / YA_INCLUIDO / PARCIAL / CONFLICTO / SIN_COMPROBAR
  before). It runs only if Void's version differs from the installed one
  or if what is installed is already Void's; also before confirming. The `build-*.sh` use it before
  building. Pieces: `xfdesktop`, Thunar, gamescope, `xdg-desktop-portal-wlr`, steamos-manager (not:
  InputPlumber, `extest`, TDP through DKMS, gamescope portal, without own patch). Removed the assumptions
  "xfdesktop >= 4.20.3" and "ldd of Thunar". Detail: IdeaPad recipe, step 6, *Prueba de parches propios*
  (*Testing own patches*); here, history of 2026-10-09.
  Here, with the test: 14 × OK (34.6 s the first time, 3.1 s afterwards).
  The steamos-manager reference (`sha256` and `package`, `paquete` before, in `/usr/local/share/steamos-manager-void/`) is
  written by **`install-steamos-manager.sh`** on every installation (since 2026-10-08); the summary line
  shows the package (`…-void-2` = patched; `…-void` = the official one, without the `set_clocks` patch, as a
  note; without the file, "unknown package", a note). Pending root: record the `package` of the
  installed one (recipe, *Pending → To do*).
- **steamos-manager** (2026-10-04, recipe step 14): runit service `steamos-manager` (root;
  **mounts `tracefs`**, without it, it crashes) + the user one, which the Game Mode launcher starts.
  Performance in Steam: profiles (the power button's LED changes color), TDP and manual GPU
  clock (**overdrive**: `/etc/modprobe.d/amdgpu-overdrive.conf`, `gpu-overdrive.sh`; the
  GPU only accepts a fixed clock in `manual` mode). **With the manual clock disabled, the official
  steamos-manager fills its log with `Error setting manual GPU clock: Invalid argument`** (harmless: Steam
  resends the saved clock, steamos-manager writes it even if the level is at `auto` and SMU 14
  rejects it; on the Deck it does not happen because its APU, Van Gogh, accepts it at any level). **Since
  2026-10-08 it goes with an own patch** (`0001-gpu-set_clocks-only-in-manual.patch`, `…-solo-en-manual.patch`
  before: `set_clocks` only writes with the level at `manual`), built here without root with `build-steamos-manager.sh` and
  packaged in `steamos-manager-v26.4.1-void-2.tar.gz` (`<repo>/common/steam/steamos-manager/`, a Release asset; the
  official one stays to go back); binary with sha256 `cc464424…1586c`. It was installed with `sudo sh
  /tmp/instalar-steamos-manager-parche.sh`; **verified on 2026-10-08** (clock at 2000 MHz in `manual` and
  back to `auto`; no new error with the clock disabled). `speech-dispatcher` (gives `libspeechd`,
  which steamos-manager needs) goes **marked manual** (`sudo xbps-pkgdb -m manual speech-dispatcher`;
  recommended, to do on 2026-10-08): otherwise, only `orca` and `speech-dispatcher-devel` hold it.
  **steamos-manager's build dependencies are kept on purpose** (the user's decision,
  2026-10-08; ≈ 470 MB): do not propose removing them.
  **Do not remove the manual clock to hide those errors**. On 2026-10-08 the clock and overdrive were removed
  by a misunderstanding (it was believed it was no use here; it was: 2900 MHz in `manual`, 2026-10-04) and they were
  given back the same day (`/tmp/legion-gpu-manual.sh`); **verified after rebooting** (2026-10-08).
  **Do not create `99-valve-wifi-backend.conf`** to silence `SetWifiBackend` (steamos-manager would try to
  switch to iwd and would break the Wi-Fi; recipe, Troubleshooting, *Known noise in the logs*). **No GPU power
  profile**: the normal amdgpu does not give `pp_power_profile_mode` on this GPU, **nor does Valve's** (checked in the source of
  SteamOS's `6.18.50-valve2`: it did not exist on SteamOS either). **Steam turns on the Wi-Fi's power
  saving** unless in Game Mode Ajustes → Desarrollador →
  "Habilitar administración de energía para Wi-Fi" (Settings → Developer → "Enable Wi-Fi Power Management")
  is turned off (done; the page shows up with Sistema → "Activar modo desarrollador" (System → "Enable Developer
  Mode")). `SetWifiBackend … not found in config` in its log: harmless.
- **`udev-net`** (`udev-red` before; 2026-10-04, recipe steps 2–3; **it already acted** twice, the last one on 2026-10-07): if the Wi-Fi shows up as `wlan0` "unmanaged", udev
  lost its event at boot (gap between the stage-1 udevd and the `udevd` service). The
  service repeats it by itself; by hand: `sudo udevadm trigger --action=add --subsystem-match=net`.
- **InputPlumber** 0.81 (2026-10-04, recipe step 14, `install-inputplumber.sh`): official binary
  (it only asks for `libiio`), runit service `inputplumber`, log in
  `/var/log/inputplumber/current`. Own profile `/etc/inputplumber/devices.d/50-legion_go_2.yaml`
  with **`deck-uhid`** (the package's one emulates an Xbox Elite): Steam sees a Valve controller
  (`28DE:12FB` "Legion Go 2 Controller", as on SteamOS), with back buttons, touchpad and the body's
  gyroscope (= **the tablet**, the part with the screen: it is the only one that reaches Steam; with the controllers
  detached, moving them does nothing) (this one, since 2026-10-04: the own profile removes the `blocked: true` of the `imu`
  sources and puts a ×100/×10 `mount_matrix` because `amd_sfh` declares a scale 100 times smaller; in
  Steam it acts with the thumb on the right trackpad). Without it, on the desktop the controller controls nothing. **It hides the originals** thanks to a
  `udevadm` wrapper only in its service's `PATH` (`/usr/local/lib/inputplumber-void/bin`:
  it adds the `M:`/`U:` lines that eudev's `udevadm` does not print) and to `acl-progs` (`setfacl`): without
  that, `Failed to hide device` and Steam saw two controllers. **Consumption:** ~3.2–3.5 % of one core and ~7100–7200
  wakeups/s fixed (measured on 2026-10-08 with `diag-inputplumber-cpu.sh`: it reads the body's IMUs
  opening and closing their sysfs files ~389 times/s, and the virtual controller through `/dev/uhid`); **it is left
  like that** (the user's decision; lowering the IMUs' frequency would cost gyroscope samples).

### Desktop

- **The same as the IdeaPad** (Orchis, Papirus teal, Volantes, JetBrainsMono NFM Blocks, xterm with the
  Super Game Bro palette, fastfetch, panels and Omarchy shortcuts), restored from `legion/xfce/` (up to date on 2026-10-05; its
  `displays.xml` is Wayland's: `DP-1`/`eDP-1`). **After changing something of Xfce, copy again
  `xfce-perchannel-xml/`, `panel/` and `gtk.css` to `legion/xfce/`** (in the repository, with the private values
  as `@NAME@`: `xfce4-panel.xml` remembers the Wi-Fi name; docs/sanitization.md).
- **It is used with an external monitor** (1920×1080 on the left; the Legion's screen on the
  right) at **96 DPI**. The window scripts (`window-snap`, `window-focus`,
  `new-windows`; `ventana-acoplar`, `ventana-foco`, `ventanas-nuevas` before) work **per monitor** with `xrandr` (they belong to the X11 session; in the Wayland one the
  same is done by the rules and shortcuts of labwc's `rc.xml`); almost maximized is the intermediate step
  between the two halves; new windows open almost maximized (event-driven watcher).
- **Super+Shift+number** goes with the US intl symbols (`exclam`, `at`, `numbersign`, `dollar`,
  `percent`, `dead_circumflex`, `ampersand`, `asterisk`, `parenleft`, `parenright`).
- **xterm:** Ctrl+Shift+C / Ctrl+Insert copy; Ctrl+Shift+V / Shift+Insert paste from the
  clipboard; OSC 52 allowed only to set text (copying from Claude Code over SSH).
- **"Minimalist" boot** (the user's decision, 2026-10-04): **hidden GRUB** (0 s, no menu;
  `GRUB_TERMINAL_OUTPUT=console` + `GFXPAYLOAD_LINUX=keep` so as not to turn off the firmware logo;
  `~/grub-hidden.sh [--remove]`), silent boot and **no Plymouth** (it was tried and removed, with the
  package: flicker). The menu (fallback kernel, **Windows on the XS1000** through `chainloader`, theme
  void-xterm) is still configured but hidden: Windows, from the firmware's boot menu.
  **Unmount `Common` before booting that Windows** and shut it down with Shift + Power off.
- **Game Mode** (Steam + gamescope on the screen, like SteamOS; external one if there is one, `-O '*',eDP-1`)
  **without loading screen**; switch to desktop (Xfce Wayland/labwc) without password. **Steam
  closes cleanly** when switching mode and at shutdown (`/etc/runit/shutdown.d/05-close-steam.sh`,
  `05-cerrar-steam.sh` before); when logging out
  from the Xfce desktop, only with the wrapper `/usr/local/bin/xfce4-session` (2026-10-04, verified
  here: `Shutdown` when rebooting with the panel's button; without it Steam died with the session); the
  desktop Steam goes with `-steamdeck` (same client as Game Mode). Detail: recipe, 14–15.
  **Hot-plugged monitor:** the launcher carries the options and variables of SteamOS's session
  (`--xwayland-count 2 --generate-drm-mode fixed`…) **without** `-w 1280 -h 800 --max-scale 2
  --cursor-scale-height 720` (it came out blurry and with a big cursor); it works since 2026-10-04.
  **Black wallpaper on the internal screen when going back to the desktop:** `xfsettingsd` reconfigures the screens
  after `xfdesktop` paints the wallpaper; `~/.local/bin/wallpaper-watcher` (`fondo-vigilante` before; labwc autostart,
  event-driven through GTK) calls `xfdesktop --reload`. It is not PSR nor HDR/VRR (ruled out with `drm_info` and debugfs).
  **Wallpaper dialog on Wayland** (Void's xfdesktop 4.20.2 writes to `monitorUnknown`; `xfdesktop` reads
  `monitoreDP-1` / `monitorDP-1`; upstream #350): `xfdesktop-4.20.2_2` with commit `ed26b06a`,
  **built here** on 2026-10-09 (the same `.xbps` for the IdeaPad; `<repo>/common/xfce-wayland/xfdesktop-wallpaper/`,
  recipe step 15). **Installed** and verified on 2026-10-09 on the Legion's
  screen (`monitoreDP-1`) and on the external one (`monitorDP-1`); the dialog takes the screen **when it opens** (dragged,
  it does not notice: close it and open it on the other one). `void-update` watches it.
  **Thunar, "Establecer como fondo de pantalla"** ("Set as wallpaper") (same bug: `monitorUnknown`; no fix upstream):
  own patch (connector through `libxfce4windowing`, keeps the screen of Thunar's window),
  `Thunar-4.20.10_2` **built here** on 2026-10-09 (`<repo>/common/xfce-wayland/thunar-wallpaper/`, recipe step
  15). **Installed** and verified on 2026-10-09 on both screens; it is enough to drag Thunar to the screen you want.
  **Controller on the desktop** (2026-10-04, recipe step 14): Steam in the background when logging in
  (`~/.config/autostart/steam-background.desktop`, `steam-segundo-plano.desktop` before; `steam -steamdeck -silent`) with **`extest`**
  (`LD_PRELOAD=~/.local/lib/extest/libextest.so`, 32-bit, built here with Rust + `gcc-multilib`):
  Steam moves the pointer through XTest and Xwayland does not pass it to labwc; `extest` turns it into a
  `uinput` mouse (`extest fake device`). Right trackpad click with **"Pulsación doble"** ("Double Press") (from the factory,
  "Pulsación suave" ("Soft Press"): brushes = clicks); right trigger = left click. Copies in
  `<repo>/legion/steam/`. Steam's keyboard (`utility` window) is exempted from labwc's
  rules. **Race with elogind** when switching mode (panels through X11, flicker):
  `restart-lightdm` (`reiniciar-lightdm` before), launched by runit (`sv once mode-switch`), prevents it (verified). If after
  a switch the screen stays off: `cat /run/switch-mode.log`; `ssh -t lego sudo sv start lightdm`.
  **Decky Loader** (service `decky`; plugins SteamGridDB and CSS Loader) and xterm art
  (`<repo>/common/steam/art-xterm/generate.py`; the quick menu's icon was set from Steam).
  **Volantes cursor** also in Game Mode (SteamOS's `steam` theme is not published): the
  launcher reads it from xsettings and puts it in `XCURSOR_THEME` and `gtk-3.0/settings.ini`. Verified.
- **Bluetooth name = hostname** (2026-10-08): `bluetoothctl system-alias Legion-Go-Gen-2`, without root
  (`bluetoothctl show | grep Alias`); from the factory it was "BlueZ 5.86". In a reinstall, repeat it.
- **Bluetooth headphones** (Method 360 ANC): they only keep the last pairing properly; if
  they fail with `br-connection-create-socket`, delete them and pair them again (recipe).

## The other machines

| Alias | Machine | System | User |
|---|---|---|---|
| `ideapad` | IdeaPad 100 (`ideapad-100.local`) | Void + Xfce (labwc) | `isaac` |
| `msi` | MSI Thin 15 | CachyOS + Omarchy | `isaac` (**`sshd` disabled there**) |
| `deck` | Steam Deck LCD (`steamdeck.local`) | SteamOS 3.8.28 (2026-10-06) | `deck` |

**Steam Deck (`deck`, 2026-10-05):** Steam Deck LCD (`Jupiter`), **SteamOS 3.8.16** that day (kernel 6.16.12-valve24.5; **3.8.28** on 2026-10-06, when its gamescope portal was looked at), `steamdeck.local` over mDNS (Wi-Fi `wlan0`, 192.168.0.146 that day), user `deck` (in `wheel`). On SteamOS sshd comes off and `deck` without a password: it was enabled from its Konsole with `passwd` and `sudo systemctl enable --now sshd`. Keys authorized there: `isaac@ideapad-100` and `isaac@Legion-Go-Gen-2` (`ssh-copy-id deck`); alias `deck` in the `~/.ssh/config` of both. **It has no `hostname`** (use `cat /etc/hostname`). SteamOS is atomic: `/` (5 GB) is read-only except with `steamos-readonly disable`.


This machine's key is `isaac@Legion-Go-Gen-2`, authorized on the IdeaPad; the IdeaPad's is
authorized here.

## Rules that are expensive to learn

- **Never send the `sudo` password and a script through the same SSH `stdin`.**
- **To diagnose a machine without a key installed, `BatchMode=yes`** (faillock).
- **Remote scripts with `ssh <alias> bash -s <<'FIN'`.**
- **Before editing a file that a running process may have open, replace it with
  `mv`**, not with `cp`.
- **Event-driven rather than polling**: no blind waits nor loops with `sleep`.
- **The recipe must be followable without inferring anything**: each thing applied, with its exact command and
  its check; what is downloaded, with a copy on the disk (in this repository: the binaries are assets of the
  GitHub Release, `install/assets.tsv`).
- **(This repository) Never commit a private value:** MACs, UUIDs, Wi-Fi name, serial numbers, the Steam
  account id and the e-mail go as `@NAME@`, with the real value only in `<repo>/local.env` (git-ignored); before a commit,
  `<repo>/install/verify.sh --secrets` (docs/sanitization.md).

## Where the documentation is

On the **external Kingston XS1000 SSD**, partition `Common` (NTFS), mounted on
`/run/media/isaac/Common` (**mounting it asks for the graphical session**; it may be connected to the IdeaPad
and not here: then it is read through `ssh ideapad`). **Before editing a document, ONE copy
`<name>.bak` next to it**, overwritten on every edit. **This disk was already lost once:
unmount it cleanly before booting its Windows.**
**With this repository**, the Legion's part lives in the clone (`<repo>`; private GitHub repository
`void-legion-go2`): edit there, commit and push (git keeps the history: no `.bak` needed in the repository).

| Document | Path inside `Common` | In this repository |
|---|---|---|
| **This machine's recipe** | `Backups Linux/void-legion-go2.md` | `docs/void-legion-go2.md` (index) + `docs/recipe/` |
| Own pieces (scripts, Xfce, keyboard) | `Backups Linux/fish/void/legion/` | `legion/` |
| The IdeaPad's recipe (the base) | `Backups Linux/void-ideapad-100.md` | steps 1–15 in `docs/reference/void-ideapad-100-steps.md` |
| Previous recipe of here (SteamOS), reference | `Backups Linux/Handheld/new/steamos-nativo-legion-go2.md` | not included |
| What was rescued from SteamOS's `/home` | `Backups Linux/Handheld/new/rescate-steamos-2026-10-03/` | not included |
| Common Void pieces (fish, xterm, Xfce, GRUB, boot) | `Backups Linux/fish/void/` | `common/` |
| The IdeaPad's context | `Backups Linux/CLAUDE-void-ideapad.md` | not included |
| Claude Code memory of here (recipe, step 7) | `Backups Linux/claude-memoria-legion/` | `claude/memory/` |
| This file | `Backups Linux/CLAUDE-void-legion.md` | `claude/CLAUDE-void-legion.md` |

**Suspend** (`s2idle`) verified on 2026-10-04: controller, Wi-Fi and InputPlumber fine on wake
(without a suspend hook). **Windows game and gyroscope in a game verified** (Borderlands 3, Proton 9.0-2RC, without
launch options; Steam moved it to Proton 11.0 on 2026-10-05). **Pending** (in the recipe): nothing; the gyroscope of each controller
**is left like that on purpose** (the detached controllers work; *Decided* in the recipe), and the drain in unplugged suspend was measured on 2026-10-05 (≈ 2 %/h ≈ 1.5 W, 29.9 min of real sleep in 30). **Hibernation verified**
(2026-10-04, `loginctl hibernate`; it restores with the same `uptime -s`); the hook
`/etc/elogind/system-sleep/brightness` (`…/brillo` before) puts back the built-in screen's brightness on wake.

**SteamOS settings** (2026-10-05, recipe step 14, "SteamOS settings"; compared live with the Steam Deck, `ssh deck`): `sudo bash ~/like-steamos.sh` (`--remove`) sets `split_lock_mitigate=0`, inotify 524288/1024, `fq_codel`, huge pages `always` (in `/etc/rc.local`), **`rtkit`** (PipeWire in real time, RR 20, like the Deck; it only installs it: D-Bus starts it, not runit, since 2026-10-08), `earlyoom`, `gamemode`, `gamescope-32bit`, `-pipewire` in the desktop Steam, `preempt=full` (in `GRUB_CMDLINE_LINUX`, not in `_DEFAULT`, which `silent-boot.sh` and `grub-hidden.sh` rewrite) and `memlock` 8 MiB; if Steam is open, it closes it cleanly. `install-game-mode.sh` adds to Game Mode `ENABLE_GAMESCOPE_WSI=1`, `GAMESCOPE_LIMITER_FILE`, variable rate shading (AMD) and `-pipewire`. If a game goes wrong: `DISABLE_GAMESCOPE_WSI=1 %command%` in that game. **All verified on 2026-10-05**, also in Game Mode with Borderlands 3: gamescope's layer loaded in the game, FPS limit (`Swapchain received new refresh cycle: 33.33ms` in `console-linux.txt`) and shading at half rate (the VRS file goes to `2x2`). **FPS limit:** without VRR it gave half (30 → 15): the panel only has 144 Hz native and the modes that gamescope makes (script `lenovo.legiongo2.oled.lua`, 48–144 Hz) lose one refresh out of two (underlying cause not found out: Valve's amdgpu patches, PSR?). Fix: `STEAM_DISPLAY_REFRESH_LIMITS=48,144` in the launcher (DMI `83N0`/`83N1`) and **"Habilitar VRR"** ("Enable VRR") in Steam (Rendimiento / Performance): exact limits; without VRR, limits that divide 144. **Gyroscope of each controller: left like that on purpose** (the IMU turns on with "bypass", but InputPlumber 0.81 does not allow changing the filter through D-Bus and it would have to be patched).
