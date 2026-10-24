# Xfce with mangowc

**The desktop since 2026-10-23, IdeaPad first** (a trial that same morning; the user preferred it to labwc). The same Xfce as [Xfce on Wayland](1-xfce.md) (panel, `xfdesktop`,
`xfsettingsd`, Thunar), with **mangowc** placing the windows instead of labwc, in **Omarchy's two layouts, per
workspace** (Super+L): *dwindle* (each new window splits the focused one) and *scroller* (columns), with Omarchy's
keybindings. Where its session is installed, `switch-mode-root desktop` (Game Mode's "Switch to Desktop") enters it;
labwc stays one more mode (`switch-mode-root desktop-labwc`, launcher "Escritorio labwc"). Without it (the Legion until
it is installed there), `desktop` is still labwc.

## Why mangowc

What was wanted: Omarchy's dwindle — the new window goes to the right of the focused one, the next one below it, then
right, then down, **following the focus** — on a compositor as light as labwc on the IdeaPad (HD 5500, 4 threads,
8 GB, spinning disk). Looked at on 2026-10-23, running each one nested (`WLR_BACKENDS=wayland`) from Void's packages:

- **niri** (tried first, as its own session the same day): only scrolling columns of stacked windows, no tree of
  splits, so **real dwindle is impossible** (also said by its users: no plan upstream). A daemon of ours
  (`niri-tile`, master + stack through niri's IPC) got close but not there, and niri's workspaces reached Xfce's pager
  in random order (libxfce4windowing 4.20 ignores the coordinates). Removed.
- **sway + `autotiling`** (a Python daemon that sets the split of the focused window by its shape): real dwindle,
  following the focus; about 95 MB plus ~25 MB of the daemon, and a split set after the window is mapped.
- **mangowc** (dwl-based, wlroots 0.20 + scenefx): **dwindle built in** (the focused window splits along its longer
  side), and **scroller, tile, monocle, grid…** per tag, switchable with a key; about 100 MB, like sway. Its effects
  (blur, shadows, rounded corners, animations) come from scenefx and cost only when on: **all off here**.
- swayfx: sway with the same scenefx effects; with them off it draws like sway. Hyprland and COSMIC are not in Void.

Void: `mangowc` 0.17.5 (pulls `scenefx` and `cJSON`; `wlroots0.20` was already there). Xwayland is built in, as in
labwc (no `xwayland-satellite`). **Its keywords are those of the config it brings (`/etc/mango/config.conf`)**, not
always those of the online wiki, which is newer (e.g. `tagrule=`, not `tag_rule=`).

## Install

```sh
sudo sh common/steam/install-passwordless-switch.sh   # switch-mode-root with desktop-mango/-labwc (keeps the mode)
sudo sh common/xfce-wayland/install-xfce-wayland.sh     # needed first; its launcher is now "Escritorio labwc"
sudo sh common/xfce-wayland/install-xfce-mango.sh
```

`install-xfce-mango.sh` (needs `install-xfce-wayland.sh` for `brightness` and `wallpaper-watcher`):

- installs `mangowc`;
- `~/.config/xfce4/mango/config.conf` from `common/xfce-wayland/mango/config.conf`, with the keyboard of
  `/etc/X11/xorg.conf.d/00-keyboard.conf` (as labwc's `environment`); checked with `mango -c … -p` before replacing
  the old one;
- `/usr/local/bin/startxfce4-mango` and `/usr/share/wayland-sessions/xfce-mango.desktop` (the session);
- the launcher "Escritorio mango" (`desktop-mango.desktop`);
- **removes niri's trial**: its session, launcher, `niri-tile` and `~/.config/xfce4/niri`, and moves the chosen mode
  from `xfce-niri` to `xfce-mango`. The packages stay until you leave niri's session (its logout needs `niri msg`):
  then `sudo xbps-remove niri xwayland-satellite`.

Enter: finder (Super+Space) → **Escritorio mango**, or Game Mode's "Switch to Desktop". labwc: **Escritorio labwc**. Like the other modes, never from
the login screen.

## How the session starts

`startxfce4-mango` runs `startxfce4 --wayland mango -c ~/.config/xfce4/mango/config.conf -s startxfce4-mango`:
`startxfce4` sets the Wayland environment and the D-Bus session, as for labwc; mango runs the same script again, which
sees `MANGO_INSTANCE_SIGNATURE` (mango's socket) and:

- puts `WAYLAND_DISPLAY`, `DISPLAY` and `XDG_CURRENT_DESKTOP=XFCE` in D-Bus's activation environment (mango does not,
  labwc does);
- runs `xfce4-session`, and when it ends, `mmsg dispatch quit`: **mango does not end when its `-s` command ends**
  (checked nested), and lightdm would never see the session end.

Why the same script: **`startxfce4` and `xinitrc` split the compositor's command on spaces without quotes**, so
neither `sh -c '…'` nor `-s "script --inside"` survive.

In the configuration: `env=XDG_CURRENT_DESKTOP,XFCE` (mango sets `mango` for what it starts, and Xfce's `.desktop`
files with `OnlyShowIn=XFCE` vanished from the finder and the menu — seen with niri), `exec-once=` for `xrdb` and
`wallpaper-watcher` (through `sh`), and `xwayland_persistence=1` (labwc's `xwaylandPersistence`). The cursor needs both `cursor_theme=volantes_cursors` (mango's own: desktop, borders, programs that ask it for a shape) and `env=XCURSOR_THEME,…` (what mango starts): with only the second, the session started with mango's default cursor.

## Two layouts per workspace

mango's workspaces are **tags 1–9**, fixed (Xfce's pager shows them in order). Each starts in **dwindle**
(`tagrule=id:N,layout_name:dwindle`); **Super+L** (`switch_layout`) cycles the focused one through
`circle_layout=dwindle,scroller`.

- ***dwindle***: the new window splits the **focused** one along its longer side (`dwindle_hsplit=1`,
  `dwindle_vsplit=1`, no smart split): on a wide screen right, then down, then right… Super+J
  (`dwindle_toggle_split_direction`) turns the focused split, and stays (`dwindle_preserve_split=1`).
- ***scroller***: every column at full width (it was 80 % until the user asked for the largest, 2026-10-23); Super+Shift+R cycles 50/80/100 %.
- Omarchy's third, *floating*: Super+T per window.

## Using it

The complete list of what the session does, as in `~/.config/xfce4/mango/config.conf`. **Super** is the Windows
key. Most are **Omarchy's** (`default/hypr/bindings/tiling.lua`, read on 2026-10-23) where mango has the action; the
programs are labwc's. Workspace and resize keys go **by keycode** (`code:10` = 1…), as Omarchy's: the same physical
keys with `latam` (IdeaPad) and with `us` + `intl` (Legion).

### How it behaves

- **Workspaces:** nine, fixed, 1–9; Xfce's pager shows them in order.
- **Layout per workspace**, each starting in **dwindle**; **Super+L** switches it to **columns** (scroller) and back.
  - **Dwindle:** each new window splits **the focused one** along its longer side: on a wide screen right, then
    down, then right… Focus another window and the next one splits that one.
  - **Columns:** every column at full width; one alone, too.
- **Focus follows the mouse**; when the keyboard moves the focus, the pointer jumps to that window.
- **Floating:** the application finder always floats; any other window with Super+T.

### Windows

| Keys | What it does |
|---|---|
| Super+W · Super+Q · Alt+F4 | Close the window |
| Super+←/→/↑/↓ | Focus the window on that side |
| Super+Shift+←/→/↑/↓ | Swap the window with the one on that side |
| Alt+Tab · Alt+Shift+Tab | Next / previous window (no previews) |
| Super+J | Turn the focused window's split: side by side ↔ one above the other (dwindle; it is kept) |
| Super+T | Floating ↔ tiled |
| Super+F · Alt+F11 | Full screen |
| Super+Ctrl+F | "Fake" full screen: the program believes it is full screen and stays in its place (shows only in programs that change then, as a video in Firefox; nothing in xterm) |
| Super+Alt+F · Alt+F10 | Maximize (the whole area, without covering the panel) |
| Super+O | Pin the window to every workspace (again to unpin) |
| Super+M · Super+Shift+M | Minimize / bring back the last minimized one |

### Size

The two keys right of 0: **'** and **¿** on `latam`, **-** and **=** on `us`.

| Keys | What it does |
|---|---|
| Super+' · Super+¿ (`us`: Super+- · Super+=) | Narrower / wider (100 px) |
| Super+Shift+' · Super+Shift+¿ (`us`: - · =) | Shorter / taller (100 px) |
| Super+Alt+' / ¿ (`us`: - / =) | Width 25 px at a time |
| Super+Ctrl+' / ¿ (`us`: - / =) | Width 300 px at a time |
| Super+Shift+R | Columns: the focused column's width goes 50 % → 80 % → 100 % |
| Super+Shift+Space | Columns: full width |

### Workspaces and monitors

| Keys | What it does |
|---|---|
| Super+1…9 | Go to that workspace |
| Super+Shift+1…9 | Take the window there and follow it |
| Super+Shift+Alt+1…9 | Send the window there and stay |
| Super+Tab · Super+Shift+Tab | Next / previous workspace |
| Ctrl+Alt+← / → | Previous / next workspace |
| Super+wheel up / down | Previous / next workspace |
| Super+L · Super+Alt+L | This workspace's layout: dwindle ↔ columns |
| Ctrl+Alt+Tab | Focus to the other monitor (Legion) |
| Super+Shift+Ctrl+← / → | Take the window to the monitor on that side |
| Super+0 | Nothing (mango has nine workspaces; see below) |

### Scratchpad

In mango the scratchpad is the minimized windows.

| Keys | What it does |
|---|---|
| Super+Alt+S | Send the window to the scratchpad |
| Super+S | The focused one is a scratchpad window → it goes back; one there → it comes; several → a list: type to filter, Enter brings it, Esc nothing |

The window comes floating and centered; Super+T puts it back in the tiling.

### Mouse

| Gesture | What it does |
|---|---|
| Super+left drag | Move the window (a tiled one floats) |
| Super+right drag | Resize |
| Trackpad | Tap = click; tap and drag = drag; off while typing |

### Programs (the same as labwc's)

| Keys | Opens |
|---|---|
| Super+Return · Ctrl+Alt+T | Terminal (xterm) |
| Super+Ctrl+T | btop |
| Super+Shift+Return · Super+Shift+B | Web browser |
| Super+Shift+Alt+B | Firefox, private |
| Super+E · Ctrl+Alt+F | Thunar |
| Super+Shift+F | Default file manager |
| Super+Shift+N | Mousepad |
| Super+Space · Alt+F3 | Application finder |
| Super+R · Alt+F2 | Finder, "run" mode |
| Super+Alt+Space · Alt+F1 | Applications menu |
| Super+Ctrl+A | Volume (pavucontrol) |
| Super+Ctrl+B | Bluetooth (blueman) |
| Super+Ctrl+D · Super+P | Displays (full / quick) |
| Super+Ctrl+P | Power |
| Super+Ctrl+V | Clipboard history (Clipman) |
| Super+Ctrl+W | Network connections |
| Ctrl+Shift+Escape | Task manager |
| Super+Escape · Ctrl+Alt+Delete | Xfce's log out / shut down / reboot (it asks first) |
| Print · Shift+Print · Alt+Print | Screenshot: whole screen / region / window |
| Volume, mute and microphone keys | `wpctl` |
| Brightness keys | `brightness`, 10 at a time |

### Switching modes

- Game Mode's **"Switch to Desktop"** (and `switch-mode-root desktop`) comes here.
- Super+Space → **"Escritorio labwc"**: Xfce with labwc; **"Escritorio mango"**: back here; **"Modo Juego"**: Steam;
  **"Escritorio X11"**: the fallback.
- At power-on it enters the last mode used.

### In the terminal

```sh
mmsg get layouts                      # mango's layouts
mmsg get all-tags                     # the workspaces and their layout
mmsg get focusing-client              # the focused window
mmsg dispatch switch_layout           # the same as Super+L
mmsg dispatch reload_config           # reload the configuration after editing it
mango -c ~/.config/xfce4/mango/config.conf -p   # check the configuration before reloading
```

To change something, edit `common/xfce-wayland/mango/config.conf` in the clone and run `install-xfce-mango.sh`
again: the installer replaces `~/.config/xfce4/mango/config.conf`.

### Compared with Omarchy

Not there: the groups (Super+G, tabs), Super+K (list of shortcuts) and Super+0 (workspace 10: mango has nine,
`tag_num=10` is refused). Ctrl+Alt+Delete is Xfce's log out (Omarchy: close all windows), as in labwc; Super+O pins
the window to every workspace (Omarchy also floats it). **Do not bind mango's overview (`toggleoverview`)**: tried on
Super+0 on 2026-10-23, it crashed mango 0.17.5 in the session (segmentation fault in `~/.xsession-errors`), and every
program with it; nested it had worked.

**How the scratchpad works (`~/.local/bin/mango-scratchpad`).** mango's `toggle_scratchpad` shows the minimized
windows one at a time, in its order: with several, you had to go through them. Super+S runs `mango-scratchpad`
instead. Its list is `fzf` in a small floating xterm titled `mango-scratchpad` (it keeps the `XTerm` class:
`~/.Xresources` goes by class, and a `-class` of its own left it without the theme). **Only one list at a time**: its
xterm holds a lock (`$XDG_RUNTIME_DIR/mango-scratchpad.lock`) until it closes, and Super+S meanwhile focuses it.
mango 0.17.5 cannot show one by id (`toggle_scratchpad client,<id>` ignores the id, checked nested), so it goes round
`toggle_scratchpad` until the chosen one is shown.

## Known limits

- First written and checked nested on 2026-10-23 (configuration with `mango -p`, dwindle and scroller, `env=`,
  `exec-once`, `mmsg dispatch quit`); in use the same day. Fixed after the first try: Super+J (it used
  `dwindle_toggle_split_direction`, which only acts with `dwindle_manual_split=1`) and Super+S; Super+0 (overview)
crashed the session and was removed.
- Monitor shortcuts (`focusmon`, `tagmon`) checked only nested with two outputs (`WLR_WL_OUTPUTS=2`).
- No screen lock (as with labwc: `xfce4-screensaver` is X11).
- **Wallpaper of a second screen** (the Legion's monitor): it did not change until `wallpaper-watcher` learned two
  things for mango (2026-10-23; [wallpaper](4-wallpaper.md)): the single-workspace mode when it is missing (mango has
  one group of workspaces per screen) and an `xfdesktop --reload` after every wallpaper change.

## Remove

```sh
sudo sh common/xfce-wayland/install-xfce-mango.sh --remove   # session, launcher, ~/.config/xfce4/mango (not mangowc)
sudo xbps-remove mangowc
```

It refuses while mango is the chosen mode: first **Escritorio labwc**. Without its session, `switch-mode-root desktop`
goes to labwc again by itself.

**Check:** `mango -c ~/.config/xfce4/mango/config.conf -p`; in the session, `pgrep -a mango`, `mmsg get layouts`,
`mmsg get all-tags` and `cat /proc/$(pgrep -x xfce4-session)/environ | tr '\0' '\n' | grep XDG_CURRENT`.
