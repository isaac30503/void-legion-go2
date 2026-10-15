## 14. Steam and Game Mode like SteamOS (2026-10-03)

The same scripts as the IdeaPad (`common/steam/`, its step 14), copied to `~/steam/`, **already
adapted to work on both machines** (on the IdeaPad they give the same as before):

```bash
sudo sh "$B/common/steam/install-steam.sh"                 # nonfree/multilib repos, Steam, gamescope, MangoHud, Vulkan, limits
#   → log out and back in (nofile), open steam: it updates (~500 MB) and you log in
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen   # launcher, brightness, steamos-session-select…
sudo sh "$B/common/steam/test-direct-session.sh"          # the Game Mode Wayland session
sudo sh "$B/common/steam/install-passwordless-switch.sh" # autologin + mode switch without password
sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"   # step 15: BEFORE rebooting (see below)
sudo reboot                                       # goes straight into Game Mode
```

Then, the Legion's own things (2026-10-04; each one with its section further down):

```bash
sudo bash "$B/legion/install-inputplumber.sh"              # controller as a Valve controller (InputPlumber)
sudo bash "$B/legion/tdp/install-tdp.sh"                   # lenovo-wmi-* modules via DKMS (fine TDP)
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"   # Performance in Steam
sudo sh "$B/legion/gpu-overdrive.sh"                        # manual GPU clock
sudo reboot
# in Game Mode: Ajustes → Sistema → "Activar modo desarrollador" (Settings → System → "Enable Developer Mode");
# Desarrollador (Developer) → turn off "Habilitar administración de energía para Wi-Fi" ("Enable Wi-Fi Power Management")
```

**No loading screen** (2026-10-04, the user's decision): `install-game-mode.sh
--no-loading-screen` does not install `steam-loading` (and deletes it if it was there); the launcher already worked
without it (it starts `mangoapp` directly). Without the option, the installer does the usual (the
IdeaPad had it until 2026-10-05; since then it also goes without it: its recipe, step 14,
"Igualada con la Legion" / "Matched with the Legion"). With Steam closed cleanly, from Game Mode to the
Steam interface: **~1 s** (01:50:17 → 01:50:18 on 2026-10-04).

**What was adapted** (each script leaves its `.bak` in `Common`):
- `install-steam.sh`: **Vulkan according to the GPU** (`/sys/class/drm/card0/device/vendor`: `0x1002`
  → `mesa-vulkan-radeon` and its `-32bit`; otherwise, `mesa-vulkan-intel`). Here: `AMD Radeon 890M Graphics
  (RADV STRIX1)`, Vulkan 1.4. 116 packages; what was installed by hand, in
  `legion/steam/installed-packages.txt` (for `--remove`).
- `install-game-mode.sh`: the launcher also passes **`XKB_DEFAULT_VARIANT`** to gamescope (from
  `00-keyboard.conf`: `intl`; without a variant, nothing) and chooses the screen **like SteamOS on this Legion**
  (`-O '*',eDP-1` in its `gamescope-session`, saved in the rescue): **the external one if there is one, otherwise
  its own** (`SCREEN="*,eDP-1"`, passed as `${SCREEN:+-O "$SCREEN"}` so that the `*`
  arrives literal; checked with `dash` and a file `trampa,eDP-1` in the folder). Only on the
  screen; in the nested X session, nothing.
- `install-game-mode.sh`, **hot-plugged monitor** (2026-10-04): without anything else, when connecting or removing the
  HDMI the Steam interface kept the previous monitor's proportions. Fix: in the
  direct-screen branch, **the same as this Legion's SteamOS session**
  (`gamescope-session-valve-original` from the rescue): `--generate-drm-mode fixed --xwayland-count 2
  --default-touch-mode 4 --hide-cursor-delay 3000 --fade-out-duration 200` and its variables
  (`STEAM_MULTIPLE_XWAYLANDS=1`, `STEAM_GAMESCOPE_*_SUPPORTED`, `GAMESCOPE_MODE_SAVE_FILE` and
  `GAMESCOPE_PATCHED_EDID_FILE` in `~/.config/gamescope/`, `STEAM_ENABLE_DYNAMIC_BACKLIGHT`, etc.;
  exact list in the script). With them Steam changes resolution by itself when connecting or disconnecting.
  **Without** SteamOS's `-w 1280 -h 800 --max-scale 2 --cursor-scale-height 720`: they draw Steam at
  the Steam Deck's resolution and stretch it; here the image came out blurry and the cursor big (and
  the fans sped up on entering; cause not clarified). **Checked by the user** with the
  monitor hot-connected and disconnected. It is applied by repeating
  `sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen`; check:
  `pgrep -a gamescope` shows `--xwayland-count 2` and not `-w 1280`.
- `install-game-mode.sh`, **cursor** (2026-10-04): SteamOS had its own (theme `steam`, with
  `XCURSOR_THEME=steam` and `gtk-cursor-theme-name=steam` in `gtk-3.0/settings.ini`, because Chromium,
  Steam's interface, ignores XCursor). **That theme is not in Valve's public
  repositories** (searched in `steamdeck-kde-presets` 3.9.4, current `steamos-customizations-jupiter` and the
  3.6 one, and `steam-jupiter-stable`) nor in the rescue (`/usr` was not saved). Instead, **the same
  mechanism with the desktop cursor**: the launcher reads `CursorThemeName` from
  `~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` (`volantes_cursors`), exports
  `XCURSOR_THEME` and `XCURSOR_SIZE=24` and puts `gtk-cursor-theme-name` in
  `~/.config/gtk-3.0/settings.ini` (creates it if missing; in Xfce xsettings rules, so it does not change the
  desktop). Check: `cursor: volantes_cursors` in `~/.local/state/steam-game-mode.log` and
  the Volantes arrow in Steam's interface. **Verified by the user on 2026-10-04.**
- `install-passwordless-switch.sh`: **on a new installation it stopped silently** after
  step 1: it read the mode from `60-steam-mode.conf`, which did not exist yet; `sed` failed and `set -e`
  ended the script. Now `… || true`.
- **Brightness needed nothing:** Game Mode's `sudo` takes the name of the light from Steam's
  command (`amdgpu_bl0` here).

**Verified on 2026-10-03** (`~/.local/state/steam-game-mode.log`): `modo: pantalla directa
(DRM)` (mode: direct screen), gamescope sees `eDP-1` (Samsung AMS881KB01) and `DP-1` (MSI MAG 276CF); loading screen within a
second and **the Steam interface at 5 s** after entering; brightness through elogind (`brillo N
(amdgpu_bl0)`); "Cambiar a escritorio" ("Switch to Desktop") → Steam closed and, 2 s later, `switch-mode-root
escritorio` → Xfce Wayland (`steamos-session-select.log`). In Steam: *Configuración → Teclado* (*Settings → Keyboard*) →
inglés (EE. UU.) internacional (English (US) international).

**Why Steam took ~50–64 s to enter, sometimes (2026-10-04, cause found):** Steam has
**two clients**: the normal one (branch `''`) on the desktop and the Steam Deck one (`steamdeck_stable`)
with `-steamdeck`. **Every time you alternate** (Steam on the desktop and then Game Mode, or the
other way round) it changes branch and **downloads and installs the other client**: in
`~/.local/share/Steam/logs/console-linux.txt`, `Client beta changed from '' to 'steamdeck_stable'`
and `installed version 0`. The branch is saved in `~/.local/share/Steam/package/beta`, but the desktop
Steam undoes it on start (`… changed from 'steamdeck_stable' to ''`): **the
argument rules, not the file.** **Fix here: the desktop Steam also with `-steamdeck`** (without
`-gamepadui`: it keeps its desktop interface, checked by the user). A copy of the system's
launcher in `~/.local/share/applications/steam.desktop` (same name: it replaces the system's
in the menu, the finder and the dock, and is not lost when the package is updated), with `-steamdeck` in
the 10 `Exec` commands; backed up in `legion/steam/steam.desktop`:

```bash
sed -E 's#^Exec=/usr/bin/steam( |$)#Exec=/usr/bin/steam -steamdeck\1#' /usr/share/applications/steam.desktop > ~/.local/share/applications/steam.desktop
# or: cp "$B/legion/steam/steam.desktop" ~/.local/share/applications/
```

Since 2026-10-04 the Legion uses the variant with `extest`'s `LD_PRELOAD` in front
(`steam-extest.desktop`, see "Controller on the desktop", further down); `steam.desktop` stays as the
generic one (the IdeaPad's).

**Verified on 2026-10-04:** Steam on the desktop started with `-steamdeck` and stayed on
`steamdeck_stable`; on entering Game Mode afterwards, no download (`installed version` = the one of the
manifest) and the interface at **21 s** (before, ~50 s). Opening it from an xterm (plain `steam`)
would change branch again.

**Clean shutdown of Steam when going from the desktop to Game Mode** (2026-10-04, in
`install-game-mode.sh` → `steamos-session-select`, common to both machines): if the desktop
Steam is open, `steam -shutdown` and it waits **event-driven** for it to finish (`timeout 30 pidwait
-u <uid> -x steam`) before `switch-mode-root game`; log: `closing the desktop Steam (steam -shutdown)`
(closing the desktop Steam) → `Steam cerrado limpio` (Steam closed cleanly). **Why:** the session switch restarts lightdm and **killed** that Steam;
when starting in Game Mode, Steam saw that it "did not close properly" (`Looks like steam didn't shutdown
cleanly`) and did the full verification (`Verifying all executable checksums`) instead of the
quick one (`Verifying file sizes only`). Measured on the Legion: Game Mode → desktop ~2 s; desktop
→ Game Mode **3 s** (before 21 s), also with Steam open (it closes in 2 s); at power-on after a
reboot, 6 s (full verification of 2 s, no errors). The 44 `bad CRC` binaries it saw once
were leftovers of the client switch (see above): repaired, they have not come back.

**Clean shutdown of Steam also when powering off or rebooting** (2026-10-04,
`install-passwordless-switch.sh`, common to both machines): **`/etc/runit/shutdown.d/05-close-steam.sh`**.
Steam's power menu asks for the reboot **directly from elogind** (D-Bus `login1` `Reboot`; in
its log, the answer from `:1.9` = `elogind-daemon`) **without closing itself**; then runit's shutdown
killed it and on start Steam did the full verification. The script runs in runit's stage 3
**before** `10-sv-stop.sh` (which stops lightdm and with it the session): if there is Steam, `steam -shutdown`
as its user (with the process's own environment, `chpst -u`) and waits **event-driven** (`timeout 20
pidwait -x steam`). It leaves **`/run/system-shutting-down`**, and `switch-mode-root` does nothing if it exists:
in Game Mode, when Steam ends the launcher takes it as "Cambiar a escritorio" ("Switch to Desktop") and, without that marker,
the shutdown **would change the boot mode to desktop**. `/run` is emptied at boot.
- **Valid for every software shutdown that goes through runit with the session alive:** Steam's menu, `reboot`,
  `poweroff`, `shutdown`, `halt`, `loginctl`, power button (elogind calls `/usr/bin/halt`,
  `/usr/bin/reboot`, `/sbin/poweroff`, those of `runit-void`) and critical battery. **Not** with `reboot -f`
  (does not call init) nor with a physical power-off.
- **It is not Void's documented way**: the documented one, `/etc/rc.shutdown`, is launched by
  `20-rc-shutdown.sh` **after** `10-sv-stop.sh` (with Steam already dead). `shutdown.d/` belongs to
  `runit-void` (all its files are the package's) and it is the same mechanism with which Void builds its
  shutdown (`/etc/runit/3` loads `shutdown.d/*.sh` in order); a file that belongs to no package
  survives updates. If one day it stops working, check that `/etc/runit/3` still
  goes through `shutdown.d/*.sh`.
- **Cost:** none in use (it is not a service); at shutdown, however long Steam takes to close (~2 s).
- **Logging out from the desktop (Xfce) did not go through here in time** (found on 2026-10-04 on both
  machines): with the panel's exit button, Super+Escape or Ctrl+Alt+Del, `xfce4-session`
  **closes the session first** and then asks for the reboot; when `xfce4-session` ends,
  labwc (`--session xfce4-session`) or the X of the `xinitrc` close, and Steam died with Xwayland/X (`X
  connection to :0 broken` in `webhelper-linux.txt`, without `Shutdown`; on start, `Verifying all
  executable checksums`). Xfce's autostart `RunHook`s (on logout/reboot/shutdown)
  **do not work**: `xfce4-session` 4.20 launches them without waiting for them (`xfsm-global.c`). **Fix
  (`install-passwordless-switch.sh`, step 3c): wrapper `/usr/local/bin/xfce4-session`**
  (`/usr/local/bin` goes before `/usr/bin` in the session's `PATH`): it runs the real one and, when it
  ends, `steam -shutdown` and waits **event-driven** (`timeout 20 pidwait -u <uid> -x steam`) with the
  session still alive; on reboot, `05-close-steam.sh` also finds it alive. Valid for Wayland and
  X11, it does not change Xfce's dialog (if it is canceled, Steam stays open) and without Steam it does nothing.
  It takes effect in the session following its installation. **A dirty shutdown that already happened cleans itself
  up:** the next start of Steam sees `Looks like steam didn't shutdown cleanly` and does the full verification ONCE
  (`Verifying all executable checksums`, seconds); the next close
  is already clean and the starts go back to `Verifying file sizes only` (that is what happened on both machines
  on 2026-10-04: 20:57:00 full → 20:58:06 `Shutdown` → 21:00:06 quick on the IdeaPad). There is no
  need to delete or repair anything. **Switching between Wayland and X11 desktop** with
  their launchers and Steam open: `switch-mode-root` restarts lightdm directly; since
  2026-10-04 it first closes Steam with the same block as `05-close-steam.sh` (from Game Mode
  Steam has already ended when it gets there). It is applied by repeating `install-passwordless-switch.sh`.
  **Verified on the Legion on 2026-10-04:** Steam open on Wayland → launcher "Escritorio X11" ("X11 Desktop") →
  `Shutdown` (21:12:17) and, on X11, `Verifying file sizes only`.
  **Here:** the failure was reproduced on 2026-10-04 (20:36:23, panel button). Wrapper installed
  (`sudo sh "$B/common/steam/install-passwordless-switch.sh"` + a reboot) and **verified** the same day:
  Steam open on the desktop, reboot with the panel button → `Shutdown` at 21:07:04, without
  `X connection to :0 broken`. Also verified on the IdeaPad.
- **Race with elogind when switching modes** (found on the Legion on 2026-10-04, when pressing
  "Escritorio Wayland" ("Wayland Desktop") while on Wayland): `switch-mode-root` did `sv restart lightdm` all at once;
  the new session started while elogind was still cleaning the old one and, when the user was left with no
  sessions, elogind **deleted `/run/user/1000` with the `wayland-0` just created by the new labwc**
  (directory recreated at 21:37:44; without `wayland-0` or `wayland-0.lock`). Everything that started
  afterwards fell back to X11 through Xwayland: `xfce4-session` tried to launch `xfwm4` (`Could not find a screen
  to manage`), the panel used X11 (`libxfce4windowing: Failed to fetch _NET_NUMBER_OF_DESKTOPS`, instead
  of `Window<->Workspace association is not available`), labwc kept repositioning it nonstop (`view has
  no last placement info` ~60/s in `~/.xsession-errors`) and **the screen flickered with the panels
  different** (their configuration did not change). Fix on the spot: reboot. **Permanent fix**
  (`install-passwordless-switch.sh`, step 3a): `switch-mode-root` does **`sv once mode-switch`**
  (one-shot runit service, `/etc/sv/mode-switch`, with a `down` file so that it does not
  start at power-on), which runs **`/usr/local/lib/switch-mode/restart-lightdm <uid>`**: `sv stop lightdm`, waits **event-
  driven** (`inotifywait` on elogind's state files in `/run/systemd/users` and
  `/run/systemd/sessions`) for `seat0`'s session to close and, if the user was left with no
  sessions, for elogind to delete `/run/user/<uid>` (`delete_self`); caps 10 s + 5 s; then `sv start
  lightdm`. With another session open (SSH) elogind deletes nothing and it does not wait. Log in
  `/run/switch-mode.log`. **Why runit and not a process launched from the session:** the first
  version launched it with `setsid` from `switch-mode-root`; it stopped lightdm and **died with the session**
  before starting it again (log with only `parar lightdm` / stop lightdm): the screen stayed off and
  `ssh -t lego sudo sv start lightdm` had to be done from the IdeaPad (2026-10-04). The earlier `sv restart`
  worked because runit also ran it. **Verified on the Legion on 2026-10-04**
  (Wayland → "Escritorio Wayland", the case that failed): `parar lightdm` 22:47:24.691 → `arrancar
  lightdm (0.4 s)`, `wayland-0` present and the panel through Wayland. Also installed on the IdeaPad.
  **If the screen stays off after a mode switch:** `cat /run/switch-mode.log` and, from
  another machine, `ssh -t <machine> sudo sv start lightdm`.
- **Verified on the Legion on 2026-10-04** (reboot from Steam's menu in Game Mode):
  `Shutdown` in Steam's log, the boot mode stayed in Game Mode (the marker stopped
  `switch-mode-root desktop`), and on start `Verifying file sizes only` and the interface at 4 s.

**Controllers: as a Valve controller with InputPlumber** (further down). Without it, the Legion's are
`Generic X-Box pad` (`xpad`): no back buttons or Deck-style touchpad, and **on the desktop they control
nothing** (Steam Input comes off for Xbox controllers).

**xterm as a "juego que no es de Steam" ("non-Steam game"):** `install -m 755 "$B/common/steam/xterm-steam" ~/.local/bin/` and in
Steam *Propiedades → Acceso directo → Destino* (*Properties → Shortcut → Target*) = `/home/isaac/.local/bin/xterm-steam` (the same
wrapper as the IdeaPad: removes Steam's `LC_ALL=C` and `LD_PRELOAD`; in Game Mode it loads
`.Xresources` and fills the screen). **Verified by the user** (2026-10-04) from Steam on the
desktop and inside Game Mode, **on both screens** (external monitor and the Legion's).
It is the reduced version of the IdeaPad's: it **does not carry** what SteamOS's `xterm-steam-fix` did
for the dock (§13.6/13.9 of its recipe: `DISPLAY=:0`, real DPI with `faceSize 14`, Xft antialiasing
forced). Here it was not needed; if one day the text comes out tiny or jagged on the
Legion's screen, port that.

**Firefox as a "non-Steam game" (2026-10-05): maximized and without frame.** Added to Steam
from its `.desktop` (shortcut with `Exe` = `firefox`), in Game Mode it came out **with a colored border and
could be resized, and then there was no way to go back to fullscreen**. Cause: in gamescope there is no
window manager, and with "Barra de título" ("Title Bar") unchecked (because of labwc, step 15;
`browser.tabs.inTitlebar` = 1 in `prefs.js`) Firefox draws its frame itself (client-side decorations,
`_MOTIF_WM_HINTS` = `0x2, 0x0, 0x0…`) with the borders for resizing; without a manager, nobody knows how to
"maximize". Fix: the wrapper **`firefox-steam`** (in `common/steam/`, common):

```bash
install -m 755 "$B/common/steam/firefox-steam" ~/.local/bin/
# in Steam, with Firefox completely CLOSED: Firefox → ⚙ → Propiedades → Acceso directo → Destino =
#   (Properties → Shortcut → Target =) /home/isaac/.local/bin/firefox-steam
```

- It starts Firefox with **`MOZ_GTK_TITLEBAR_DECORATION=system`**: it does not draw its frame (it asks for the system's and
  in gamescope there is none): no border or resize zones (`_MOTIF_WM_HINTS` becomes `0x2, 0x0, 0x2…`).
- Only if `XDG_CURRENT_DESKTOP` = `gamescope`: it waits **event-driven** for the window (`xdotool search --sync
  --onlyvisible --class firefox`) and sets **the main ones** (those that declare a minimum size in
  `WM_NORMAL_HINTS`; the auxiliary 1×1 and 10×10 ones, no) to the screen's size (`xdotool windowsize
  100% 100%`, at 0,0). On the desktop it only starts Firefox.
- **Verified on 2026-10-05** (user + `/proc/<pid>/environ`): Firefox launched by `firefox-steam`,
  with the variable, its two windows at 1920×1080 (the external monitor's output) and without frame. F11 still
  gives real fullscreen.
- **Trap when testing:** if Firefox was already open, `firefox` only opens another window in the existing
  process (with its frame): **close it completely** before. If the screen changes with Firefox open (monitor
  connected or removed), the window keeps the previous size: close and open.
- To bring an already shrunk window back to fullscreen without closing (what was done the first time):
  `DISPLAY=:1 xdotool windowsize <id> 100% 100% windowmove <id> 0 0` (`xdotool search --class firefox`).

