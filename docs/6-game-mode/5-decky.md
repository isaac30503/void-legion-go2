# Decky Loader

Plugins for Steam's quick menu, as on SteamOS.

```bash
sudo sh "$B/common/steam/install-decky.sh"      # --remove undoes it (leaves ~/homebrew/plugins)
sudo xbps-install -S hidapi                     # for the "Colores" plugin (the controllers' RGB)
```

Then restart Steam (it reads the debugging file on start). The installer adds `psmisc` and `inotify-tools`, creates
`~/homebrew/{services,plugins}`, `~/.steam/steam/.cef-enable-remote-debugging` and the link `/home/deck` →
`/home/<user>` (plugins expect SteamOS's user), downloads `PluginLoader` from GitHub and runs it as the runit service
**`decky`** (as root, `KEEP_SYSTEMD_SERVICE=1`). Decky updates itself from its menu; the service's `run` notices it
**event-driven** (`inotifywait` on `.loader.version`, waiting until the new binary is executable) and restarts it.
Its output goes to `/var/log/decky/current` (svlogd, 1 MB × 2; `journalctl -u plugin_loader` reads it).

**Plugins made for SteamOS call systemd** (`systemctl restart plugin_loader` after updating themselves,
`systemctl is-active inputplumber.service`, `systemd-inhibit`…): that is answered by
[systemd-compat](../2-base-system/4-systemd-compat.md), installed in step 15 of the reinstallation. Without it, the
"restart Decky" button of Hooandee's plugins never restarts it (by hand: `sudo sv restart decky`).

**Plugins** (from its store): **SteamGridDB**, **CSS Loader**, **Colores** and **Panel de Control** (the last two by
Hooandee), **MAKO - Frame Generation** and **Decky-Framegen**. **Colores needs `hidapi`**: it loads `libhidapi-hidraw.so.0` with `ctypes` (SteamOS ships it); without it, it
says no RGB controller is found (`~/homebrew/logs/Colores/*.log`: `driver=NullDevice … available=False`). After
installing it, `sudo sv restart decky`. It runs as root, so it reaches the controller even with InputPlumber hiding
it; it turns the lights off before suspending and restores them after (through `systemd-inhibit` = elogind's).
**Panel de Control** finds InputPlumber (its controller section: remapping Y1–Y3 and M1–M3 on top of InputPlumber's
`Default` profile, which is the one loaded; our `deck-uhid` target device is not touched) and its equalizer runs
PipeWire's `filter-chain` as a user unit; `python3-yaml` and `caps` come with systemd-compat's installer.

**Check:** `pgrep -a -f homebrew/services/PluginLoader`; port `127.0.0.1:1337` open; the plug icon in the quick menu;
for Colores, `Found Legion Go device: PID=0x61EB …` and `Successfully set Legion Go RGB` in its log.

## Mako and FPS limiting

When **MAKO - Frame Generation** is enabled through **Panel de Control**:

- **`DISABLE_GAMESCOPE_WSI=1` is mandatory:** `mako-launch` (`~/.local/share/panel-de-control/mako/4.6.0/bin/mako-launch`)
  exports it because keeping `VkLayer_FROG_gamescope_wsi` active above Mako's generated/original frame sequence serializes
  presents and collapses frame pacing (~13 FPS).
- **Avoid X11 FIFO input lag (`MAILBOX`):** with Xwayland/VKD3D and `DISABLE_GAMESCOPE_WSI=1`, FIFO swapchains introduce
  noticeable input lag. Enabling `adaptive_stable_cadence = false`, `swapchain_image_count_compatibility = true`, and
  `mailbox_presentation_compatibility = true` in the generated `conf.toml` (patched in
  `~/homebrew/plugins/Panel de Control/py_modules/upscalers/mako.py`, with `version=1` in `launcher.conf`; `.bak` kept
  alongside it) switches presentation to `VK_PRESENT_MODE_MAILBOX_KHR` and removes the lag. Note that updating Panel de
  Control later overwrites `mako.py`, so check that diff if latency returns.
- **Steam's Quick Access Menu FPS limiter has no effect under Mako:** Steam's limiter inside the game process relies on
  `VkLayer_FROG_gamescope_wsi` (`GAMESCOPE_LIMITER_FILE`), which `mako-launch` disables, and `MAILBOX` never blocks on
  Wayland/Xwayland frame callbacks. Leaving `base_fps_cap = 0` runs the game and frame generator uncapped.
- **Recommended limiting mode (verified 2026-11-14 with Borderlands 3 at 1920×1080@200 Hz):** switch the game's Mako
  profile in **Panel de Control** to **Adaptive** mode with the desired `target_fps` (for example `adaptive = true`,
  `target_fps = 60`, `adaptive_max_multiplier = 2`). Mako paces frame generation to that target cleanly without
  reintroducing input lag. Do **not** edit `~/.config/panel-de-control/mako/<appid>/conf.toml` outside Panel de Control:
  `mako.py` verifies its SHA-256 and raises `mako_conflict` on mismatch.
