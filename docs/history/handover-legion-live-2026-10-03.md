# Handover: live test of Void (USB) on the Legion Go 2 — 2026-10-03

> English version of `TRASPASO-legion-live.md` (external disk, `Backups Linux/`). A historical document: the
> names of scripts, commands and files are the ones of that day (in Spanish; today's names in
> [`../glossary.md`](../glossary.md)), and the paths are the external disk's.

> **Historical (noted on 2026-10-07): already done, do not follow it.** The test was done and the Legion has
> Void since 2026-10-03: its recipe is `void-legion-go2.md` and its context `CLAUDE-void-legion.md`.

For a new Claude Code session in `~/Work`. Read this whole thing, then `CLAUDE.md` (already loaded) and
the two recipes of the `Common` disk (mount it if needed: `udisksctl mount -b /dev/sdb4`):
- `Backups Linux/void-ideapad-100.md` — above all **steps 14 (Game Mode like SteamOS) and 15
  (Xfce on Wayland/labwc)** and **Pendientes** (*Pending*) (the first entry: "PENDIENTE DE DECIDIR" ("PENDING DECISION")).
- `Backups Linux/Handheld/new/steamos-nativo-legion-go2.md` — the Legion's recipe with SteamOS
  (its *Pendientes*: the gyroscope).

## Where we come from (session of 2026-10-02/03, on the IdeaPad)

The underlying goal: **try on the IdeaPad (Void + runit) a SteamOS-like experience to see whether
it can be replicated on the Legion Go 2.** On the IdeaPad it already works and is documented:
- Game Mode: gamescope on the screen (DRM, Wayland), Steam with `-steamos3 -steampal -steamdeck
  -gamepadui`, autologin into the last mode, mode switch without password
  (`cambiar-modo-root` + `/etc/sudoers.d/zz-cambiar-modo`), loading screen (`steam-cargando`),
  audio (pipewire from the launcher), brightness through elogind, mangoapp, Decky as a runit service.
- Normal desktop: Xfce on Wayland with labwc (Omarchy-style shortcuts, Orchis theme, windows
  almost maximized, etc.). Xfce X11 as a backup.
- `steamos-manager` built for Void (in `fish/void/steam/steamos-manager/`), not installed.
- All the scripts are backed up in `Common`: `Backups Linux/fish/void/steam/` and
  `Backups Linux/fish/void/xfce-wayland/`.

## What is known about the Legion (read-only diagnosis through `ssh lego`, with SteamOS)

SteamOS 3.8.28, kernel `6.18.50-valve2-1-neptune`. Controllers through **InputPlumber 0.78**
(`50-legion_go_2.yaml`, virtual Valve controller `28DE:12FB`). Gyroscope: the sensor exists
(`gyro_3d`/`accel_3d` through `amd_sfh`), but InputPlumber's profile has no `iio` source.
Compared with Void's 6.18 kernel (the IdeaPad's):
- **Void DOES bring:** `mt7921e` (Wi-Fi), `amd_sfh`, `hid_sensor_gyro_3d`/`accel_3d`, `hid_playstation`.
- **Void does NOT bring:** `hid_lenovo_go` (`CONFIG_HID_LENOVO_GO`: Valve's patch, not in the normal
  kernel), `lenovo_wmi_gamezone`/`lenovo_wmi_other` (`CONFIG_LENOVO_WMI_GAMEZONE`/`_TUNING`: in the
  normal kernel but Void does not enable them; `steamos-manager` uses them for the TDP). InputPlumber is not
  in Void's repositories.
- Project already done for the gyroscope on SteamOS: `github.com/razoomnik/legion-go-2-steamos-gyro`.

## What comes now: the Legion booted with Void's live USB

Goal: **see what Void's kernel recognizes on the Legion WITHOUT installing anything** and decide between
(1) improving SteamOS (gyroscope) or (2) bringing Void (own kernel + InputPlumber built).
Check, and write the result in both recipes:
1. Kernel version of the ISO (`uname -r`); the ISO may bring one older than 6.18.
2. Screen: does it come out rotated? (the Legion's is portrait from the factory) → `cat /sys/class/drm/*/status`,
   and whether the kernel applies the orientation.
3. Wi-Fi (`mt7921e`): `ip link`, `lsmod | grep mt79`, connect.
4. Controllers without Lenovo's driver: `cat /proc/bus/input/devices` (do they show up as "Legion Controller"
   keyboard/mouse/touchpad and "Generic X-Box pad", as on SteamOS?), `ls /sys/class/hidraw`.
5. Gyroscope and accelerometer: `ls /sys/bus/iio/devices/` + `cat .../name`.
6. Sound, battery (`/sys/class/power_supply`), suspend (`cat /sys/power/mem_sleep`).
7. TDP: `ls /sys/class/firmware-attributes/` and `/sys/firmware/acpi/platform_profile*`.
8. Full `lsmod`, to compare it with SteamOS's.

**Access to the live system:** Void's ISO logs in as `anon` (password `voidlinux`; root also
`voidlinux`: the ISO's public defaults). The simplest: the user looks at the IP on the Legion (`ip a`) and, if one wants to get in
over SSH, start `sudo sv up sshd` there (or `sudo ln -s /etc/sv/sshd /var/service/`) and log in with
`ssh -o BatchMode=no anon@<ip>` (the IdeaPad's key is not in the live system: it will ask for the password;
**careful with faillock**: it is not the `deck` account, it is the live one). Careful: `ssh lego` does NOT work (it is SteamOS).
If there is no network, the user runs the commands on the Legion and pastes the output.

## Work rules with this user (also in `CLAUDE.md` and the memory)

- Answer **always in Spanish**.
- **Document everything** in the matching recipe (and in `CLAUDE.md` if it is about this machine), leaving
  **one** `.bak` next to it before editing, without inferring anything.
- What needs root is run by the user (`sudo` asks for a password); never send password and script
  through the same stdin.
- Event-driven rather than polling (no blind waits).
- **Do not install anything on the Legion nor touch its internal disk** (SteamOS) without the user deciding it.
- Unmount `Common` before booting the Windows on the XS1000.
