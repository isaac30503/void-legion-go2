### Desktop wallpaper on Wayland: patched xfdesktop (2026-10-09; installed)

**The same as on the IdeaPad** (its recipe, step 15, *Fondo de escritorio en Wayland* (*Desktop wallpaper on Wayland*): the bug, the
upstream commit `ed26b06a` and the pieces of `common/xfce-wayland/xfdesktop-wallpaper/`). In Xfce
Wayland the wallpaper dialog of `xfdesktop` 4.20.2 writes to `/backdrop/screen0/monitorUnknown/…` and
`xfdesktop` reads `monitor<connector>/…`: choosing a wallpaper does nothing. **Here there are two screens**, each one
with its connector: **`eDP-1`** (the Legion's) and **`DP-1`** (the external monitor; in
`/sys/class/drm/card0-*` on 2026-10-09). That day only `monitoreDP-1/workspace0/last-image` existed
(`xfce-x.svg`); no key for `DP-1`.

**Built here** on 2026-10-09 (2 min 47 s with `binary-bootstrap`): `build-xfdesktop.sh` run
from `/tmp/xfdesktop-wallpaper/` (no scripts in `~`), `xfdesktop-4.20.2_2.x86_64.xbps` (Void's revision +
1; sha256 `6f36c3908bd2ea75e834f268ce8194a58894c95e26f9c181d738d441579446d0`) copied to `Common`, and
`~/src/void-packages` and `/tmp/xfdesktop-wallpaper` deleted. It is **the same package** installed on the
IdeaPad.

**Installation** (root; `Common` is usually not mounted here, so it goes from `/tmp`; with this
repository, from the clone, where `install/fetch-assets.sh` left the package next to the installer):

```bash
# on the Legion (asks for the password and to confirm):
sudo bash "$B/common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh"
# originally: on the IdeaPad (or wherever Common is), copy the installer and the package to the Legion's /tmp,
#   scp "<disk>/Backups Linux/fish/void/xfce-wayland/xfdesktop-fondo/"{instalar-xfdesktop-fondo.sh,xfdesktop-4.20.2_2.x86_64.xbps} lego:/tmp/xfdesktop-fondo/
# then on the Legion, and delete when done:
#   sudo bash /tmp/xfdesktop-fondo/instalar-xfdesktop-fondo.sh
#   rm -rf /tmp/xfdesktop-fondo
```

**Check** (in Xfce Wayland, with the wallpaper dialog closed before installing): in an xterm,
`xfconf-query -c xfce4-desktop -m`; open the dialog **on the Legion's screen** and choose a wallpaper:
`/backdrop/screen0/monitoreDP-1/workspace<N>/last-image` must show up and the wallpaper of that screen must change;
take the dialog **to the external monitor** and choose another: `monitorDP-1/…` and that one's changes (the dialog
takes the screen **when it opens**: dragged to the other one it does not notice; you have to close it and open it on the screen
you want, checked on 2026-10-09). Never `monitorUnknown`. `xbps-query -p pkgver xfdesktop`
→ `xfdesktop-4.20.2_2`. **Verified on 2026-10-09 on both screens** (`monitoreDP-1` and `monitorDP-1`, each one with its wallpaper;
without `monitorUnknown`). `void-update` watches it **by testing the patch** against Void's code (since
2026-10-09; before it assumed "fixed in >= 4.20.3"): OK while it is needed, NOTA (NOTE) with the command to go back
to Void's if it already has it, AVISO (WARNING) if it does not apply (IdeaPad recipe, step 6, *Prueba de parches propios* (*Testing own patches*)).

