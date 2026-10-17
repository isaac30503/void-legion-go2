# Game Mode

SteamOS's Game Mode on Void: **gamescope driving the screen itself** (Wayland + Xwayland on DRM/KMS) and Steam
inside with **SteamOS's arguments** (`-steamos3 -steampal -steamdeck -gamepadui`). Without them Steam behaves as
a PC in Big Picture: another interface, no "Switch to Desktop", no control of the performance overlay. Entering
and leaving is in [login and modes](../4-sessions/1-login-and-modes.md).

## Install

After [Steam](1-steam.md) was opened once:

```bash
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen     # --remove undoes it
```

`--no-loading-screen`: no `steam-loading` splash (the launcher works without it; fewer screen handovers). With it,
`steam-loading` shows the frames of the Plymouth theme in use (`Theme=` of `/etc/plymouth/plymouthd.conf`), with the
firmware logo only when the theme uses it and at the theme's height, or those of `/usr/local/share/steam-loading/` if
a local theme script put a different one there; it opens at full screen size, so the first frames are never small in
a corner. Then
the [session pieces](../4-sessions/1-login-and-modes.md) and [Xfce on Wayland](../5-desktop/1-xfce.md), and reboot:
it enters Game Mode by itself.

## What it installs

- **`/usr/local/bin/steam-game-mode`, the launcher.** It starts its own D-Bus session bus (`dbus-run-session`;
  without it Steam's interface fails with `Failed to connect to the bus`), sets `XDG_CURRENT_DESKTOP=gamescope`,
  the keyboard (`XKB_DEFAULT_LAYOUT`/`XKB_DEFAULT_VARIANT` from `00-keyboard.conf`), starts **PipeWire** if it is not
  running (there is no session autostart here; without it Steam saw no audio device),
  [steamos-manager's user process](3-steamos-manager.md) and the [power button](../3-hardware-support/2-power.md#power-button)
  if they are installed, and launches gamescope with Steam. Log: **`~/.local/state/steam-game-mode.log`** (emptied
  on entry, written in append mode).
  - **On the screen** (the Wayland session, without `DISPLAY`): **`--adaptive-sync`** and **SteamOS's session
    options and variables** (`--generate-drm-mode fixed --xwayland-count 2 --default-touch-mode 4
    --hide-cursor-delay 3000 --fade-out-duration 200`, `STEAM_MULTIPLE_XWAYLANDS=1`,
    `STEAM_GAMESCOPE_*_SUPPORTED`, `GAMESCOPE_MODE_SAVE_FILE` and `GAMESCOPE_PATCHED_EDID_FILE` in
    `~/.config/gamescope/`…; with them Steam follows a monitor plugged in or out) **without** SteamOS's
    `-w 1280 -h 800 --max-scale 2 --cursor-scale-height 720` (blurry, big cursor). **Screen:** like SteamOS on this
    Legion, the external one if there is one, otherwise its own (`-O '*',eDP-1`). Plus the settings in
    [SteamOS parity](4-steamos-parity.md).
  - **Nested** (the backup X session, `/usr/share/xsessions/steam-game-mode.desktop`, with `DISPLAY`): gamescope full
    screen inside X.
  - **Cursor:** SteamOS's `steam` cursor theme is not public, so the launcher uses the desktop's (Volantes, read from
    `~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml`): `XCURSOR_THEME`, `XCURSOR_SIZE=24` and `gtk-cursor-theme-name` in
    `~/.config/gtk-3.0/settings.ini` (Steam's Chromium interface only reads that).
  - **It knows when Steam ends event-driven** (a pipe `$XDG_RUNTIME_DIR/…fifo` written by Steam's wrapper or by
    gamescope's subshell) and then **closes gamescope at once** (otherwise ~26 s waiting for elogind to release the
    screen) and calls `steamos-session-select` to go to the desktop.
- **Performance overlay like SteamOS:** gamescope **without** `--mangoapp` (it wrote `no_display` followed by a null
  byte and the overlay always showed); a `MANGOHUD_CONFIGFILE` starting at `no_display`, `STEAM_USE_MANGOAPP=1` and
  its companions, and `mangoapp` started separately. Steam rewrites the file when the level changes.
- **`/usr/local/bin/steamos-session-select`**, what Steam calls for "Switch to Desktop" (as on SteamOS): it only
  closes Steam; the launcher switches when gamescope ends. From the desktop ("Modo Juego" launcher,
  `/usr/share/applications/game-mode.desktop`) it closes the desktop's Steam cleanly and switches. Log
  `~/.local/state/steamos-session-select.log`.
- **`/usr/local/bin/steamos-update`**: with `-steamos3` Steam asks for system updates; it answers "No update
  available" (exit 7), like SteamOS. The system is updated with [void-update](../8-maintenance/1-void-update.md).
- **Brightness:** Steam changes it with `echo N | sudo -n tee /sys/class/backlight/<x>/brightness`, which here would
  ask for a password. **`/usr/local/lib/steam-game-mode/bin/sudo`**, first in the `PATH` only inside Game Mode,
  turns **only that exact command** into **elogind's `SetBrightness`** (what GNOME and KDE use: the session on screen
  may change its brightness without root) and passes everything else to the real `sudo`. Each value goes to the log
  (`brightness N (amdgpu_bl0)`).
- **`cap_sys_nice`** on `/usr/bin/gamescope` (without it: "No CAP_SYS_NICE … Performance will be affected"). **An
  update of gamescope removes it**; [void-update](../8-maintenance/1-void-update.md) puts it back.

## Check

```bash
grep -m1 'mode:' ~/.local/state/steam-game-mode.log     # mode: direct screen (DRM)
pgrep -a gamescope                                      # gamescope-wl …, with --xwayland-count 2 and not -w 1280
getcap /usr/bin/gamescope                               # cap_sys_nice=eip
grep cursor: ~/.local/state/steam-game-mode.log         # cursor: volantes_cursors
```

gamescope's process is called **`gamescope-wl`**. From Game Mode to Steam's interface takes seconds (with Steam
closed cleanly, about one).

## Quick menu → Performance

The advanced options (FPS limit, scaling filter: FSR, NIS…) are behind **"Vista avanzada"** ("Advanced view") at the
end, as on SteamOS. **TDP, power profiles and the manual GPU clock** come from
[steamos-manager](3-steamos-manager.md).

## Problems

- **Stuck:** Ctrl+Alt+F2, log in, `pkill -KILL -x gamescope-wl`, `sudo sv restart lightdm`.
- **The external monitor stays black at boot** (seen once: gamescope chose `DP-1` at 1920×1080@60 without errors,
  but no image until the cable was replugged). Without touching the cable, from another machine: `ssh lego` and
  `sudo sh "$B/legion/diag-monitor.sh"` (leaves `~/diag-monitor.log`: connectors, GPU, processes, `dmesg`).
- **When testing anything shown inside gamescope, use `-e`:** with it a window without `STEAM_GAME` and without
  `GAMESCOPECTRL_BASELAYER_APPID` on the root is not shown at all.
- **Harmless in the log:** `[MANGOHUD] … Unknown option 'nis_steam_sharpness'` (Void's `mangoapp` 0.8.4 does not know
  it; only NIS sharpness is missing from the overlay); Steam's adaptive brightness lines (many in the first minute;
  `steamos-priv-write failed` in `console_log.txt`: Steam tries SteamOS's helper first, then the `sudo` above).
