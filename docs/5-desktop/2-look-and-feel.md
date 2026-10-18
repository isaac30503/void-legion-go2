# Look and feel

All of it is restored by the [Xfce install](1-xfce.md); this page says what each piece is, where it lives and how to
redo it.

| Setting | Value |
|---|---|
| GTK and window theme | **Orchis-Teal-Dark-Compact** (in `~/.themes`; for labwc, generated in `~/.local/share/themes/…/labwc`) |
| Icons | **Papirus-Dark** with **teal** folders |
| Font (UI, monospace, titles) | **JetBrainsMono NFM Blocks** Bold 10 (titles Bold 9); `hintfull`, no subpixel, 96 DPI |
| Cursor | **Volantes** (`volantes_cursors`, dark), size 24 |
| Terminal | **xterm**, everywhere |
| Wallpaper | Xfce's `xfce-mouserace.svg` (from xfdesktop, in `/usr/share/backgrounds/xfce/`), zoomed to fill; no desktop icons |

## Fonts

The whole **JetBrainsMono Nerd Font** family (96 files: `Nerd Font`, `Mono`, `Propo`, each also `NL`; a Release
asset, unpacked into `common/fonts/`) and **JetBrainsMono NFM Blocks**, a patched copy (in
`common/xterm/jetbrains-blocks/`, regenerated with its `regenerate.sh`) that seals the rows of `█` in xterm; it is
also the desktop's and the login screen's font. **No JetBrains variant has `⏺` (U+23FA), `⎿` (U+23BF)** (Claude
Code's) **or emoji**: fontconfig takes them from `adwaita-fonts` (Adwaita Mono), `twemoji` and `noto-fonts-ttf`;
without them xterm draws a crossed-out box. Emoji come out in black and white in the terminal (FreeType draws
Twemoji's fallback version), as preferred.

Check: `fc-list | grep -ci jetbrains` → 100 (104 after the login screen's copy);
`fc-match "JetBrainsMono NFM Blocks:charset=23fa" family` → `Adwaita Mono`.

## Icons, theme and cursor

- **Papirus teal folders:** `sudo papirus-folders -C teal --theme Papirus-Dark`. It changes links inside
  `/usr/share/icons/Papirus*`, so **an update of `papirus-icon-theme` may bring the default color back**: repeat it.
  Check: `readlink /usr/share/icons/Papirus-Dark/48x48/places/folder.svg` → `folder-teal.svg`. The application finder
  stays resident with the old icons until `pkill -x xfce4-appfinder`.
- **Orchis** is not in Void: restored from `orchis-themes.tar.gz` (the six `Orchis-Teal-Dark*` variants its
  `install.sh` produced; tag `2026-07-07`). It is not updated by `void-update`. To update:

  ```bash
  sudo xbps-install -Sy sassc gtk-engine-murrine
  git clone --depth 1 https://github.com/vinceliuice/Orchis-theme.git /tmp/Orchis-theme
  cd /tmp/Orchis-theme && ./install.sh -t teal -c dark
  cd ~ && rm -rf /tmp/Orchis-theme
  ```

  and redo the copy (`tar czf orchis-themes.tar.gz -C ~/.themes .`), the login screen's copy and the labwc theme
  (`bash "$B/common/xfce-wayland/labwc-theme.sh"`). Check: `ls ~/.themes` → the six `Orchis-Teal-Dark*` variants.
- **Volantes** is not in Void either: the built dark variant linked by its project (xfce-look.org), restored from
  `volantes-cursors.tar.gz` (relative paths, 148 cursors). Building it needs Inkscape and `xcursorgen`
  (`make build && make install PREFIX=$HOME/.local`).
- **labwc theme** (`labwc-theme.sh`, run by the Wayland installer, without root): built from Orchis' xfwm4 theme
  (buttons renamed as labwc wants, title bar 34 px `#2C2C2C`/`#333333`, focused border teal `#4DB6AC`; Alt+Tab and
  popups with the bottom panel's colors, `#212121a6`).

## Panels

| Panel | Plugins, in order |
|---|---|
| `panel-1` (top, opaque black) | applications menu, workspaces, **Docklike**, clock, **Clipman**, volume, tray, power, **Exit** |
| `panel-2` (bottom, **always hides**) | show desktop, 4 launchers, folders menu |

Docklike's options are in `~/.config/xfce4/panel/docklike-2.rc` (no window list for a single window, only this
workspace and screen). **Exit** is a launcher (`plugin-23`, `exit.desktop`: `Icon=system-shutdown-symbolic`,
`Exec=xfce4-session-logout`), because the Actions plugin's icon cannot be changed. xfce4-power-manager's tray icon
is hidden (the power plugin is in the panel); its own power-button action is "nothing"
([power button](../3-hardware-support/2-power.md#power-button)).

**`~/.config/gtk-3.0/gtk.css`** (what has no graphical option; after changing it, `xfce4-panel -r`):

| Rule | Does |
|---|---|
| `#XfcePanelWindow.panel-2 { border-radius: 14px }` | rounded bottom panel (needs the compositor: xfwm4's `use_compositing`, or labwc) |
| `#XfcePanelWindow.panel-2 button { border-radius: 12px; margin: 2px }` | its buttons' highlight, concentric with the panel |
| `#pager-20 button` / `:checked` / `:checked label` | the active workspace as a white circle with a black number |
| `#power-manager-plugin-19 label` | battery in the clock's font (JetBrainsMono NFM Blocks, bold, 10 pt) |
| `#panel_window { background-color: #000000 }` + `#panel_window label` | the black bar of `xfce4-screensaver`'s unlock screen, like the login screen's |

The plugin numbers come from the restored panel configuration; if the panel is rebuilt by hand, check them with
`xfconf-query -c xfce4-panel -lv | grep '^/plugins/plugin-[0-9]* '`. xfwm4's dock shadow is off
(`show_dock_shadow` = `false`): it is rectangular and showed outside the rounded corners.

## Terminal: xterm

- **`~/.Xresources`** (`common/xterm/Xresources`, loaded by `/etc/lightdm/Xsession` on X11 and by labwc's `autostart`
  in Xwayland; needs `xrdb`): Super Game Bro palette, JetBrainsMono NFM Blocks, `108x35`, login shell (→ fish),
  **Ctrl+Shift+C / Ctrl+Insert** copy and **Ctrl+Shift+V / Shift+Insert** paste (the clipboard; the mouse selection
  with the middle click), `backarrowKey: false` (Backspace sends `^?`: otherwise xbps's and sudo's prompts typed
  `^H`), OSC 52 allowed only to *set* the clipboard. Open windows do not take new resources: open a new one.
- **Window icon:** Papirus' terminal icon as XPM (`XTerm*iconHint`), because xfwm4 does not take it from the
  `.desktop`. If the icon theme changes, regenerate it:

  ```bash
  rsvg-convert -w 48 -h 48 -o /tmp/xterm-papirus.png /usr/share/icons/Papirus-Dark/48x48/apps/utilities-x-terminal.svg
  magick /tmp/xterm-papirus.png ~/.local/share/icons/xterm-papirus.xpm && rm /tmp/xterm-papirus.png
  ```

- **The default terminal for everything:** `~/.config/xfce4/helpers.rc` (`TerminalEmulator=xterm`, for `exo-open`),
  `~/.local/bin/xdg-terminal-exec` (a substitute for GTK apps' `Terminal=true`; Void does not package the real one)
  and `TERMINAL=xterm` in `~/.xprofile` (which also puts `~/.local/bin` in the session's `PATH`). xfce4-terminal stays
  installed (the `xfce4` metapackage needs it) but is not used.
- **Default browser:** Firefox → *Ajustes → General → Hacer predeterminado* (*Settings → General → Make Default*);
  check `xdg-mime query default x-scheme-handler/https`.
- xterm cannot scroll while dragging a selection past the edge: left click at the start, scroll, **right click** at
  the end.

## fastfetch

Omarchy's style (three framed sections, keys in a tree), launched by `fish_greeting`. **Edit the generator,
`~/.config/fastfetch/gen-config.py`, not `config.jsonc`** (the icons are `\uXXXX` escapes), then run it. Every line
comes from the real system: Void's logo, `xbps: N` with a box icon, the mirror, `glibc · <init>` (the init read from
`/proc/1/comm`), the 16 xterm colors, "Instalado" (`stat -c %W /home`) and **"Actualizado"** = the last full
`void-update` (`~/.local/state/void-update/last-update`; if missing, the pkgdb's date), shown as
`hace N días (fecha)`. Check it inside an xterm (over SSH there is no DE, WM, terminal or font).

## Login screen

Almost never seen (autologin; [login and modes](../4-sessions/1-login-and-modes.md)), but it looks the same.
`desktop-2-root.sh` copies to the system what the greeter (user `lightdm`, which cannot read `~`) needs: Orchis to
`/usr/share/themes`, Volantes to `/usr/share/icons` (X cursors are not looked for in `/usr/local`), the Blocks font
to `/usr/local/share/fonts/jetbrains-blocks`; installs `/etc/lightdm/lightdm-gtk-greeter.conf`
(`common/xfce/lightdm-gtk-greeter.conf`: theme, icons, cursor, font, `xft-dpi = 96`, `hintfull`, `rgba none`,
background) and the greeter's `gtk.css` (black top bar and the clock's font) with
`install -o lightdm -g lightdm -m 644` into `/var/lib/lightdm/.config/gtk-3.0/`. **They are copies:** after updating
Orchis, Volantes or the font, run it again. Check without the home folder:
`HOME=/nonexistent fc-match "JetBrainsMono NFM Blocks:bold"`.
