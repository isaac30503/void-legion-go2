### Wallpaper from Thunar on Wayland: patched Thunar (2026-10-09; installed)

**The same as on the IdeaPad** (its recipe, step 15, *Fondo desde Thunar en Wayland* (*Wallpaper from Thunar on Wayland*): the bug, the own
patch and the pieces of `common/xfce-wayland/thunar-wallpaper/`). In Xfce Wayland, Thunar's "Establecer como fondo de
pantalla" ("Set as wallpaper") writes to `monitorUnknown/…` (it uses `gdk_monitor_get_model`) and the wallpaper does not change; no
upstream fix on 2026-10-09. The patch asks `libxfce4windowing` for the connector (like `xfdesktop`) and
**still chooses the screen of Thunar's window** (`gdk_display_get_monitor_at_window`): here, with
two screens, `eDP-1` or `DP-1` depending on where the window is.

**Built here** on 2026-10-09: `Thunar-4.20.10_2` (Void's template was already 4.20.10_1, although the
mirror still gave 4.20.9_1; with 4.20.9 the next update would have replaced it without the patch), 1 min
2 s; `build-thunar.sh` run from `/tmp/thunar-wallpaper/` (no scripts in `~`). A first build
came out **without** `libxfce4windowing` (its `.pc` asks for wnck, xrandr and wayland-client in `Requires.private`):
the script adds those `-devel` and now **fails** if `configure` does not find it. `Thunar-4.20.10_2.x86_64.xbps`
(sha256 `70ccff54505dd70d09f6cdd0d00925c8113a1810843d480da0c351bab060999b`) and `Thunar-devel` copied to
`Common`; `~/src/void-packages` and `/tmp/thunar-wallpaper` of the build, deleted. **The same package**
installed on the IdeaPad. Only `Thunar` is needed (the plugin goes in it; `Thunar-devel` is not
installed).

**Installation** (root; from `/tmp`, already copied on 2026-10-09 together with the `xfdesktop` one; with
this repository, from the clone):

```bash
# on the Legion (asks for the password and to confirm):
sudo bash "$B/common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh"
thunar -q                      # as user: closes Thunar with the old plugin
# originally, from /tmp; if /tmp was emptied (reboot), from the IdeaPad or wherever Common is:
#   ssh lego mkdir -p /tmp/thunar-fondo
#   scp "<disk>/Backups Linux/fish/void/xfce-wayland/thunar-fondo/"{instalar-thunar-fondo.sh,Thunar-4.20.10_2.x86_64.xbps} lego:/tmp/thunar-fondo/
#   sudo bash /tmp/thunar-fondo/instalar-thunar-fondo.sh && thunar -q && rm -rf /tmp/thunar-fondo
```

**Check** (in Xfce Wayland): `xfconf-query -c xfce4-desktop -m` in an xterm; Thunar **on the Legion's
screen**, right click on an image → "Establecer como fondo de pantalla" ("Set as wallpaper"): `monitoreDP-1/…` and
the wallpaper of that screen changes; Thunar **on the external monitor**: `monitorDP-1/…` and that one's changes.
Never `monitorUnknown`. `xbps-query -p pkgver Thunar` → `Thunar-4.20.10_2`. **Verified on 2026-10-09 on both screens** (`monitoreDP-1` and `monitorDP-1`; without `monitorUnknown`). Unlike
the dialog, **dragging Thunar's window** to another screen is enough: it sets the wallpaper on the
one it is on at that moment. `void-update` watches it **by testing the patch** against Void's code (since
2026-10-09; before it assumed "fixed if Void's plugin links `libxfce4windowing`"), the same as
`xfdesktop`; `build-thunar.sh` also tests it before building (before, a `grep`).

