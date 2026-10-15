### Decky Loader (2026-10-04)

```bash
sudo sh "$B/common/steam/install-decky.sh"            # the same as the IdeaPad's (common/steam/), unchanged
```
The same as on the IdeaPad (its recipe, step 14, *Decky Loader*): `psmisc` and `inotify-tools`,
`~/homebrew/{services,plugins}`, `~/.steam/steam/.cef-enable-remote-debugging`, `/home/deck` →
`/home/isaac`, `PluginLoader` **v3.2.9** from GitHub (it updates itself from its menu: v3.2.10 on 2026-10-07; the `run`
restarts it when it detects it) and the runit service `decky`. Then restart
Steam (it reads the debugging file on start). Check: `pgrep -a -f
homebrew/services/PluginLoader`, port `127.0.0.1:1337` open and the plug icon in the
quick menu. **Verified on 2026-10-04.** Plugins installed from its store: **SteamGridDB**
(`decky-steamgriddb`) and **CSS Loader** (`SDH-CssLoader`); on 2026-10-09, **Colores** (v0.31.0) and
**Panel de Control** (v0.67.1), both by Hooandee.

**Colores (the controllers' RGB LEDs) needs `hidapi`** (2026-10-09). The plugin talks to the LEDs through
`libhidapi-hidraw.so.0`, which it loads with `ctypes`; SteamOS ships it and Void does not. Without it the plugin
disables all HID and says it does not detect a controller with RGB (its log,
`~/homebrew/logs/Colores/*.log`: `driver=NullDevice … available=False`). Fix: Void's official
package, and restart Decky so that the plugin loads again:

```bash
sudo xbps-install -S hidapi
sudo sv restart decky
```

Check: in the plugin's log, `Found Legion Go device: PID=0x61EB … usage_page=0xFFA0` and
`Successfully set Legion Go RGB`. The plugin runs as root (`flags: root`), so it opens the controller even though
InputPlumber has it hidden (`/dev/hidraw0`–`2` with permissions `000`), and they do not step on each other. After suspending
it sets the color again (`restored lighting after … suspend`), although it warns `No such file or directory:
'systemd-inhibit'` (Void does not have it; it does not matter). **Verified by the user on 2026-10-09**, also
after suspending.

