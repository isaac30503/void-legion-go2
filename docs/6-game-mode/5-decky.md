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

**Plugins** (from its store): **SteamGridDB**, **CSS Loader**, **Colores** and **Panel de Control** (the last two by
Hooandee). **Colores needs `hidapi`**: it loads `libhidapi-hidraw.so.0` with `ctypes` (SteamOS ships it); without it, it
says no RGB controller is found (`~/homebrew/logs/Colores/*.log`: `driver=NullDevice … available=False`). After
installing it, `sudo sv restart decky`. It runs as root, so it reaches the controller even with InputPlumber hiding
it; it restores the color after suspending (a warning about `systemd-inhibit` is harmless).

**Check:** `pgrep -a -f homebrew/services/PluginLoader`; port `127.0.0.1:1337` open; the plug icon in the quick menu;
for Colores, `Found Legion Go device: PID=0x61EB …` and `Successfully set Legion Go RGB` in its log.
