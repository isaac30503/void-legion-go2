# Wallpaper on Wayland

Three fixes so that `xfdesktop`'s wallpaper works in Xfce on Wayland with two screens (`eDP-1`, the Legion's, and
`DP-1`, the monitor). `xfdesktop` reads `/backdrop/screen0/monitor<connector>/workspace<N>/last-image`.

## The internal screen black after Game Mode: `wallpaper-watcher`

Coming from Game Mode, `xfsettingsd` applies the display profile **after** `xfdesktop` painted the wallpaper, and
the Legion's screen stayed black (cursor and windows fine). `~/.local/bin/wallpaper-watcher` (Python + GTK, from
labwc's `autostart`; installed by `install-xfce-wayland.sh`) waits **event-driven** for GTK's screen signals (added,
removed, geometry, scale) and, half a second after the last one, runs `xfdesktop --reload` once. Also when plugging
the monitor in or out.

**It also restarts `xfdesktop` when the number of screens or a scale changes** (2026-10-16): next to a 4K TV at
scale 2, `xfdesktop` 4.20.2 drew the Legion's 1× screen at scale 2 (the wallpaper zoomed in) and ignored new wallpapers
for it until restarted; `--reload` did not help. **And it puts the panels on the external screen:** xfce4-panel 4.20
names the screens with GTK's model, `Unknown` for every one on labwc, so `output-name` `DP-1` never matches and the
panel hides; it takes `monitor-<index>-<model>`, but a fixed one hides the panel when that screen is unplugged. So the
watcher picks the first screen that is not the built-in one (its physical size is the eDP panel's, from its EDID) and
sets `monitor-N-Unknown` on every panel, or removes `output-name` (Automatic) when the Legion's screen is alone.
`PANELS_ON_EXTERNAL=0` turns that part off.

**Screenshots lie about a scaled screen:** `xfce4-screenshooter -f` on labwc showed the panels of the TV at scale 2 at
twice their length and offset (the top bar's right half off screen, a centred panel at the right edge), while the TV
itself showed them right. A "fix" made from those captures broke the real panels (2026-10-16, undone): on a scaled
screen, check by looking at it, not with a capture.

**Check:** `~/.local/state/wallpaper-watcher.log` (redone every session), e.g. `vigilando 2 pantallas`, two
`geometry:` lines and `xfdesktop --reload (rc=0)`. On the spot: `xfdesktop --reload` or switch workspace. (Ruled out while finding it: HDR/VRR/color properties and the panel's self-refresh; `sudo sh "$B/legion/diag/diag-edp.sh" black|fine` compares amdgpu's state of the screen black and fine: identical.)

## The wallpaper dialog does nothing: patched xfdesktop

`xfdesktop` 4.20.2's dialog writes `monitorUnknown/…` on Wayland (it names the screen with
`gdk_monitor_get_model`), which `xfdesktop` never reads (upstream issue #350). The fix is **upstream's commit
`ed26b06a`** ("Use XfwMonitor in backdrop settings instead of GdkMonitor", Brian J. Tarricone; in the `xfce-4.20`
branch, not released yet), packaged as `xfdesktop-4.20.2_2` (Void's revision + 1):

```bash
sudo bash "$B/common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh"
```

The `.xbps` comes from the Release (sha256 `6f36c3908bd2ea75e834f268ce8194a58894c95e26f9c181d738d441579446d0`). To
build it again (without root; `xbps-src` in user namespaces; it **tests the patch first** and does not build if
Void already has it):

```bash
bash "$B/common/xfce-wayland/xfdesktop-wallpaper/build-xfdesktop.sh"   # → ~/src/void-packages/hostdir/binpkgs
```

**Check** (with the dialog closed before installing): `xfconf-query -c xfce4-desktop -m` in an xterm; open the
dialog **on each screen** and choose a wallpaper: `monitoreDP-1/…` or `monitorDP-1/…`, never `monitorUnknown`, and
that screen's wallpaper changes. The dialog takes the screen **when it opens** (dragged elsewhere it does not
notice: close it and open it on the other screen). `xbps-query -p pkgver xfdesktop` → `xfdesktop-4.20.2_2`.

## Thunar's "Set as wallpaper" does nothing: patched Thunar

Thunar's plugin has the same bug (`monitorUnknown`), with no upstream fix. **Our patch**
(`0001-wallpaper-use-the-monitor-connector-name.patch`) asks `libxfce4windowing` for the connector, like
`xfdesktop`, and keeps choosing the screen Thunar's window is on (`gdk_display_get_monitor_at_window`); packaged as
`Thunar-4.20.10_2`:

```bash
sudo bash "$B/common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh"
thunar -q                      # as the user: closes the Thunar with the old plugin
```

(sha256 of the `.xbps` `70ccff54505dd70d09f6cdd0d00925c8113a1810843d480da0c351bab060999b`; only `Thunar` is
installed, not `Thunar-devel`.) To build it: `bash "$B/common/xfce-wayland/thunar-wallpaper/build-thunar.sh"` (it adds
the `-devel` packages `libxfce4windowing`'s `.pc` needs, and fails if `configure` does not find it).

**Check:** right click on an image in Thunar → "Establecer como fondo de pantalla" ("Set as wallpaper") with Thunar on
each screen: `monitoreDP-1/…` / `monitorDP-1/…`, and the wallpaper changes. `xbps-query -p pkgver Thunar` →
`Thunar-4.20.10_2`. If it still fails: an update replaced it (`void-update --summary`), or an old Thunar is still
open (`pgrep -a thunar`).

## Updates

`void-update` **tests both patches against Void's current code** and says, in its summary, whether each one is still
needed, already included (with the command to go back to Void's package, `sudo xbps-install -Sf <package>`) or no
longer applies ([own patches](../8-maintenance/2-own-patches.md)). Meanwhile, without root, a wallpaper can be set by
hand: `xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor<connector>/workspace0/last-image -n -t string -s <image>`
(without `-n -t string` if the key exists).
