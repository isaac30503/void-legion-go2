### Discord (Vesktop) via Flatpak, the GNOME Software store and its art (2026-10-05 and 06)

**Discord is not in Void's repositories** (not even in `nonfree`; searched with `xbps-query -Rs discord`
on 2026-10-05). **Flatpak** (Flathub) was chosen: official, sandboxed and updated by `void-update`,
which already does `flatpak update` if it finds Flatpak (for all installations, the user's too).
Store: **GNOME Software** (`gnome-software` 50.2, "flatpak only", from Void's repository; it brings
`flatpak` 1.18.3 as a dependency). Discarded: **KDE Discover** (`discover`, 36 dependencies of
Qt6/KDE) and **Bazaar** (`io.github.kolunmi.Bazaar`, only on Flathub, not in Void). Client: **Vesktop**
(`dev.vencord.Vesktop` 1.6.7, alternative client with Vencord): unlike the official one
(`com.discordapp.Discord`), it is native Wayland and shares the screen with audio; **it is not official** (Discord
does not allow modified clients; no bans for using it are known).

```bash
sudo xbps-install -S gnome-software
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# log out and back in (see below); then, in "Software" (Super+Space → "software", or
# menu → Sistema (System) → Software): search for Vesktop and install it. Or: flatpak install --user flathub dev.vencord.Vesktop
```

- **Everything `--user`** (in `~/.local/share/flatpak`, 1.7 GB with its runtime `org.freedesktop.Platform`
  25.08 and Mesa's GL 26.2.2): no `sudo` to install apps.
- **It did not show in the menu:** `/etc/profile.d/flatpak.sh` adds Flatpak's folders to `XDG_DATA_DIRS`,
  and the session only reads it on login (`/etc/lightdm/Xsession` loads `/etc/profile`); the session from before
  installing Flatpak had `XDG_DATA_DIRS=/usr/local/share:/usr/share`. **A new session fixes it**
  (going through Game Mode or rebooting); meanwhile, `flatpak run dev.vencord.Vesktop`. GNOME Software does not
  stay in the background in Xfce (it has no autostart).
- **Resources** (measured on 2026-10-05): a Flatpak app uses the same CPU and GPU (it is not a virtual
  machine: `bubblewrap`); somewhat more RAM because it does not share libraries with the system (tens of MB;
  in Discord, which is Electron, almost nothing) and more disk the first time (the runtime).
- **In Steam:** Vesktop added as a non-Steam game (from its `.desktop`): `Exe`
  `"/usr/bin/flatpak"`, options `"run" "--branch=stable" "--arch=x86_64" "--command=startvesktop"
  "--file-forwarding" "dev.vencord.Vesktop" "@@u" "@@"` (those of the `.desktop`), `appid` 2287774968.
  **Today it also carries** `"--env=XDG_SESSION_TYPE=wayland" "--env=WAYLAND_DISPLAY=gamescope-0"` before
  `"dev.vencord.Vesktop"` and `"--ozone-platform=x11"` after (2026-10-07: to share the screen in
  Game Mode through gamescope's portal; see "Screen sharing in Game Mode"). Changing the options
  does not change the `appid` (it comes from the name and the `Exe`).
- **Art: Vesktop's logo with Discord's colors, minimalist** (2026-10-06, the user's request:
  Vencord's from SteamGridDB was pink): **`common/steam/art-vesktop/generate.py`** (without root;
  Pillow and `rsvg-convert`). It takes the vector from the Flatpak itself (`~/.local/share/flatpak/exports/share/
  icons/hicolor/scalable/apps/dev.vencord.Vesktop.svg`: speech bubble with a "V" and a "C") and
  changes its 4 colors: pink `#eb7396` → **`#5865F2`** ("blurple"), white `#ededed`/`#fff` →
  `#ffffff`, outlines `#1d2021` → `#1e1f22` (Discord's darkest gray). **Background with Vesktop's
  aesthetics and those same colors** (second request of the same day; before it was flat `#313338`): diagonal
  gradient `#313338` → `#1e1f22`, diffuse blue halo behind the logo, pattern of speech bubbles (the shape
  of Vesktop's bubble, in blue at 10–22 %, rotated ±35°, fixed seed) and **rectangular free zones**
  over the logo and the text (cover 10–90 % × 17–84 %, capsule 27–73 % × 5–95 %, header 0–56 % ×
  38–100 %, where Steam puts the logo); the logo carries a soft shadow, like a sticker. On blue the
  bubble would not be seen, that is why the background is gray; "Vesktop" in Noto Sans Bold on the
  cover, the capsule and the logo; plain gray header; the icon is the recolored logo. **First version,
  discarded the same day:** Papirus's Discord silhouette (`panel/discord-tray.svg`) in white
  on blue with "Discord": the user wanted Vesktop's logo. It looks for the shortcut by name or
  by "Vesktop" in its options; it saves in `~/.cache/arte-vesktop-anterior/` **only what is not already
  there** (the original pink one from SteamGridDB is still there; to go back: copy it again to `grid/`). The quick menu icon
  changed by itself: the shortcut already pointed to `grid/2287774968_icon.png`. It also leaves
  `~/.local/share/icons/steam-shortcuts/discord-256.png` (the 256 px icon; the name is from the first
  version). Reviewed in a preview (2026-10-06). Run without leaving anything in `~`:

  ```bash
  ssh lego python3 - < "$B/common/steam/art-vesktop/generate.py"   # or on the Legion: python3 <that file>
  ```

  With Steam open it shows after restarting Steam.
- **The same icon in Xfce** (menu, finder, Docklike and Alt+Tab; 2026-10-06, the user's request): it is done by
  the same `generate.py` at the end (function `desktop()`). **Why a copy of the launcher is needed:**
  the **Papirus-Dark** icon theme **ships its own `dev.vencord.Vesktop.svg`** (multicolor), which beats the
  Flatpak's `hicolor` icon, so changing the Flatpak's `.svg` would not work (and the Flatpak
  redoes it when it updates). The script:
  1. saves the recolored vector (same 3 colors) in **`~/.local/share/icons/vesktop-discord.svg`**;
  2. writes **`~/.local/share/applications/dev.vencord.Vesktop.desktop`** = copy of the one in
     `~/.local/share/flatpak/exports/share/applications/` (or in `/var/lib/flatpak/exports/…`) with
     `Icon=/home/isaac/.local/share/icons/vesktop-discord.svg` (absolute path: it does not depend on the theme) and a
     comment that says where it comes from. Same file name → **the user's copy rules**
     (`~/.local/share` goes before Flatpak's folders in `XDG_DATA_DIRS`), without duplicates in the menu.
     It keeps `Exec=` and `StartupWMClass=vesktop`: the Docklike and Alt+Tab associate the open window to this
     launcher by that class, so the window shows the same icon.
  Checked: `desktop-file-validate` without errors; the `.svg` only has `#5865f2`, `#ffffff` and `#1e1f22`.
  New windows and menus see it; if not, close Vesktop and open it again, or a new session.
  Verified in a new session (2026-10-06): menu and Docklike in blue. **If a Vesktop update changes its
  launcher** (another command in `Exec=`), run `generate.py` again (it redoes the copy). To go back to the
  Papirus icon: `rm ~/.local/share/applications/dev.vencord.Vesktop.desktop ~/.local/share/icons/vesktop-discord.svg`.
- **Tray icon** (the "VC" of the top panel, next to the Wi-Fi; 2026-10-06, the user saw that it was still
  pink after the above): **it does not come from the theme or the launcher, Vesktop draws it** with its internal PNGs
  (`static/tray/tray.png` and `trayUnread.png` inside the Flatpak's `resources/app.asar`: only "VC", without the
  bubble, 64×64; the "unread" one carries a red dot). But Vesktop **uses first the "user
  assets"** (those chosen in its settings): `~/.var/app/dev.vencord.Vesktop/config/vesktop/userAssets/tray`
  and `…/trayUnread` (**without extension**; read in its `main.js`: `userAssets`, `["splash","tray","trayUnread"]`).
  `generate.py` (function `tray()`, at the end) extracts those two PNGs from `app.asar`, changes **only the pink**
  to `#5865F2` (with its blend with the outline, so the soft edge stays the same; the white, the outline and
  the red dot are not touched: the red is told apart because its blue ≈ its green) and leaves them there. It shows **when
  opening Vesktop again**: closing the window only sends it to the tray (`minimizeToTray`); quit from
  the tray menu ("Quit"/"Salir") and open it again. As they do not touch the Flatpak, **they survive
  updates** (if Vesktop changed its PNGs, run `generate.py` again). To go back to pink:
  `rm -r ~/.var/app/dev.vencord.Vesktop/config/vesktop/userAssets`. **Verified** (2026-10-06): after quitting
  Vesktop from the tray and opening it again, the tray's "VC" shows in blue.
- **Desktop portals and screen sharing** (2026-10-06). Flatpak apps are sandboxed: to
  open a link in the browser, choose a file or capture the screen they ask the **portals**
  (`xdg-desktop-portal`), a system service provided by the distribution (Fedora/Ubuntu/SteamOS ship them
  with GNOME or KDE; Void with Xfce does not, and GNOME Software does not install them because they are not Flatpak). Without them
  Vesktop chats, talks and does video, but does not open links, attach files or share the screen.
  **1. Installed** (root, by the user) and new session:

  ```bash
  sudo xbps-install -S xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr grim fuzzel
  ```

  Void ships `/usr/share/xdg-desktop-portal/xfce-portals.conf` (the session is `XDG_CURRENT_DESKTOP=XFCE`):
  by default `gtk`, and `ScreenCast=wlr;gtk` (screen sharing through `xdg-desktop-portal-wlr`, which in labwc
  captures with its protocol and sends it through PipeWire). Nothing to configure. There is no screen capture
  portal (`Screenshot`: `xapp` is not there and the `gtk` one is GNOME's): Vesktop does not use it. Checked with
  `busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop
  org.freedesktop.portal.<X> version`: `OpenURI` 5, `FileChooser` 4, `ScreenCast` 4 (sources 3 = screen
  and window), `Settings` 2, `Notification` 1. **Opening links and attaching files: verified** by the
  user.
  **2. Screen sharing did nothing** (the button gave no sign): the portal has to ask *what* to
  share and for that it launches a **chooser**; without configuration it tries `slurp`, `wmenu`, `wofi`, `rofi`,
  `bemenu`, `mew` and `fuzzel` (`src/screencast/chooser.c` of xdpw 0.8.4) and, with none, it fails with
  `wlroots: no output found` and Vesktop does not warn (the man page says it uses any output:
  it does not). Seen by launching the portal by hand with logging: `setsid -f /usr/libexec/xdg-desktop-portal-wlr
  -r -l DEBUG > /tmp/xdpw.log 2>&1` (with the `xfce4-session` session; `-r` replaces the running one) and
  `dbus-monitor --session "interface='org.freedesktop.portal.ScreenCast'"`. Logs archived in
  `logs/legion-diagnostics-2026-10-04/xdpw-sin-selector-2026-10-06.log` and
  `xdpw-doble-peticion-vesktop-2026-10-06.log`. **`fuzzel`** (text list, theme in `legion/
  fuzzel.ini` → `~/.config/fuzzel/fuzzel.ini`, panel colors) is the fallback the portal takes by itself.
  **3. Chooser with previews, like Discord's** (the user's request): on Wayland no app can
  see the screen before the user chooses, so Discord's chooser with thumbnails (Windows/X11)
  does not exist here (Vesktop on X11 would have it, but it would only capture X11 programs: no). In GNOME/KDE the
  desktop provides it; here, an own one: **`legion/screen-share/`** ("share screen"):
  - `screen-share` (Python + GTK 3, already installed) → `~/.local/bin/`. Window "Compartir pantalla" ("Share screen")
    with Discord's colors (`#313338`, cards `#2b2d31`, border `#5865f2` on hover), tabs
    **Aplicaciones** (Applications) and **Pantallas** (Screens) and a card per source with a thumbnail (`grim -s 0.25 -o <output>` or
    `grim -T <identifier>`, in threads, 3 s cap; meanwhile, an icon). One click shares; `Esc` or
    "Cancelar" ("Cancel") does not. Fixed size → labwc treats it as a dialog (centered). Protocol with the portal
    (`chooser_type=dmenu`): on stdin `Monitor: <output> <description>` and `Window: <title> (<id>)`; on
    stdout the chosen line, identical; no output = canceled; never exit with 127. **`gi.require_version`
    of Gtk, Gdk, GdkPixbuf and Pango at 3.0/2.0/1.0**: Void also has GTK 4 and without pinning Gdk it fails
    (`Requiring namespace 'Gdk' version '3.0', but '4.0' is already loaded`). **Always on top**
    (2026-10-07): the script sets its identifier (`GLib.set_prgname("screen-share")`) and labwc's common
    `rc.xml` puts it always on top (`<windowRule identifier="screen-share"><action
    name="ToggleAlwaysOnTop"/>`, step 15). Why: with focus without raising (`raiseOnFocus` no), if Vesktop
    got the focus the chooser stayed **behind** without being noticed, and **while a chooser is still
    open the portal does not attend another request** (it launches it and waits for it to finish): it looked like you could no longer
    share again. Verified by the user (2026-10-07). Fixed note at the bottom of "Aplicaciones":
    "Si tras elegir una ventana no aparece la ventana de Vesktop, abre esa ventana un momento y vuelve"
    ("If after choosing a window the Vesktop window does not appear, open that window for a moment and come back")
    (point 5; until 2026-10-07 it ended in "(pasa con Steam)" / "(happens with Steam)": it also happened with Thunar).
    **Look** (2026-10-07, the user's request): **no bar or window buttons** (the same labwc
    rule carries `SetDecorations decorations="none"`; it closes with "Cancelar" or `Esc`), **rounded
    corners** (window with an RGBA visual and transparent; the content on a `#313338` background with
    `border-radius: 12px` and border `#3f4147`), **tabs that look like buttons** also when inactive (background
    `#2b2d31` and border; the active one, `#5865f2`) and **"Cancelar" as a button** (`#4e5058`, `#6d6f78` on hover).
    Reviewed in a screenshot with test data and by the user.
  - `install.sh` (without root; `--remove` undoes everything and goes back to fuzzel): copies the script; writes
    `~/.config/xdg-desktop-portal-wlr/config` = `[screencast]` `chooser_type=dmenu`
    `chooser_cmd=/home/isaac/.local/bin/screen-share`; writes
    **`~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service`** = the package's
    (`/usr/share/dbus-1/services/…`) with `Exec=/usr/bin/env XDPW_PERSIST_MODE=permanent
    /usr/libexec/xdg-desktop-portal-wlr` (point 4; the user's folder rules over the system's and
    updates do not overwrite it); reloads D-Bus (`dbus-send … org.freedesktop.DBus.ReloadConfig`) and restarts
    the portal (it reads everything on start; D-Bus relaunches it: `pkill -u "$USER" -f
    '^/usr/libexec/xdg-desktop-portal-wlr'`, anchored pattern so that it does not match the command itself).
    **Careful: restarting the portal cuts a running stream.** Check that it took the variable:
    `tr '\0' '\n' < /proc/$(pgrep -n -f '^/usr/libexec/xdg-desktop-portal-wlr')/environ | grep XDPW` →
    `XDPW_PERSIST_MODE=permanent`.
  - Log: `~/.cache/screen-share.log` (one line per call; last 200).
  - **Checked** (2026-10-07, full review): Common's `install.sh`, run again, leaves the
    three files (`screen-share`, `config` and the D-Bus service with `XDPW_PERSIST_MODE`)
    identical to those that were there and the portal comes back with the variable.
  **4. Vesktop asks to choose TWICE** (seen in the portal's log): the first session is for the preview
  of **its configuration window** (quality, FPS, audio: it is a dialog *inside* Vesktop) and the
  second, when confirming in it, to stream. **It is not Flatpak's or Void's: it is Chromium, on purpose**
  (issues.chromium.org/354537406, comment 13; Vencord/Vesktop#583): it skips the second question with
  the portal's **"restore token"** (in Hyprland/KDE, the "Allow restore token" checkbox; in Hyprland,
  `allow_token_by_default`). With fuzzel it would also happen; Flatseal has nothing to do with it (Vesktop
  lacks no permission). If the second chooser is closed the stream is canceled.
  **Fix, in two parts** (2026-10-06):
  - **The portal's, for screens:** xdg-desktop-portal-wlr 0.8.4 does implement the token
    (`persist_mode`/`restore_data`, `src/screencast/screencast.c`), but **only if the variable
    `XDPW_PERSIST_MODE` exists** (`transient`/`permanent`; without it, never) and **only for screens**
    (`restore_data` = `output_name`; for windows it returns nothing). It goes in the user's D-Bus service
    that `install.sh` writes (`permanent` = cap: each app receives at most what it asks for; Vesktop
    asks for 1, "while running"). That way the second request for a screen does not even call the chooser.
  - **Windows: own patch of the portal** (2026-10-07). **The previous approach, discarded:** the chooser
    remembered the choice and answered the following requests by itself (5 min from the choice; with 60 s
    it was not enough, the time in the configuration window counts). On 2026-10-07, with the stream's
    audio enabled, Vesktop asked **three** times and the memory (single use) only covered the
    second; with a 15 s burst after each answer, reconfiguring or streaming again (~5 s
    later) repeated the source without letting you choose; with 3 s it worked, but **it depended on timings**
    (the user's decision: no; "muy propenso al fallo" / "very failure-prone"). **The current approach, without timings:** have the portal
    return the token also for windows, which is what Chromium expects (it saves it per source and only
    sends it in follow-up requests, not in a new stream or when changing source).
    xdpw 0.8.4 does not do it (and in the project the issue #170, "Implement screencast session
    restore", is still open). **`legion/portal-wlr-patch/0001-screencast-restore-window-sessions.patch`**:
    when a request that shared a window ends, `restore_data` carries `toplevel_identifier` (the
    `ext-foreign-toplevel` identifier, stable while the window exists); when receiving it back, it
    looks for that window and uses it without calling the chooser; if it is no longer there, the chooser, as always. The
    screens, as before. It still needs `XDPW_PERSIST_MODE`. Built with Void's package
    (`build-portal-wlr.sh`, same scheme as gamescope's: `revision=2`, ~1 min with 16 threads;
    package saved next to it: the current one, with the three patches, in the third point below; since
    2026-10-09 the script and `void-update` first test the three patches against Void's code, see the
    IdeaPad recipe, step 6, *Prueba de parches propios* (*Testing own patches*): on 2026-10-09, the three HACE_FALTA (STILL_NEEDED) on 0.8.4_1 and
    on upstream `master`) and installed with `sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs
    xdg-desktop-portal-wlr`. **Rebooting the Legion was needed** for it to work (restarting only the
    portal was not enough; not found out what the old session kept). The chooser no longer carries memory: only the
    Steam rule. **`void-update` warns** if Void replaces the portal (repository without
    `hostdir/binpkgs`). **Verified** (2026-10-07, after rebooting): each stream calls the chooser
    **once** (the follow-up ones are restored by the portal and do not reach the log), and reconfiguring or
    streaming again asks anew. The user also saw that **a window on another workspace did
    stream** (see point 5).
  - **When changing streams, the chooser showed up repeated: second patch** (2026-10-07). Diagnosis with
    the portal in detailed logging (`pkill -u "$USER" -f '^/usr/libexec/xdg-desktop-portal-wlr'` and, with
    the session's environment, `XDPW_PERSIST_MODE=permanent setsid -f /usr/libexec/xdg-desktop-portal-wlr -r
    -l DEBUG > /tmp/xdpw-diag.log 2>&1`) and controlled tests by the user: **canceling does not cause
    repetitions**; when **sharing** the first time, chooser + 2 restored sessions that start (fine);
    when **changing streams** with one running ("Cambiar transmisión" / "Change stream" → another source → Go live),
    chooser + 3 restored, **the third closed before `Start`**, and right away **a fourth without
    `restore_data`** → the chooser again. That fourth is the real stream (canceling it cuts it; choosing
    another source streams that one). **Cause:** the token is single use and Chromium receives a new one only on
    `Start`; when closing the third without starting it, it was left without a token. **Fix:**
    **`portal-wlr-patch/0002-screencast-reuse-aborted-restored-source.patch`** (on top of 0001): the portal
    records the source of a **restored session that closes without starting** (app + screen or window) and
    uses it for the **next request without a token from that same app** (if it still exists; otherwise, chooser), and
    forgets it when using it, when the app brings its own token or when a session of that app that
    did start is closed (the stream ended: a new stream asks again). **No timings.** In the
    portal's log: `restored session of … closed before starting; remembering …` and `reusing the
    source of the restored session that was closed before starting`. `build-portal-wlr.sh` applies
    all the `0*.patch` of the folder (still `revision=2`: to reinstall the same revision, `sudo
    xbps-install -f -R ~/src/void-packages/hostdir/binpkgs xdg-desktop-portal-wlr`), clean build
    (the only warning, unused `has_drm_fourcc`, is from the original code). Saved package:
    `xdg-desktop-portal-wlr-0.8.4_2.x86_64.xbps`, sha256 `2d4b4090…` (no longer there: replaced by the one with three
    patches, below); its binary was identical to the one installed then (`66d61b68…`). Installed with `-f` and
    **reboot**. **Verified by the user** (2026-10-07): share
    → Go live → change → another → Go live, **without a repeated chooser**; stopping and sharing again asks
    once.
  - **Third patch: the portal tells the chooser which app is asking** (2026-10-07). Before, the chooser looked at
    all the pending requests of the main portal (from any portal and app) and a stuck one from
    Firefox showed up together with Vesktop: with Steam, its rule would not have applied. **`0003-screencast-pass-
    request-to-chooser.patch`**: before launching the chooser, the portal exports `XDPW_REQUEST_HANDLE`
    (`/org/freedesktop/portal/desktop/request/<connection>/<token>` of **that** request) and `XDPW_APP_ID`
    (empty for non-Flatpak apps, like Steam); the chooser gets from the connection the PID and from there
    the program (or, if it is a Flatpak app's `xdg-dbus-proxy`, its name from `.flatpak-info`). Without the
    variable it does what it did before. The three patches apply in order on 0.8.4 (checked with `git
    apply`); clean build. Saved package: `xdg-desktop-portal-wlr-0.8.4_2.x86_64.xbps`, sha256
    `845a8b54…` (replaces the two-patch one); its `/usr/libexec/xdg-desktop-portal-wlr` (sha256
    `3ca98c58…`) is **identical to the installed one** (checked on 2026-10-07 by opening the package). Installed with
    `-f`. **Verified** (2026-10-07): the log says `pide: dev.vencord.Vesktop` (asks: …), without Firefox.
  **5. Windows that give no image while they are not visible.** **Vesktop does not open its configuration window
  until it receives the first image** of what was chosen (it seems nothing happens, and if something else was already being streamed,
  the previous one continues). **What is known today** (2026-10-07, observed by the user): sometimes the
  windows give an image even if they are on another workspace or minimized (Firefox, Thunar) and other times not: that of
  **Steam** (a Chromium/CEF through Xwayland) on another workspace, never; **Thunar**, once yes and once no.
  **It does not reliably depend on the app.** Remedy: **go look at that window for a moment and come back**, and the
  Vesktop window appears by itself. (The first idea, "labwc does not draw
  the windows of another workspace or the minimized ones", was from before and turned out to be true only for windows
  like that one.) **There is no reliable signal to know it beforehand:** from SSH the capture of Steam's window
  gave no image in 3 s and Thunar's in 0.19 s, but inside the chooser Steam did give a thumbnail (it
  redraws from time to time) and Vesktop kept waiting. **Discarded:** (a) warning through the thumbnail
  (mark "Sin imagen" / "No image" on the card and a warning when pressing it, without sharing until a second click):
  implemented and removed the same day, it did not warn because there was a thumbnail; (b) having the chooser bring the
  window to the front for an instant (`wlrctl`) so it would be drawn: workspace jumps (the user's
  decision: no). **What stays:** the fixed note at the bottom of "Aplicaciones" (point 3), explicit and without guessing
  anything. The **Pantallas** (Screens) tab does not have this problem.
  **6. If the share button stops responding** (Vesktop does not call the portal: `dbus-monitor` without
  `CreateSession`), its "sharing" state got stuck after canceling halfway: **quit Vesktop
  from the tray and open it again**. It is a known Vesktop (Electron) bug on Wayland: if the
  **portal** answers "canceled", it cannot share again until restarted (Vencord/Vesktop#1099,
  #916, #799, closed without a fix; the same in other Electron apps, e.g. stoatchat#333). **Before
  thinking about that, look whether there is a chooser open** (`pgrep -af 'screen-share$'`): on 2026-10-07 the
  "it does not let me open it again" was a chooser forgotten behind Vesktop, already solved with "always on top"
  (point 3). At one point "Cancelar" was made to return a screen to Vesktop so you could cancel in its
  window and dodge the bug; **undone** at the user's request on seeing that the cause was the other one.
  **"Who is asking"** (point 7): until 2026-10-07 the chooser looked at **all** the pending requests
  of the main portal (from outside you cannot tell which portal each one belongs to): Firefox had a stuck one
  (`/request/1_154/t`) and the log said `pide: firefox, dev.vencord.Vesktop`; with Steam, its rule would not
  have applied. **Solved with the portal's third patch** (point 4): the chooser receives the
  exact request.
  Flatpak apps talk to the portal through their `xdg-dbus-proxy`; the app's name is read
  in `/proc/<pid>/root/.flatpak-info` (`name=dev.vencord.Vesktop`): that is how it shows in the log.
  **7. Steam also asks to share the screen when starting on the desktop** (seen on 2026-10-06 on logging in:
  the chooser showed up by itself, with 1 source = screens only): the desktop Steam runs with `-pipewire` (like
  SteamOS; `like-steamos.sh`) and on start it prepares the capture for Remote Play and game recording
  (`~/.local/share/Steam/logs/streaming_log.txt`: `CDesktopCapturePipeWire`; in gamescope it uses the
  PipeWire node `gamescope` and does not ask; on the desktop it goes through the portal; before installing the portals
  it failed silently: `Failed to create a screen cast session`). With `XDPW_PERSIST_MODE=permanent`
  **it kept asking on every start** (Steam does not save the token; seen on 2026-10-06 at 23:23).
  Removing `-pipewire` from the desktop Steam, or rejecting its request, was discarded (the user's
  decision: "no mutilar" / "do not mutilate": Steam would lose Remote Play and recording on the desktop). **Fix: per-program
  rules in the chooser** (`REGLAS = {"steam": "pantalla"}` — rules: steam → screen): the chooser finds out who is asking (while
  the request is pending, the portal publishes `/org/freedesktop/portal/desktop/request/<connection>/
  <token>`, e.g. `1_104` = `:1.104`; D-Bus gives its PID with `GetConnectionUnixProcessID` and `/proc/PID/comm`
  the program) and **grants Steam the screen without a dialog**, like KDE with "remember" in SteamOS.
  **It costs nothing:** Steam only wants the permission and closes the capture right away (`streaming_log.txt`:
  `Start signal received.` → `Finished obtaining persistent permissions, exiting PipeWire until streaming
  or recording.` → `Stopping capture session`; the portal, 0 % CPU and no open streams).
  Other possible actions: `"cancelar"` (cancel: answer "no" without a dialog: as before the portals) and, without a
  rule, the normal chooser. The log says who asked: `abierto con N fuentes (pide: vesktop.bin)` (opened with N sources (asks: …)) or
  `steam: regla 'pantalla', sin diálogo: Monitor: eDP-1 …` (steam: rule 'screen', no dialog: …). **Verified** (2026-10-06): test
  requests to the portal (from `python3`, chooser; from a program called `steam`, rule) and **real Steam
  restarted on the desktop: without a dialog and with the permission granted**. **Since 2026-10-07** (portal
  with the three patches, after rebooting): Steam **does not even reach the chooser**: the portal restores its
  permission with its token (`streaming_log.txt`, 21:47:27: `Start signal received.` → `Finished obtaining
  persistent permissions`, with no new entry in `~/.cache/screen-share.log`). The rule stays as a
  fallback for when it arrives without a token. Verified by the user: no dialog on logging in.
  **Compared with SteamOS** (2026-10-06, from what is published; the Deck was off): in its desktop mode
  (KDE), Steam with `-pipewire` shows the dialog "Compartir pantalla con…" ("Share screen with…") **on every start even if
  "permitir restaurar" ("allow restore") is checked** (discuss.kde.org, "Pipewire Share screen not restoring on future
  sessions"): Steam does not reuse the token. Here the rule solves it better. **Checked later on the
  Deck** (SteamOS 3.8.28, 2026-10-06): its desktop Steam also runs with `-pipewire`
  (`/usr/bin/steam` → `steam-jupiter`, which always sets it): the one here is faithful.
  **Verified** (2026-10-06): choosing a window in the chooser → Vesktop's configuration window →
  "EN VIVO" ("LIVE"), without a second question (log: `elegido: …` (chosen) and `segunda petición: repite sin diálogo: …` (second request: repeats without dialog),
  with the memory of back then). With the portal's token: **screen and window, without a second question**
  (verified by the user). Today (2026-10-07) windows also go through the token: see point 4.
- **Screen sharing in Game Mode (gamescope)** (2026-10-06 and 07). **Current state:** Vesktop
  streams **the whole Game Mode screen, games included, with their sound** ("Todo el sistema" / "Entire system"),
  through **SteamOS's gamescope portal** (below) and with **patched gamescope 3.16.30_2**; without a chooser
  (the portal does not ask) and without choosing a window (in gamescope one app is seen at a time). What follows goes in
  the order in which it was found. **By default** (without the portal or Vesktop's options): there is no Wayland
  for the apps there: everything is X11 (gamescope's two Xwaylands, `--xwayland-count 2`: Steam on `:0`; what is launched from Steam,
  games, Firefox and Vesktop, on `:1`). Vesktop uses **its own chooser with previews** (through X11, without
  portal) and only sees what is drawn through X11 on its server. Tested:
  - **Firefox window: fine.** Vesktop window: very blurry (not investigated; not of much use).
  - **Full screen: black.** gamescope composites the windows itself, outside X: the X "screen"
    is empty. Through X11 there is no fix; **with gamescope's portal there is** (below).
  - **Game (Nuclear Throne, Proton): black.** gamescope's WSI layer (`ENABLE_GAMESCOPE_WSI=1`, from
    `install-game-mode.sh`, like SteamOS) makes Vulkan games (Proton/DXVK) present through Wayland
    directly to gamescope, without going through X11. The same on the Steam Deck: SteamOS#1659 and gamescope#1563, open
    since 2024. **Per-game fix** (not global: that game loses frame pacing control, VRR and the
    layer's limiter): launch options `ENABLE_GAMESCOPE_WSI=0 %command%` and, in Vesktop,
    share the game's window. **There was no need to test it:** gamescope's portal was chosen (below),
    which streams games without touching the layer.
  - **SteamOS does the same:** gamescope has no capture portal (it only publishes its whole image as the
    PipeWire node `gamescope`, which Steam uses), and on the Deck Discord/Vesktop come out just as black in
    Game Mode (SteamOS#1659). Nothing that SteamOS has is missing. → **Corrected the same day with the Deck
    on:** SteamOS **does** have a capture portal for Game Mode (below); what is the same is
    that Vesktop, by default, does not use it.
  - **What was looked at on the Deck** (SteamOS 3.8.28, 2026-10-06): `/usr/bin/steam` → `steam-jupiter`, which
    **always** launches `steam -steamdeck -pipewire` (also on its desktop: our `-pipewire` is faithful).
    Portals: `xdg-desktop-portal-kde` (desktop), **`xdg-desktop-portal-gamescope`** and
    `xdg-desktop-portal-holo` (Game Mode). `/usr/bin/start-gamescope-session` does `systemctl --user
    set-environment XDG_DESKTOP_PORTAL_DIR=/usr/share/xdg-desktop-portal/gamescope-portals` (in Game
    Mode the portal only uses those: `gamescope-portals.conf` = `default=holo;gamescope`) and forces
    `XDG_SESSION_TYPE=x11` for all apps (that is why Vesktop goes through X11 and does not use the portal).
  - **gamescope's portal** (`xdg-desktop-portal-gamescope` 0.1.33.412a4bf-2, by Valve, Rust,
    BSD-3-Clause; code not public, `gitlab.steamos.cloud/holo/xdg-desktop-portal-gamescope`; public
    package in `https://steamdeck-packages.steamos.cloud/archlinux-mirror/holo-3.8/os/x86_64/`, 1.5 MB):
    implements `ScreenCast`, `Screenshot` and `Access`; to share the screen it delivers **gamescope's whole
    image** (its PipeWire node `gamescope`), WSI games included. **Screen only, no
    windows** (`AvailableSourceTypes` = 1, read over D-Bus): in Game Mode one app is seen at a time.
    It only depends on glibc. Saved in **`common/steam/portal-gamescope/`** with
    **`install-portal-gamescope.sh`** (root; `--remove`): it checks the package's sha256
    (`3929455f…`) and the binary's (`b449321f…`, identical to the Deck's), extracts it with Python 3.14's
    `compression.zstd` (Void does not ship `zstd`) and installs in `/usr/local`: `lib/xdg-desktop-portal-gamescope`,
    `lib/xdg-desktop-portal-gamescope-void` (wrapper, below), `share/dbus-1/services/
    org.freedesktop.impl.portal.desktop.gamescope.service` (Exec = the wrapper) and
    `share/xdg-desktop-portal/gamescope-portals/` (`gamescope.portal` and `gamescope-portals.conf` =
    `default=gamescope`; holo is not needed).
  - **In the Game Mode launcher** (`install-game-mode.sh`, common; only if that folder exists):
    `XDG_DESKTOP_PORTAL_DIR` exported **before** `dbus-run-session` (the bus inherits it) and, inside
    gamescope and before Steam, `dbus-update-activation-environment XDG_CURRENT_DESKTOP
    XDG_SESSION_DESKTOP GAMESCOPE_WAYLAND_DISPLAY XDG_DESKTOP_PORTAL_DIR` (gamescope only gives
    `GAMESCOPE_WAYLAND_DISPLAY` to its children, and without `XDG_CURRENT_DESKTOP=gamescope` the portal says "Not
    running under a gamescope session"). Log: `== portal de gamescope: …` in
    `~/.local/state/steam-game-mode.log`. On the IdeaPad (without the portal) it does nothing.
  - **Journal wrapper:** Valve's binary logs to systemd's journal (crate
    `systemd-journal-logger` 2.2.2) and without `/run/systemd/journal/socket` (Void) it crashes on start:
    `panicked at src/main.rs:22:10 … NotFound`, code 101 (seen with `StartServiceByName` and launching it by
    hand). Tested: with a fake journal socket it starts. **`xdg-desktop-portal-gamescope-void`**
    (Python) relaunches itself inside `bwrap` (without root; `--dev-bind / / --tmpfs /run/systemd`), creates
    the socket there, starts the portal as a child and passes each `MESSAGE=` to `~/.local/state/portal-gamescope.log`
    (emptied when it passes 1 MB). No fake journal is created for the whole system: other programs would change where
    they log. **The main portal looks for its portals on start:** if one crashed, you have to leave
    and come back to Game Mode.
  - **Vesktop through the portal:** Chromium only uses the portal if it believes it is on Wayland
    (`XDG_SESSION_TYPE=wayland` and `WAYLAND_DISPLAY` set). Launch options of Vesktop's shortcut
    in Steam: `"run" "--branch=stable" "--arch=x86_64" "--command=startvesktop"
    "--file-forwarding" "--env=XDG_SESSION_TYPE=wayland" "--env=WAYLAND_DISPLAY=gamescope-0"
    "dev.vencord.Vesktop" "--ozone-platform=x11" "@@u" "@@"` (the window stays on X11: `startvesktop`
    sees `DISPLAY` and does not switch to Wayland; `--ozone-platform=x11` ensures it). Result: **no chooser**
    (the portal does not ask) → Vesktop's configuration window → streams the whole screen, games
    included. **Stable** during a match (verified by the user). Without those options (by default, like
    SteamOS): its X11 chooser with windows, WSI games in black.
  - **gamescope failure when starting or reconfiguring a stream** (2026-10-07): twice gamescope
    crashed (`Segmentation fault` in the launcher's log, after a burst of `pipewire: warning: out
    of buffers`) and the launcher switched to Xfce. Diagnosed with **`legion/diag-gamescope-pipewire.sh`**
    (root; it attaches `gdb` to `gamescope-wl` in the background and leaves the trace in
    `/var/tmp/gamescope-pipewire-traza.txt`; no dump is possible: gamescope has `cap_sys_nice` and
    `fs.suid_dumpable=0`). It needed `gdb` and Void's symbols (`sudo xbps-install -S
    --repository=https://repo-default.voidlinux.org/current/debug gamescope-dbg`; removed when done).
    **Trace** (`logs/legion/gamescope-pipewire-fallo-2026-10-07.txt`): thread `gamescope-pw`,
    `copy_buffer()` in `src/pipewire.cpp:196` ← `dispatch_nudge()` (308), with an already freed buffer
    (`pw_buffer = 0x1f0000000a`). **Cause:** race in gamescope (3.16.30 and the same in Valve's master
    branch; their 2026 PipeWire fixes, `e3ed1ea7` and `4d143bfd`, were already there): `request_buffer()` (steamcompmgr's
    thread) takes the buffer with `pw_stream_dequeue_buffer()` and afterwards marks it `copying = true`;
    if in between the PipeWire thread runs `stream_handle_remove_buffer()` (a consumer that starts or
    renegotiates), it sees it free and deletes it. **Own fix:**
    **`common/steam/gamescope-patch/0003-pipewire-fix-use-after-free.patch`** (a `std::mutex` between
    "take + mark" and "remove"; PipeWire 1.6.9's `pw_stream_dequeue_buffer()` takes no lock,
    so it cannot deadlock; written to be sent to Valve). **Built** with Void's official
    package (`xbps-src`, without root or container, `revision=2`): **`build-gamescope.sh`** (same folder;
    clones `void-packages`, copies the patch, bumps the revision, `binary-bootstrap` if missing and `pkg gamescope`
    with `XBPS_DEBUG_PKGS=yes`; ~6 min with 16 threads). Packages saved next to it:
    `gamescope-3.16.30_2.x86_64.xbps` (sha256 `53c89d77…`) and `gamescope-dbg-3.16.30_2.x86_64.xbps`
    (`0100f0e1…`). Installed (root): `sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs -R
    ~/src/void-packages/hostdir/binpkgs/debug gamescope gamescope-dbg` (with `gamescope-dbg` 3.16.30_1
    installed, xbps did not let install only `gamescope` 3.16.30_2: "breaks installed pkg") + `sudo setcap
    cap_sys_nice=eip /usr/bin/gamescope`. `~/src/void-packages` (1.1 GB) deleted afterwards.
    **Tested** (2026-10-07, with `gdb` attached): stream, reconfigure, stop and start again
    several times → **no crashes** (11 stream state changes, no `SIGSEGV`). Nuance: that time no
    `out of buffers` showed up, which is when the race opens: a good sign, not definitive proof.
    **`void-update` warns** if the installed gamescope stops being the one built here
    (`xbps-query -p repository gamescope` without `hostdir/binpkgs`): a Void update replaces it;
    then, repeat `build-gamescope.sh` (if the patch no longer applies, it stops at "patching").
    **Since 2026-10-09** `void-update` and `build-gamescope.sh` **test the patch** against the code
    of Void's template (`patch-still-needed`, IdeaPad recipe, step 6, *Testing own
    patches*): if it already has it, the script does not build and `void-update` gives the command to go back to Void's
    (`sudo xbps-install -Sf gamescope && sudo setcap cap_sys_nice=eip /usr/bin/gamescope`). On 2026-10-09:
    HACE_FALTA (STILL_NEEDED) on 3.16.30_1 (and on upstream `master`).
    **Common's version, checked** (2026-10-07, full review): run as is from
    `/tmp`, it applies `0001`, `0002` and `0003`, generates `gamescope-3.16.30_2` and its `-dbg` (~6 min) and its
    `/usr/bin/gamescope` is **identical byte for byte** to the installed one (sha256 `ba4ff94f…`): the build
    is reproducible. `~/src/void-packages` deleted again afterwards.
  - **Game sound in the stream:** with the whole screen through the portal, the viewers
    only got the sound of Steam's menu. In Vesktop's stream configuration window,
    audio source **"Todo el sistema"** ("Entire system"): **the game is heard** (verified by the user,
    2026-10-07).
  - **The user's decision (2026-10-07): a single Vesktop shortcut, the full-screen one through the
    portal** (with the options above). The default one (X11 chooser with windows) was discarded: it forces
    `ENABLE_GAMESCOPE_WSI=0` in every game (and loses the layer's things) and the full screen comes out black.
    **Also verified** (2026-10-07): no crashes when changing the stream's settings and with a heavier
    game (Borderlands 3). If a Void update replaces gamescope, `void-update` warns and it is
    redone with `build-gamescope.sh`.
  - **Verified again** (2026-10-07, by the user), after the wlroots portal's three patches,
    the new chooser and the labwc rules: **screen sharing in Game Mode still
    works** (as expected: neither the wlroots portal nor the chooser are involved there). In that
    boot: `portal-gamescope.log` → `arrancado` (started) (21:49:59), gamescope `3.16.30_2` from the local
    repository and no `Segmentation fault` in `steam-game-mode.log`.
  Check: `cat ~/.config/xdg-desktop-portal-wlr/config`; `tail ~/.cache/screen-share.log`.

