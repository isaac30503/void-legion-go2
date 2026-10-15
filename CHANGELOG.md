# Changelog

The notable changes of the system and this repository, newest first. The full account of each one (diagnosis,
attempts, measurements) is in the private repository's archive and, until 2026-10-14, in the tag
`recipe-single-file` (*History*).

## 2026-10-14

- **CI** (GitHub Actions): `install/verify.sh --ci` and the new automated tests (`tests/run.sh`) on every push;
  `verify.sh` also fails on unused catalog entries and broken links between the documents. Versions are dated tags,
  `vYYYY.MM.DD` ([this repository](docs/8-maintenance/4-this-repository.md#versions)).
- Commands and installed files no longer hard-code the user name (`$USER`, `$HOME`, `$(hostname)`, `@TARGET_USER@`).
- Documentation reorganized **by the system's layers** (`docs/1-platform` … `docs/8-maintenance`), one page per topic
  with install, check and problems, and [docs/reinstall.md](docs/reinstall.md) as the order of execution. Logs, the
  long rationale and Claude Code's context moved to the private companion repository.
- Public release done properly: **MIT** for this repository's own work, `THIRD_PARTY.md` and `LICENSES/` for what is not
  ours, the GPL binaries' sources in the Release, `local.env.age` moved to the private repository and removed from the
  history, **ShellCheck** clean and part of `verify.sh`.
- `void-update`'s summary fits half a terminal (symbols, short lines; detail under warnings or with `-v`).
- **Power button like the Steam Deck:** press = suspend, held ~3 s = power menu, in Game Mode and on the desktop
  (`common/power-button/`); elogind no longer powers off at the first press.

## 2026-10-13

- The old Spanish argument and option aliases removed.
- `local.env` kept encrypted (age, passphrase), with `install/secrets.sh`.

## 2026-10-11

- **`void-update`** replaces `update-system`: panel icon, checks without root on network connect and every 6 h,
  notifications, Void's news, services with old code, the summary. Both machines migrated to this repository's names
  (`install/migrate.sh`).

## 2026-10-09

- This repository: the Legion's documentation and pieces in English, private values as `@NAME@`, binaries in a
  Release, translatable messages.
- Own patches are **tested against the new code** (`patch-still-needed`) instead of assumed from versions.
- Patched `xfdesktop` and `Thunar`: choosing a wallpaper works on Wayland.
- Decky's "Colores" plugin (controllers' RGB) with `hidapi`.

## 2026-10-08

- steamos-manager with the `set_clocks` patch (no more manual-clock errors); the manual GPU clock and the overdrive.
- `rtkit` started only by D-Bus (it ran twice and looped).
- InputPlumber's CPU use measured and left as is.

## 2026-10-07

- Screen sharing: the wlroots portal with three patches (window sessions restored, no repeated chooser, the chooser
  knows who asks), the chooser always on top; in Game Mode, SteamOS's gamescope portal and a gamescope patch for a
  PipeWire crash.
- Remote Play in Game Mode (32-bit PipeWire modules and VA-API).
- The `void-maintainer` agent.

## 2026-10-06

- Desktop portals and the own screen-share chooser; Discord (Vesktop) through Flatpak, with its art and icons.
- Focus follows the mouse without raising; Xwayland always alive.

## 2026-10-05

- **SteamOS parity**, compared live with a Steam Deck (sysctl, huge pages, real-time audio, earlyoom, gamemode,
  preemption, memlock, gamescope's layer, the FPS limiter); the FPS limit's half-rate solved with VRR.
- The microSD's Steam library mounted at boot; Firefox as a game in Game Mode; `audio-ctrl` and `audio-priority`.

## 2026-10-04

- **InputPlumber** (Valve controller, body gyroscope), **fine TDP** via DKMS, **steamos-manager**, Decky.
- Steam in the background on the desktop with `extest`; Steam closes cleanly on every way out; mode switching without
  a race with elogind.
- Hidden GRUB, no Plymouth; hibernation with the brightness restored; `s2idle`.
- Wi-Fi without power saving, avahi only over Wi-Fi, `udev-net`; `wallpaper-watcher`; Game Mode follows a hot-plugged
  monitor and uses the desktop's cursor; the kernel held in the 6.18 series.

## 2026-10-03

- Installed: Void Linux + Xfce, replacing SteamOS. Game Mode like SteamOS, Xfce on Wayland (labwc) as the normal
  desktop, GRUB with the XS1000's Windows entry and the "void-xterm" theme, per-monitor window scripts.
