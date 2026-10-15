# Void Linux on the Legion Go 2 — the recipe

The complete reinstall recipe, one file per step (the file name carries the step number). Read it in this
order: **the reinstall list first** (points A–M, each with its commands), then each step with its why and
its check. Step numbers are those of the IdeaPad's recipe, which this one builds on: that is why 7 comes
after 13 and 15 is installed inside 14.

Until 2026-10-14 this was a single file; it was split without changing a byte (the parts, joined in their
original order, gave the same file: checked with `cmp`). That single file is the git tag
[`recipe-single-file`](https://github.com/isaac30503/void-legion-go2/blob/recipe-single-file/docs/void-legion-go2.md).

## Before starting

- [Void Linux on the Legion Go 2](recipe/00-introduction.md)
- [Starting point](recipe/00-starting-point.md)
- [Reinstall: the order, at a glance](recipe/00-reinstall-list.md)

## Steps, in the order they are applied

- [0. Before installing: live test and rescue of SteamOS (2026-10-03)](recipe/step-00-live-test-and-rescue.md)
- [1. Installation with `void-installer`](recipe/step-01-void-installer.md)
- [2–3. System up to date, keyboard and SSH (one script)](recipe/step-02-03-system-keyboard-ssh.md)
- [4. SSH access in both directions](recipe/step-04-ssh-both-directions.md)
- [5–12. X11 desktop](recipe/step-05-12-x11-desktop.md)
- [13. Xfce configuration and per-monitor windows](recipe/step-13-xfce-configuration.md)
- [7. Claude Code (2026-10-03)](recipe/step-07-claude-code.md)
- [8. GRUB: Windows on the XS1000, silent boot, theme and hidden GRUB (2026-10-03 and 04)](recipe/step-08-grub.md)

## Step 14 — Steam and Game Mode

- [14. Steam and Game Mode like SteamOS (2026-10-03)](recipe/step-14-00-steam-and-game-mode.md)
- [InputPlumber: the Legion's controller as a Valve controller (2026-10-04)](recipe/step-14-01-inputplumber.md)
- [Fine TDP: `lenovo-wmi-*` modules via DKMS (2026-10-04)](recipe/step-14-02-tdp-dkms.md)
- [steamos-manager: TDP, profiles and GPU clock from Steam (2026-10-04)](recipe/step-14-03-steamos-manager.md)
- [Decky Loader (2026-10-04)](recipe/step-14-04-decky-loader.md)
- [xterm library art (2026-10-04)](recipe/step-14-05-xterm-library-art.md)
- [Discord (Vesktop) via Flatpak, the GNOME Software store and its art (2026-10-05 and 06)](recipe/step-14-06-vesktop-and-screen-sharing.md)
- [Remote Play (Remote Play Together) in Game Mode: 32-bit PipeWire and VA-API (2026-10-07)](recipe/step-14-07-remote-play.md)
- [Controller on the desktop: Steam in the background, `extest` and the desktop layout (2026-10-04)](recipe/step-14-08-controller-on-the-desktop.md)
- [Hibernation and brightness on wake (2026-10-04)](recipe/step-14-09-hibernation-and-brightness.md)
- [microSD: Steam library, always mounted at boot (2026-10-05)](recipe/step-14-10-microsd.md)
- [SteamOS settings: compared live with a Steam Deck (2026-10-05)](recipe/step-14-11-steamos-settings.md)
- [Power button: press = suspend, held ~3 s = power menu, in both modes, like the Deck (2026-10-14)](recipe/step-14-12-power-button.md)

## Step 15 — Xfce on Wayland

- [15. Xfce on Wayland (labwc) (2026-10-03)](recipe/step-15-00-xfce-wayland.md)
- [Internal screen without wallpaper when coming from Game Mode: `wallpaper-watcher` (2026-10-04)](recipe/step-15-01-wallpaper-watcher.md)
- [Xwayland always alive: `xwaylandPersistence` (2026-10-06)](recipe/step-15-02-xwayland-persistence.md)
- [Focus without raising: raise only on click (2026-10-06)](recipe/step-15-03-focus-without-raising.md)
- [Screen-share chooser always on top (2026-10-07)](recipe/step-15-04-screen-share-chooser-on-top.md)
- [Steam's on-screen keyboard: exception in the window rules (2026-10-04)](recipe/step-15-05-steam-keyboard-exception.md)
- [Desktop wallpaper on Wayland: patched xfdesktop (2026-10-09; installed)](recipe/step-15-06-xfdesktop-wallpaper.md)
- [Wallpaper from Thunar on Wayland: patched Thunar (2026-10-09; installed)](recipe/step-15-07-thunar-wallpaper.md)

## After

- [Troubleshooting](recipe/troubleshooting.md)
- [Verification](recipe/verification.md)
- [Pending](recipe/pending.md)
- [History](recipe/history.md)
