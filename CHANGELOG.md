# Changelog

The notable changes of the system and this repository, newest first. The full account of each one (diagnosis,
attempts, measurements) is in the private repository's archive and, until 2026-10-14, in the tag
`recipe-single-file` (*History*).

## 2026-10-17

- **Tests for `ssh-find`** (`tests/ssh_find_test.py`, 31 checks, run by `tests/run.sh`; 106 in all): without a network,
  with real TCP connections to the loopback and the home network's parts faked — candidates (IPv4, IPv6, link-local
  on every interface), the neighbour table, simultaneous connections (the first that answers wins, a silent address
  costs one round), the order of the ways (last address, MAC in the table, names), a remembered address that is
  another machine's today, discovery rounds only when there are MACs to look for, the deadline, the MACs it learns,
  the state file and `--list`. (After the tag `v2026.10.17.1`.)

- **Rules for the inventory, as for a Void package** ([adding or changing a piece](docs/8-maintenance/4-this-repository.md#adding-or-changing-a-piece)):
  one piece per function; every file with exactly one owner (`verify.sh` now fails on two); `installs` only the paths
  that prove it is there; a new column **`undo`** (like `xbps-remove`: `--remove`, checked against the installer, `rm`,
  or the command); settings made by hand are pieces too (Steam's and Firefox's settings, Decky's plugins, Bluetooth
  pairings, Vesktop). 60 pieces. (After the tag `v2026.10.17`.) From a third outside review: every installed piece
  now needs its proof (the rule compared with "" and the table writes "-": `grub-hidden`, `direct-session` and the
  wallpaper patch had none), with two new forms, `grep:<file>:<regex>` and `xbps-local:<package>`; an installer is
  matched as a whole name in `install.sh` and the docs, not as a substring. From a fourth: `test-direct-session.sh` is
  now `install-direct-session.sh` (an installer named `test-…` was confusing; the old marker in `lightdm.conf` is still
  recognized), and a `grep:` proof that cannot be read without root says "not verifiable" instead of passing.
  From a fifth: `tests/run.sh` stops with a message as root (the scripts refuse root on purpose: 11 tests "failed" for
  that); `THIRD_PARTY.md` says the six Plymouth themes are in use again and what they take from Plymouth's `bgrt` and
  `spinner`; every `rm -rf` of a variable uses `${VAR:?}`; ShellCheck's SC2086 and SC2015 notes are now enforced by
  `verify.sh` (the `a && b || c` became `if`, the splitting on purpose says why); `like-steamos.sh` runs with
  `set -euo pipefail`; the diagnostic scripts moved to `legion/diag/` and `common/diag/`; Python: an unused import,
  `zip(strict=True)`, and the bubbles' opacity written so that it is plainly one per bubble (it already was).

- **The inventory, `install/pieces.tsv`** ([this repository](docs/8-maintenance/4-this-repository.md#the-inventory-installpiecestsv)):
  every piece the repository installs, one per line, enforced by `verify.sh` (every file has its piece, every installer
  its place in the reinstall), checked on each machine by the audit and read by the maintenance agents. Writing it
  found what the reinstall had lost: `install.sh` now installs systemd-compat, Plymouth and `ssh-find`, both reinstall
  documents the wallpaper patches (xfdesktop, Thunar), and Game Mode keeps its loading screen (the `--no-loading-screen`
  of 2026-10-04 had stayed in the reinstall after Plymouth came back). The IdeaPad-only `bluetooth-at-boot.sh` and
  `greeter-without-atspi.sh` are named in their pages.

- **systemd-compat** (`common/systemd-compat/`, [systemd-compat](docs/2-base-system/4-systemd-compat.md)): Decky
  plugins made for SteamOS (Hooandee's Panel de Control and Colores) call `/usr/bin/systemctl restart plugin_loader`
  after updating themselves, `systemctl is-active inputplumber.service`, a `filter-chain` user unit and
  `systemd-inhibit`; on Void none of that existed (the restart button did nothing, Panel hid its controller section).
  Now `systemctl`, `journalctl` and `systemd-run` answer them with runit, the session's processes and elogind, without
  modifying the plugins and without anything resident; `/run/systemd` is never created. Decky logs to
  `/var/log/decky` (svlogd); `python3-yaml` and `caps` installed. `void-update --systemd [--ack]` reports what was not
  served, plugins whose systemd calls changed, and scripts that decide "is there systemd?" by `systemctl` existing;
  one line in the summary. `ssh-survey.sh` now knows runit by PID 1 (it was one of those scripts). 35 → 70 tests.

- **Controller layouts:** xterm and Vesktop use a copy of the layout Steam gives Firefox (Web Browser template, left
  stick as the mouse wheel), kept in `legion/steam/web-browser-layout-controller_steamos_handheld.vdf`
  ([Steam](docs/6-game-mode/1-steam.md#xterm-as-a-game)); the desktop layout takes its left stick from it. The
  keyboard opens with X, as in Valve's desktop template: the docs said RT+X, which no Valve layout has.

- **Plymouth's default is "B with B":** `install-plymouth.sh` without options installs Void B at power-on and Steam B
  as Game Mode's loading screen (before: Steam A for both); `--loading-same` keeps the boot's one for Game Mode.

## 2026-10-16

- **A second screen at another scale (a 4K TV at scale 2):** `wallpaper-watcher` now puts the panels on the external
  screen (xfce4-panel cannot name screens on labwc: `monitor-N-Unknown`, Automatic again without one) and restarts
  `xfdesktop` when a scale changes (4.20.2 drew the Legion's screen zoomed in and ignored its new wallpaper).
  `displays.xml` keeps two saved profiles, "Monitor MSI" and "Sala 4K", applied by themselves. The clock is alone in a
  third, top-centre panel, so it sits in the middle of the screen.

- **`ssh-find`** (`common/ssh-find/`, [network and SSH](docs/2-base-system/2-network.md#ssh-find-finding-the-machines)):
  SSH between the machines no longer depends on one mDNS name. A `ProxyCommand` tries at once the last address that
  worked, the neighbour table by MAC (IPv4 and IPv6 link-local with its interface) and every name, then discovery,
  in rounds for up to 15 s; it learns the machines' MACs; `HostKeyAlias` fixed per machine. Same on both machines,
  without root.

- **Plymouth again**, renewed (`common/boot/install-plymouth.sh`, [boot](docs/1-platform/3-boot.md#the-loading-animations)):
  six animations drawn from vectors at the panel's size — Steam A/B/C and Void A/B/C (A with the firmware logo, B the
  same symbol large, C Steam's mechanism with STEAM or Void's logo with its letters) — for the boot and, the same or
  another, for Game Mode's loading screen (`--loading-…`). `loglevel=2` with `splash` (`silent-boot.sh`): amdgpu's
  `pr_crit` overdrive warning took the screen before Plymouth. At shutdown, black without runit's lines (the animation
  is opt-in: it freezes on the Legion's panel). The Legion: `--void-b --loading-steam-b`.

- Game Mode's loading screen (`steam-loading`) follows the Plymouth theme in use: its frames (any number), the
  firmware logo only when the theme uses it and the theme's height; or a different screen of its own in
  `/usr/local/share/steam-loading/`. It opens at full screen size: before, the first frames came out small and
  cropped in the top-left corner.

## 2026-10-14

- **CI** (GitHub Actions): `install/verify.sh --ci` and the new automated tests (`tests/run.sh`) on every push;
  `verify.sh` also fails on unused catalog entries and broken links between the documents. Versions are dated tags,
  `vYYYY.MM.DD` ([this repository](docs/8-maintenance/4-this-repository.md#versions)).
- labwc: Xfce's settings windows (CSD) get the teal focus border, like Firefox and Steam.
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
