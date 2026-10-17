# Xfce: X11 and Wayland

The same Xfce in two sessions: **Xfce on Wayland** with **labwc** as the compositor (the normal desktop; what
`startxfce4 --wayland` does in Xfce 4.20) and **Xfce X11** with xfwm4 (the backup). Both share the panels,
themes and settings; window handling is xfwm4's on X11 and labwc's (`rc.xml`) on Wayland
([windows and shortcuts](3-windows-and-shortcuts.md)). The Live ISO installed Xfce X11 and lightdm already.

## Install

**1. Packages, Bluetooth and the user's pieces** (from the X11 session of the installed system):

```bash
sudo bash "$B/legion/desktop-1-root.sh"     # log ~/desktop-1-root.log
```

It deletes the `.new-*` of `/etc`, installs `fish-shell fzf ntfs-3g curl git ripgrep xdg-utils xrandr` and the
desktop software (`xterm xrdb xprop xdotool librsvg-utils ImageMagick fastfetch xfce4-docklike-plugin
xfce4-clipman-plugin papirus-icon-theme papirus-folders sassc gtk-engine-murrine xfce4-screensaver
xfce4-screenshooter btop blueman adwaita-fonts twemoji noto-fonts-ttf libspa-bluetooth`), sets the teal Papirus
folders and enables `bluetoothd`.

Then, as the user ([look and feel](2-look-and-feel.md) explains each piece):

```bash
V="$B/common"
# fish from bash (the login shell stays /bin/bash; see "Shell" below)
mkdir -p ~/.bashrc.d && cp "$V/shell/99-exec-fish.sh" ~/.bashrc.d/
cp ~/.bashrc ~/.bashrc.bak && cat "$V/shell/bashrc-block.sh" >> ~/.bashrc
# fish functions and the translations of the messages
mkdir -p ~/.config/fish/functions ~/.local/bin
bash "$B/install/install-i18n.sh"   # ~/.local/share/void-legion (without it, the messages come out in English)
cp "$V/fish/functions/"{__vl_t,fish_prompt,fish_greeting,disk-ops}.fish ~/.config/fish/functions/
cp "$V/fish/functions/"{install-pkg,remove-pkg,audio-ctrl,audio-priority}.fish ~/.config/fish/functions/
cp "$V/ssh-setup/ssh-setup.fish" ~/.config/fish/functions/
cp "$V/ssh-setup/ssh-survey.sh" ~/.config/fish/ && chmod +x ~/.config/fish/ssh-survey.sh
fish -c 'fish_add_path -U ~/.local/bin'
bash "$V/void-update/install-void-update.sh" --no-tray   # void-update and its patch test
# fonts, Orchis, Volantes
mkdir -p ~/.local/share/fonts ~/.themes ~/.local/share/icons
cp "$V/fonts/"*.ttf ~/.local/share/fonts/
cp -r "$V/xterm/jetbrains-blocks" ~/.local/share/fonts/ && chmod +x ~/.local/share/fonts/jetbrains-blocks/regenerate.sh
fc-cache -f ~/.local/share/fonts
tar xzf "$V/xfce/orchis-themes.tar.gz" -C ~/.themes/
tar xzf "$V/xfce/volantes-cursors.tar.gz" -C ~/.local/share/icons/
# xterm and the default terminal
X="$V/xterm"; mkdir -p ~/.config/xfce4
cp "$X/Xresources" ~/.Xresources && cp "$X/xterm-papirus.xpm" ~/.local/share/icons/
cp "$X/helpers.rc" ~/.config/xfce4/helpers.rc && cp "$X/xprofile" ~/.xprofile
cp "$X/xdg-terminal-exec" ~/.local/bin/ && chmod +x ~/.local/bin/xdg-terminal-exec
# fastfetch
mkdir -p ~/.config/fastfetch && cp "$V/fastfetch/gen-config.py" ~/.config/fastfetch/ && python3 ~/.config/fastfetch/gen-config.py
```

`~/.local/bin` must exist before `fish_add_path` (otherwise it returns an error).

**2. The login screen** with the session's look ([look and feel](2-look-and-feel.md#login-screen)):

```bash
sudo bash "$B/legion/desktop-2-root.sh"     # log ~/desktop-2-root.log
```

**3. Xfce's configuration, with the session closed** (`xfconfd` rewrites these files on exit and would overwrite
the copy). Log out and, from the login screen's console (Ctrl+Alt+F2) or over SSH:

```bash
pkill -u "$USER" -x xfconfd
L="$B/legion"; X="$B/common/xfce"
mkdir -p ~/.config/xfce4/xfconf ~/.config/gtk-3.0 ~/.local/bin ~/.config/autostart
cp -r "$L/xfce/xfce-perchannel-xml" ~/.config/xfce4/xfconf/
cp -r "$L/xfce/panel" ~/.config/xfce4/
cp "$L/xfce/gtk.css" ~/.config/gtk-3.0/gtk.css
cp "$X/"{window-snap,window-focus,new-windows} ~/.local/bin/ && chmod +x ~/.local/bin/{window-snap,window-focus,new-windows}
cp "$X/new-windows.desktop" ~/.config/autostart/
```

From `"$B"` because those files carry rendered values (the Wi-Fi name in the panel's remembered tray tooltips,
`@TARGET_HOME@` in the shortcuts). Then log back in (Ctrl+Alt+F7).

**4. Xfce on Wayland**, before the first reboot into Game Mode (it is where "Switch to Desktop" goes;
[login and modes](../4-sessions/1-login-and-modes.md)):

```bash
sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"     # --remove leaves the labwc package
```

It installs **`labwc`** and **`~/.config/xfce4/labwc/`** (the folder `startxfce4 --wayland` uses, not
`~/.config/labwc`): `environment` (`XKB_DEFAULT_LAYOUT=us`, `XKB_DEFAULT_VARIANT=intl`, from
`00-keyboard.conf`; `XCURSOR_THEME=volantes_cursors`, `XCURSOR_SIZE=24`), an empty **`lock`** (without it
`startxfce4` rewrites the keyboard from `/etc/vconsole.conf`, which Void does not have, and leaves `en`),
`autostart` (`xrdb -nocpp -merge ~/.Xresources` in Xwayland, and `wallpaper-watcher`) and `rc.xml`; plus
**`~/.local/bin/brightness +N|-N`** (brightness keys through elogind's `SetBrightness`, without root, never below
5 %: on Wayland xfce4-power-manager cannot catch them), **`~/.local/bin/wallpaper-watcher`**
([wallpaper](4-wallpaper.md)), the Orchis theme for labwc (`labwc-theme.sh`) and the launchers "Escritorio
Wayland" / "Escritorio X11". After editing `rc.xml`: `labwc --reconfigure` (or `kill -HUP $(pgrep -x labwc)`).

## Notes

- **Shell:** the login shell stays **`/bin/bash`** (`getent passwd "$USER"`); `~/.bashrc.d/99-exec-fish.sh`, run by a
  block at the end of `~/.bashrc`, starts fish in interactive shells (guarded against non-interactive shells and
  loops). On purpose: with fish as the login shell the account depends on `/etc/passwd` and `/etc/shells` staying
  consistent. **Do not "fix" it with `chsh`.**
- **Saving the configuration back to the repository:** after changing something of Xfce, copy
  `~/.config/xfce4/xfconf/xfce-perchannel-xml/`, `~/.config/xfce4/panel/` and `~/.config/gtk-3.0/gtk.css` to
  `legion/xfce/` (with their private values back to `@NAME@`: [sanitization](../sanitization.md)).
- **`~/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml`** is the Wayland session's (outputs `DP-1` at `0,0` 1920×1080 60 Hz, `eDP-1` at `1920,0`
  1920×1200 144 Hz), with **two saved profiles** that Xfce applies by itself (`AutoEnableProfiles` 3) according to the
  screen plugged in: **"Monitor MSI"** (that layout) and **"Sala 4K"** (a 4K Pioneer TV, `3840x2160` at **scale 2**, to
  the right of the Legion's screen; 2026-10-16). Saving a new screen's layout in *Settings → Display* overwrites
  `Default`: save it as a **new profile** in the *Profiles* tab instead. **The panels go to the external screen** when
  there is one (`wallpaper-watcher`, [wallpaper](4-wallpaper.md)).
- **The clock in the middle of the screen:** it is alone in a third panel (`panel-3`: top centre, `p=9`, size 26, no
  struts, the same black), not in the top bar, where it sat in the middle of the free space between the widgets of
  each side (2026-10-16).
- **X11 programs (xterm) are blurry on a screen at scale 2:** labwc 0.20 (wlroots 0.20) draws Xwayland windows at
  scale 1 and stretches them; it has no option for it. Native Wayland programs (GTK, the panel) are sharp. Left as it
  is (the user's decision, 2026-10-16): xterm stays the terminal; it is sharp on the Legion's screen and the monitor. In the X11 session, arrange the screens once in *Configuración → Pantalla* (*Settings →
  Display*), monitor on the left.
- **Copying from Claude Code over SSH:** `.Xresources` lets programs *put* text on the clipboard with OSC 52
  (`disallowedWindowOps` without `SetSelection`); Shift + drag selects over Claude Code.

## Check

Inside the Wayland session: `echo $XDG_SESSION_TYPE` → `wayland`; `pgrep -a labwc` →
`labwc --config-dir ~/.config/xfce4/labwc …`; fastfetch → `labwc 0.20.x (Wayland)`;
`ls ~/.config/xfce4/labwc` → `autostart environment lock rc.xml`; `grep -c wallpaper-watcher
~/.config/xfce4/labwc/autostart` → 2. Also: `fish -c 'functions -q install-pkg disk-ops ssh-setup; and echo OK'`,
`void-update --version`.

## Known limits on Wayland

No screen lock (`xfce4-screensaver` is X11 only); the shortcuts of `xfce4-keyboard-shortcuts` do not apply (they
are in `rc.xml`); the bottom panel can only "always hide" (the "intelligent" mode needs the windows' positions,
which Wayland keeps private); the **Docklike cannot filter by workspace** (labwc's `wlr-foreign-toplevel` does not
say each window's workspace, and `libxfce4windowing` only knows it through Xfce's own protocol); labwc 0.20 cannot
round Alt+Tab's corners.
