# Void Linux on the Legion Go 2 — documentation

The system is described **by layers, from the bottom up**: each layer builds on the ones below it. To rebuild it from
an empty disk, follow **[reinstall.md](reinstall.md)** (the order of execution); to understand or fix a piece, go to its
layer. Every page has the same parts: what it is and why, how to install it, how to check it, and its known problems.
To see first what it is like to use, with screenshots: **[the tour](tour.md)**.

```
 8  maintenance     void-update · own patches · Claude Code · this repository
 7  apps            screen sharing · Vesktop · Firefox
 6  game mode       Steam · Game Mode · steamos-manager · SteamOS parity · Decky · art · Remote Play · controller on the desktop
 5  desktop         Xfce (Wayland/labwc and X11) · look and feel · windows and shortcuts · wallpaper
 4  sessions        autologin · mode switching without password · clean Steam shutdown
 3  hardware        controllers and gyroscope · power (TDP, GPU, power button, sleep) · audio and Bluetooth
 2  base system     Void, keyboard, runit, SteamOS-like tuning · network and SSH · storage
 1  platform        hardware · installation · boot (hidden GRUB, kernel 6.18)
```

## 1. Platform

- [Hardware](1-platform/1-hardware.md)
- [Installation](1-platform/2-installation.md)
- [Boot](1-platform/3-boot.md)

## 2. Base system

- [System](2-base-system/1-system.md)
- [Network and SSH](2-base-system/2-network.md)
- [Storage](2-base-system/3-storage.md)
- [systemd-compat: programs written for systemd](2-base-system/4-systemd-compat.md)

## 3. Hardware support

- [Controllers and gyroscope](3-hardware-support/1-controllers.md)
- [Power: TDP, GPU clock, power button, suspend and hibernation](3-hardware-support/2-power.md)
- [Audio and Bluetooth](3-hardware-support/3-audio-bluetooth.md)

## 4. Sessions

- [Login and modes](4-sessions/1-login-and-modes.md)

## 5. Desktop

- [Xfce: X11 and Wayland](5-desktop/1-xfce.md)
- [Look and feel](5-desktop/2-look-and-feel.md)
- [Windows and shortcuts](5-desktop/3-windows-and-shortcuts.md)
- [Wallpaper on Wayland](5-desktop/4-wallpaper.md)

## 6. Game Mode

- [Steam](6-game-mode/1-steam.md)
- [Game Mode](6-game-mode/2-game-mode.md)
- [steamos-manager: Performance from Steam](6-game-mode/3-steamos-manager.md)
- [SteamOS parity](6-game-mode/4-steamos-parity.md)
- [Decky Loader](6-game-mode/5-decky.md)
- [Library art](6-game-mode/6-library-art.md)
- [Remote Play](6-game-mode/7-remote-play.md)
- [The controller on the desktop](6-game-mode/8-controller-on-desktop.md)

## 7. Apps

- [Screen sharing](7-apps/1-screen-sharing.md)
- [Discord (Vesktop)](7-apps/2-vesktop.md)
- [Firefox](7-apps/3-firefox.md)

## 8. Maintenance

- [void-update and the everyday tools](8-maintenance/1-void-update.md)
- [Own patches and packages built here](8-maintenance/2-own-patches.md)
- [Claude Code](8-maintenance/3-claude-code.md)
- [This repository](8-maintenance/4-this-repository.md)

## Reference

- [Reinstall](reinstall.md) — the order of execution
- [Sanitization](sanitization.md) — `@NAME@`, `local.env` and its encrypted copy
- [Translations](i18n.md) — the messages in the system's language
- [Glossary](glossary.md) — the original Spanish names
- [ssh-setup](ssh-setup.md) — its manual

The documentation until 2026-10-14 was a single recipe ordered by the IdeaPad's step numbers, with every dated note,
diagnosis and attempt: the public git tag
[`recipe-single-file`](https://github.com/isaac30503/void-legion-go2/blob/recipe-single-file/docs/void-legion-go2.md),
and in full, with the logs and the history, in the private repository's archive.

## Old step numbers

Scripts, messages and older notes cite the recipe's step numbers. Where each one is now:

| Old step | Page |
|---|---|
| 0, 1 | [installation](1-platform/2-installation.md) |
| 2–3 | [system](2-base-system/1-system.md), [network](2-base-system/2-network.md) |
| 4 | [network and SSH](2-base-system/2-network.md) |
| 5–12 (6: functions and void-update; 9: software and themes; 10: login screen; 11: xterm; 12: fastfetch) | [Xfce](5-desktop/1-xfce.md), [look and feel](5-desktop/2-look-and-feel.md), [void-update](8-maintenance/1-void-update.md), [audio and Bluetooth](3-hardware-support/3-audio-bluetooth.md) |
| 7 | [Claude Code](8-maintenance/3-claude-code.md) |
| 8 | [boot](1-platform/3-boot.md) |
| 13 | [Xfce](5-desktop/1-xfce.md), [look and feel](5-desktop/2-look-and-feel.md), [windows and shortcuts](5-desktop/3-windows-and-shortcuts.md) |
| 14 (Steam, Game Mode) | [Steam](6-game-mode/1-steam.md), [Game Mode](6-game-mode/2-game-mode.md), [login and modes](4-sessions/1-login-and-modes.md) |
| 14 (InputPlumber, gyroscope) | [controllers](3-hardware-support/1-controllers.md) |
| 14 (TDP, overdrive, hibernation, brightness, power button) | [power](3-hardware-support/2-power.md) |
| 14 (steamos-manager) | [steamos-manager](6-game-mode/3-steamos-manager.md) |
| 14 (SteamOS settings) | [SteamOS parity](6-game-mode/4-steamos-parity.md), [system](2-base-system/1-system.md) |
| 14 (Decky, art, Remote Play, controller on the desktop, microSD) | [Decky](6-game-mode/5-decky.md), [art](6-game-mode/6-library-art.md), [Remote Play](6-game-mode/7-remote-play.md), [controller on the desktop](6-game-mode/8-controller-on-desktop.md), [storage](2-base-system/3-storage.md) |
| 14 (Vesktop, portals, screen sharing, Firefox as a game) | [screen sharing](7-apps/1-screen-sharing.md), [Vesktop](7-apps/2-vesktop.md), [Firefox](7-apps/3-firefox.md) |
| 15 (Xfce on Wayland, labwc, wallpaper) | [Xfce](5-desktop/1-xfce.md), [windows and shortcuts](5-desktop/3-windows-and-shortcuts.md), [wallpaper](5-desktop/4-wallpaper.md) |
| reinstall list A–M | [reinstall](reinstall.md) |
| *Troubleshooting*, *Verification*, *Pending* | the **Problems**, **Check** and **Known limits** of each page |
| *History* | [CHANGELOG.md](../CHANGELOG.md); the full one in the private archive |
