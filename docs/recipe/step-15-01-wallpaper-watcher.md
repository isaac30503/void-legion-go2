### Internal screen without wallpaper when coming from Game Mode: `wallpaper-watcher` (2026-10-04)

**Symptom:** when going from Game Mode to the desktop, the Legion's screen stayed **black** (the
external monitor fine). The cursor and the windows were visible on it: only `xfdesktop`'s wallpaper
was missing. Switching workspace fixed it until the next mode switch.
**Cause:** when the session starts, `xfsettingsd` applies the display profile
(`~/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml`: external at `0,62` back then (today `0,0`, step 13), Legion at `1920,0` at
144 Hz) **after** `xfdesktop` painted the wallpaper, and `xfdesktop` does not paint it again on the
internal screen. `xfdesktop --reload` brings it back (tested over SSH with the screen black).
**Fix:** `~/.local/bin/wallpaper-watcher` ("wallpaper watcher"; Python + the system's GTK, `common/xfce-wayland/`),
started from labwc's `autostart`. **Event-driven:** it waits for GTK's signals (screen
added/removed, geometry or scale change) and, half a second after the last one (they arrive in a
burst), calls `xfdesktop --reload` once. It also works when connecting or removing the monitor with the
session open. `install-xfce-wayland.sh` installs it (and its `--remove` removes it); to put it without
redoing everything: copy `wallpaper-watcher` to `~/.local/bin/` (755) and `labwc/autostart` to
`~/.config/xfce4/labwc/`. **Check:** `~/.local/state/wallpaper-watcher.log` (redone every
session) after coming back from Game Mode:
```
03:21:06 vigilando 2 pantallas
03:21:06 geometry: Unknown 1920x1080+0+62
03:21:06 geometry: Unknown 1920x1200+1920+0
03:21:07 xfdesktop --reload (rc=0)
```
("vigilando 2 pantallas" = "watching 2 screens") and the internal screen with wallpaper. **Verified by the user on 2026-10-04.**
**Discarded along the way** (so as not to repeat it):
- **SteamOS's Game Mode variables** (HDR, VRR, color): with `drm_info` at the black moment,
  `Colorspace=Default`, `HDR_OUTPUT_METADATA=0`, `VRR_ENABLED=0`, without `GAMMA_LUT`/`CTM`; the screen
  on, with its mode and its image assigned.
- **The panel's self-refresh (PSR)**: the panel supports it and it was in use, but blocking it
  live (`echo 1 > /sys/kernel/debug/dri/0000:c2:00.0/eDP-1/disallow_edp_enter_psr`, mounting
  debugfs first; it is lost on reboot) **changed nothing**. Panel Replay: the panel does not support it.
  The kernel was not touched (`amdgpu.dcdebugmask`).
- **The screen's state in amdgpu** (`sudo sh "$B/legion/diag-edp.sh" black|fine`, in `legion/`: reads the
  debugfs of `eDP-1`, the backlight and `dmesg`): **identical** black and with image.
- Tools used for this (read-only): `drm_info` and `wlr-randr`. **Removed on 2026-10-06**
  (final product, *Pending*, "Cleanup"); if they are needed again: `sudo xbps-install -S drm_info
  wlr-randr`. `drm_info` runs without root; `wlr-randr` needs `WAYLAND_DISPLAY=wayland-0` (over SSH, plus
  `XDG_RUNTIME_DIR=/run/user/1000`).

