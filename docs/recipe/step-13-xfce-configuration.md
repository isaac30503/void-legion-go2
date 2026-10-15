## 13. Xfce configuration and per-monitor windows

**With the session closed** (Log out and stay at the login screen; from SSH works, there is no
need for Ctrl+Alt+F2). Before logging out, if `Common` could be unmounted on exit,
copy what is needed to `~/.cache`. Then:

```bash
pkill -u isaac -x xfconfd
L="$B/legion"; X="$B/common/xfce"     # originally: L="<disk>/Backups Linux/fish/void/legion"; X="…/fish/void/xfce"
mkdir -p ~/.config/xfce4/xfconf ~/.config/gtk-3.0 ~/.local/bin ~/.config/autostart
cp -r "$L/xfce/xfce-perchannel-xml" ~/.config/xfce4/xfconf/
cp -r "$L/xfce/panel" ~/.config/xfce4/
cp "$L/xfce/gtk.css" ~/.config/gtk-3.0/gtk.css
cp "$X/"{window-snap,window-focus,new-windows} ~/.local/bin/ && chmod +x ~/.local/bin/{window-snap,window-focus,new-windows}
cp "$X/new-windows.desktop" ~/.config/autostart/
rm -f ~/.local/bin/{ventana-acoplar,ventana-foco,ventanas-nuevas} ~/.config/autostart/ventanas-nuevas.desktop   # the old Spanish names, if they are there (otherwise two watchers run)
```

> **In this repository:** `legion/xfce/xfce-perchannel-xml/xfce4-panel.xml` contains the Wi-Fi name
> (`@WIFI_SSID@`, in remembered tray tooltips) and the keyboard shortcuts carry `@TARGET_HOME@`: that is
> why the block copies from `"$B"` (rendered).

`legion/xfce/` is the IdeaPad configuration (step 13 of its recipe: themes, panels, Docklike,
Omarchy shortcuts, focus, `gtk.css`) **with the Legion's own things**:

- **The Legion's `displays.xml`**, not the IdeaPad's (which describes its 1366×768 screen). The
  first time the IdeaPad's was restored and the one the Legion's session had created was put back.
  **Since 2026-10-05 the backed-up one is the Wayland session's:** labwc calls the outputs
  `DP-1` (monitor, `0,0`, 1920×1080 at 60 Hz) and `eDP-1` (Legion, `1920,0`, 1920×1200 at 144 Hz); X11,
  `DisplayPort-0` and `eDP`. When Wayland was used, `xfsettingsd` rewrote the `Default` profile and the
  X11 entries disappeared. In the backup X11 session, arrange the screens once in
  *Configuración → Pantalla* (*Settings → Display*) (monitor on the left).
- **Copy of `legion/xfce/` brought up to date on 2026-10-05** (it was the one from 2026-10-03), copied from the
  running Legion: besides `displays.xml`, Num Lock active on login (`keyboards.xml`), the
  Clipman notifications (`xfce4-notifyd.xml`), the known tray icons (`nm-applet`,
  `blueman`, `steam`, in `xfce4-panel.xml`) and window sizes of Thunar and of the settings
  manager. `panel/` and `gtk.css` had not changed. The previous copy stays in
  `legion/xfce/xfce-perchannel-xml.bak/`. **Again on 2026-10-07** (full review): only
  `xfce4-panel.xml` (the tray already knows Vesktop's icon, `vesktop_status_icon_1`) and `xfwm4.xml`
  (with `raise_on_focus` = false, already backed up); the rest was identical to the Legion (except the state of
  Thunar's windows and `ristretto.xml`, which are not saved).
- **Super+Shift+1…0 shortcuts with the US international symbols.** xfwm4 registers them with the
  symbol that Shift+number gives (in `latam` they were `exclam`, `quotedbl`…). Read from the
  active layout (`xkbcomp -xkb $DISPLAY -`, keys `<AE01>`…`<AE10>`), not from memory: `exclam`, `at`,
  `numbersign`, `dollar`, `percent`, **`dead_circumflex`** (with `intl`, Shift+6 is a dead key, not
  `asciicircum`), `ampersand`, `asterisk`, `parenleft`, `parenright`. Each one:
  `xdotool getactivewindow set_desktop_for_window N set_desktop N` (N = 0…9). Done with
  `xfconf-query` (live): first `-r` of the ten old ones and then `-n -t string -s` of the
  new ones (Shift+7 was `ampersand` in `latam` and now it is Shift+7 → all are deleted before creating).
- **Super+Shift+Space** → `window-snap home` (new, see below).

> **In this repository:** `legion/xfce/xfce-perchannel-xml.bak/` (the previous copy) is not included: git
> history replaces the `.bak` copies.

### Per-monitor and almost-maximized windows (2026-10-03)

With the external monitor, the IdeaPad shortcuts split the window between the two screens:
**`_NET_WORKAREA` is a single rectangle for the whole desktop** (here 3840×1200). The scripts
(common to both machines, in `common/xfce/`; with a single screen they behave the same):

- **`window-snap left|right|up|down|full|home`**: works on the **window's monitor**. Its
  rectangle comes from `xrandr --listactivemonitors` and only the panels (`DOCK` windows
  with `_NET_WM_STRUT_PARTIAL`) that fall on it are subtracted: external monitor → `0,26 1920×1054`
  (top panel); the Legion's screen → `1920,0 1920×1200` (no panel). Without `xrandr`, the
  whole desktop, as before. **Almost maximized ("llena" / "full" region) is the intermediate step between the two halves**, inside
  the monitor (2026-10-03): left half + → = full; full + → = right half (same with
  ↑/↓). **Towards the edge it does nothing** (← on the left half, or outwards from a quarter),
  and **quarters never go to full** with arrows: inwards they grow to the half. (Before it was
  repeating the arrow outwards, "as if leaving the monitor": not intuitive.) Same in labwc (step 15 of the IdeaPad).
  Checked with an xterm (←, ←, →, →, →, ↑, →, ←, ↓, ←, ↓ → full, left half, nothing, full, right
  half, nothing, top-right quarter, nothing, top half, full, left half, bottom-left quarter).
  Super+Shift+Space (`inicio`) → "full", or to the center if it is a dialog, fixed-size or the finder.
  - **Windows with a big minimum size** (e.g. *Preferencias del panel* / *Panel Preferences*, 562×625): they do not reach the
    requested size and the state, deduced by measuring, came out wrong (erratic behavior). Now
    their minimum is used, stuck to the edge it touches (right/bottom), and **where each
    window was sent is recorded** (`$XDG_RUNTIME_DIR/window-snap/<id>`: destination and geometry without frame, as
    `getwindowgeometry` gives it); if it is still there (±20 px), what was recorded is valid. Checked with *Panel
    Preferences*: →, ↓, ←, ↑, ↑, →, → give full, bottom half, corner, left half, corner,
    top half, corner, without leaving the monitor.
- **`window-focus`**: Super+arrows only jumps between windows **of the same monitor**.
- **`new-windows`** (autostart `new-windows.desktop`): every **new** window opens almost
  maximized on its monitor, like the labwc rule. **Event-driven:** `xprop -spy -root
  _NET_CLIENT_LIST` (no periodic queries). It does not touch those that were already there at start, the non-
  normal ones (without type, like xterm, counts as normal), dialogs and windows with a parent, the
  fixed-size ones, `xfce4-appfinder` nor those that open fullscreen (games). A single copy
  per session (`flock`). **In a Wayland session it exits without doing anything** (`WAYLAND_DISPLAY`): labwc's
  also declares itself XFCE and would start the autostart, but there its rules do it. Checked: a new xterm opened at `8,34 → 1912,1072` (8 px gap and
  below the panel); the finder, centered and untouched.
- **Needs `xrandr`**, which Void does not install with Xfce. On 2026-10-03 it was installed by hand
  (`sudo xbps-install -Sy xrandr`); the backed-up `desktop-1-root.sh` already includes it.
- **X11 limit with no fix:** xfwm4's workspaces are **shared by the
  two monitors** (Super+1…5 switches both screens at once).
- **Bottom panel:** always hidden (`autohide-behavior` = 2). While *Panel Preferences* is open,
  Xfce leaves it visible to show which one is being edited.

After changing something of Xfce on the Legion, copy again `xfce-perchannel-xml/`, `panel/` and
`gtk.css` to `legion/xfce/` (not to `common/xfce/`, which is the IdeaPad's).

**Copying from Claude Code over SSH** (2026-10-03): `.Xresources` (common, `common/xterm/`)
allows OSC 52 only for putting text in the clipboard (`disallowedWindowOps` without `SetSelection`);
detail in the IdeaPad recipe, step 11. Shift + drag selects on top of Claude Code.

