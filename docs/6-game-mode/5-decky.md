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
