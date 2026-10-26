# Windows and shortcuts

Omarchy's shortcuts on a floating desktop, focus that follows the mouse **without raising**, new windows **almost
maximized** (8 px gap) and keyboard snapping to halves and quarters, **per monitor**. On Wayland it is all labwc's
`rc.xml` (`common/xfce-wayland/labwc/rc.xml`); on X11, xfwm4's settings plus three scripts
(`window-snap`, `window-focus`, `new-windows`).

## Shortcuts

| Keys | Does |
|---|---|
| Super+Enter | terminal (xterm) |
| Super+Shift+Enter, Super+Shift+B / Super+Shift+Alt+B | browser / private browser |
| Super+Shift+F / Super+Shift+N | files / editor (mousepad) |
| Super+Space / Super+Alt+Space | finder (`xfce4-appfinder`) / applications menu |
| Super+Escape | system menu (`xfce4-session-logout`) |
| Super+Ctrl+L | lock (X11 only: `xflock4` needs `xfce4-screensaver`) |
| Super+Ctrl+V | clipboard (Clipman) |
| Super+Ctrl+A / W / D / P / T / B | audio / network / display / power / activity (`btop`) / Bluetooth |
| Super+W, Super+Q, Alt+F4 | close window |
| Super+F / Super+Alt+F / Super+O | full screen / maximize / always on top |
| Super+1…5 / Super+Shift+1…5 | go to workspace / take the window there and follow it |
| Super+Tab / Super+Shift+Tab | next / previous workspace |
| **Super+← → ↑ ↓** | focus the window on that side |
| **Super+Shift+← → ↑ ↓** | snap: halves; chaining two arrows, corners; between the two halves, almost maximized |
| **Super+Shift+Space** | back to the home position (almost maximized; dialogs, fixed-size windows and the finder to the center) |
| Super+drag (left / right) | move / resize |
| Alt+Tab | window switcher with thumbnails |
| Print / Shift+Print / Ctrl+Print | screenshot (`xfce4-screenshooter`) |
| volume and brightness keys | `wpctl` and `brightness` on Wayland; Xfce's on X11 |

There are 5 workspaces (named "1"…"5"); Super+6…0 do nothing. Xfce's own shortcuts (Ctrl+Alt+T, Super+E…) keep
working, except Super+Tab, which now switches workspace.

**Snapping, exactly:** Super+Shift+arrow puts the window in that half; from a half, an adjacent arrow makes a
quarter; from a quarter, the opposite arrow grows it back to a half; **almost maximized is the step between the two
halves** (left half + → = almost maximized; again → = right half); **towards the edge nothing happens**; quarters
never go straight to almost maximized.

## Wayland: labwc's `rc.xml`

- Like xfwm4: 8 px gap (`<core><gap>`), new windows centered, **focus follows the mouse, raise only on click**
  (`followMouse` yes, **`raiseOnFocus` no**), Super+drag, 5 named workspaces, no workspace popup (`popupTime` 0),
  **`<xwaylandPersistence>yes`** (without it labwc closes Xwayland after 10 s without X programs and what `autostart`
  loaded with `xrdb` is lost: xterm without its theme).
- **New windows almost maximized:** a region **`full`** (the usable area) and a rule `identifier="*"` that snaps every
  new window to it; then `UnSnap` for `type="dialog"` (labwc's fixed-size and child windows) and `xfce4-appfinder`,
  which stay centered. (`type="normal"` does not work: XWayland windows without `_NET_WM_WINDOW_TYPE`, like xterm, do
  not count as normal.)
- **Super+Shift+arrows:** each arrow is a chain of `If`: a dialog → `MoveToEdge` (it moves to the edge without
  resizing); already on that side or one of its quarters (`query tiled="left"`, `"up-left"`, `"down-left"`) →
  `None`; on the opposite half → `SnapToRegion full`; in a quarter of the other side → `SnapToEdge` to its half;
  otherwise `SnapToEdge combine="yes"`. labwc cannot center dialogs on the other axis or release them by repeating
  the arrow: Super+Shift+Space puts them back in the center (`UnSnap` + `AutoPlace policy="center"`).
- **Super+arrows:** labwc's `<default/>` uses them to snap, so they are overridden; labwc has no focus by direction,
  so `ForEach` focuses and raises the window **snapped** on that side (`tiled="left"`…) of the current workspace; with
  none, ←/↑ previous window and →/↓ next (Alt+Tab's order).
- **Firefox and Steam: only labwc's border** (`SetDecorations decorations="border" forceSSD="yes"`): both draw their
  own bar. In Firefox, **"Barra de título" ("Title Bar") unchecked** (☰ → Más herramientas → Personalizar barra de
  herramientas… / More tools → Customize toolbar…): it is Firefox's default (`browser.tabs.inTitlebar` = 2,
  automatic); only a very old restored profile may have it checked.
- **Xfce's settings: only labwc's border too.** The settings manager and its dialogs are `XfceTitledDialog` windows,
  whose bar libxfce4ui 4.20 draws itself (CSD, no switch to turn it off): without a rule they had no frame and no
  teal focus border. Rules by app_id (the binary's name): `xfce4-settings-manager`, `xfce4-*-settings`,
  `xfwm4-*settings`, `xfdesktop-settings`, `thunar-volman-settings`, `xfce4-settings-editor`,
  `xfce4-screensaver-preferences`, `xfce4-notifyd-config`. **Not** Thunar, the panel, xfce4-terminal or the finder:
  they use that dialog only for secondary windows (preferences, properties), and "border" would take labwc's bar off
  their main windows. To see a window's app_id: the Docklike knows it (libxfce4windowing).
- **Exceptions at the end of `<windowRules>`:**

  ```xml
  <windowRule identifier="steam" type="utility">          <!-- Steam's on-screen keyboard -->
    <action name="UnSnap"/>
    <action name="SetDecorations" decorations="none"/>
  </windowRule>
  <windowRule identifier="screen-share">                    <!-- the screen-share chooser -->
    <action name="ToggleAlwaysOnTop"/>
    <action name="SetDecorations" decorations="none"/>
  </windowRule>
  ```

  Steam's keyboard is a `_NET_WM_WINDOW_TYPE_UTILITY` window (matched by type, not by its translated title); the
  chooser sets its identifier with `GLib.set_prgname` and, with focus without raising, it stayed behind the app
  asking ([screen sharing](../7-apps/1-screen-sharing.md)).
- Alt+Tab `style="thumbnail"` with `preview` and `outlines`; window buttons `menu:shade,iconify,max,close` like xfwm4.

Apply changes with `labwc --reconfigure`; to replace the file while labwc runs, `mv` it (not `cp` over it).

## X11: xfwm4 and the window scripts

- xfwm4: `click_to_focus` = false, `focus_delay` = 5, **`raise_on_focus` = false** (`xfconf-query -c xfwm4 -p /general/raise_on_focus -s false`), `placement_ratio` = 100 (new
  windows centered: with the default 20 only small ones were), `easy_click` = Super.
- **Omarchy's shortcuts that duplicate an xfwm4 action are `xdotool` commands** in `/commands/custom`: **xfwm4 keeps
  only ONE shortcut per action** (with two, one works at random after a restart). Check that no action repeats:
  `xfconf-query -c xfce4-keyboard-shortcuts -lv | grep '^/xfwm4/custom/' | awk '{print $2}' | sort | uniq -d` (empty).
- **Super+Shift+number is registered with the symbol Shift+number gives** in the active layout. US international:
  `exclam`, `at`, `numbersign`, `dollar`, `percent`, **`dead_circumflex`** (a dead key with `intl`), `ampersand`,
  `asterisk`, `parenleft`, `parenright` (read with `xkbcomp -xkb $DISPLAY -`). Each runs
  `xdotool getactivewindow set_desktop_for_window N set_desktop N`. **If the layout changes, redo them.**
- **`_NET_WORKAREA` is one rectangle for both screens** (3840×1200), so the scripts work **per monitor** (from
  `xrandr --listactivemonitors`, minus the panels on that monitor; needs the `xrandr` package):
  - **`window-snap left|right|up|down|full|home [window]`:** places the window itself (simulating keys for xfwm4
    fails while the real keys are held), adds the xfwm4 frame (`_NET_FRAME_EXTENTS`), subtracts the invisible shadow
    of GTK windows with their own bar (`_GTK_FRAME_EXTENTS`), only moves fixed-size windows, respects minimum sizes,
    records where it sent each window (`$XDG_RUNTIME_DIR/window-snap/<id>`) and moves the pointer to the window (the
    focus follows the mouse). The 8 px gap is `GAP=8` at the top of the script.
  - **`window-focus left|right|up|down`:** the closest normal window that way on the same monitor (distance + 2 ×
    lateral offset), moving the pointer there first (with Super held, `xdotool windowactivate` alone is ignored);
    windows without `_NET_WM_WINDOW_TYPE` (xterm) count as normal.
  - **`new-windows`** (autostart): every new window opens almost maximized on its monitor, **event-driven**
    (`xprop -spy -root _NET_CLIENT_LIST`); not dialogs, child or fixed-size windows, the finder or full-screen games;
    one per session (`flock`); **on Wayland it exits at once** (labwc's rules do it).
- X11 limit: xfwm4's workspaces are shared by the two monitors.
