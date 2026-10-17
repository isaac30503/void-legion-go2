# Discord (Vesktop)

Discord is not in Void's repositories. **Vesktop** (`dev.vencord.Vesktop`, an alternative client with Vencord: native
Wayland, screen sharing with audio; not official) from **Flathub**, with **GNOME Software** as the store (it brings
`flatpak`). `void-update` updates Flatpak too.

## Install

```bash
sudo xbps-install -S gnome-software
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

**Start a new session** (`/etc/profile.d/flatpak.sh` adds Flatpak's folders to `XDG_DATA_DIRS` only at login; before
that the apps do not show in the menu; meanwhile, `flatpak run dev.vencord.Vesktop`). Then install Vesktop from "Software" (Super+Space → "software"), or
`flatpak install --user flathub dev.vencord.Vesktop`. Everything `--user` (`~/.local/share/flatpak`): no `sudo` for
apps. A Flatpak app uses the same CPU and GPU (`bubblewrap`, not a virtual machine), somewhat more RAM and, the first
time, disk (its runtime).

**Screen sharing** needs the desktop portals: [screen sharing](1-screen-sharing.md). **Rich Presence** (Discord shows
what is being played): enabled in Vesktop's own settings (the arRPC option); check
`grep -c '"arRPC": true' ~/.var/app/dev.vencord.Vesktop/config/vesktop/settings.json` → `1`.

## In Steam

Add Vesktop as a non-Steam game from its `.desktop` (`Exe` `"/usr/bin/flatpak"`), then set the launch options of
[screen sharing in Game Mode](1-screen-sharing.md#in-game-mode). Changing the options does not change the shortcut's
`appid`.

## Its look: Vesktop's logo in Discord's colors

Open Vesktop once (so its data folder exists); then, with the shortcut already in Steam:

```bash
python3 "$B/common/steam/art-vesktop/generate.py"
```

Without root (Pillow, `rsvg-convert`). From the Flatpak's own vector it recolors the logo (pink `#eb7396` →
**`#5865F2`**, white `#ffffff`, outlines `#1e1f22`) and makes:

- **Steam's library art** (cover, banner, hero, logo, icon) on a `#313338` → `#1e1f22` gradient with a pattern of
  Vesktop's speech bubbles (fixed seed); it saves what was there before in `~/.cache/art-vesktop-previous/` (only what is
  not saved already).
- **The same icon in Xfce** (menu, finder, Docklike, Alt+Tab): `~/.local/share/icons/hicolor/scalable/apps/vesktop-discord.svg` and a copy of
  the Flatpak's launcher in `~/.local/share/applications/dev.vencord.Vesktop.desktop` with `Icon=vesktop-discord` (a name of
  its own: Papirus-Dark ships its own `vesktop`, which would win), keeping `StartupWMClass=vesktop`. By name and not by
  path (2026-10-16): with a path the panel loaded it at 1× and stretched it, blurry on a screen at scale 2. Only this
  part: `python3 "$B/common/steam/art-vesktop/generate.py" --desktop`.
- **The tray icon** (the "VC" Vesktop draws itself): recolored PNGs in Vesktop's *user assets*,
  `~/.var/app/dev.vencord.Vesktop/config/vesktop/userAssets/tray` and `…/trayUnread` (no extension; the red dot untouched).
  It shows after **quitting Vesktop from its tray** and opening it again.

None of it touches the Flatpak, so it survives updates; if Vesktop changes its launcher or its tray PNGs, run the
generator again. To go back: `rm ~/.local/share/applications/dev.vencord.Vesktop.desktop ~/.local/share/icons/hicolor/scalable/apps/vesktop-discord.svg`
and `rm -r ~/.var/app/dev.vencord.Vesktop/config/vesktop/userAssets`.

**Check:** `desktop-file-validate ~/.local/share/applications/dev.vencord.Vesktop.desktop`; menu, Docklike and tray in blue.
