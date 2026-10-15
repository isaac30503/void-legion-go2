# Screen sharing

Sharing a screen or a window from Flatpak apps (Vesktop) **on the desktop** and the **whole Game Mode screen, games
included**, through the desktop portals. Three own patches and an own chooser make it ask once and work reliably.

## On the desktop (Xfce on Wayland)

### Install

```bash
sudo xbps-install -S xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr grim fuzzel
bash "$B/legion/portal-wlr-patch/build-portal-wlr.sh"            # the wlroots portal with our 3 patches (without root, ~1 min)
sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs xdg-desktop-portal-wlr   # with -f if that revision is already installed
rm -rf ~/src/void-packages
bash "$B/legion/screen-share/install.sh"                          # the chooser (without root; --remove → back to fuzzel)
install -D -m 644 "$B/legion/fuzzel.ini" ~/.config/fuzzel/fuzzel.ini
sudo reboot                                                        # a new session was not enough the first time
```

The patched `xdg-desktop-portal-wlr-0.8.4_2` is also a Release asset (sha256 `845a8b54…`). Void's
`/usr/share/xdg-desktop-portal/xfce-portals.conf` routes `ScreenCast` to `wlr` (labwc's capture protocol, through
PipeWire) and the rest to `gtk`: nothing to configure. Without the portals Vesktop chats and calls but cannot open
links, attach files or share the screen.

- **The chooser `screen-share`** (`~/.local/bin/screen-share`, Python + GTK 3): a "Compartir pantalla" ("Share
  screen") window with Discord's colors, tabs **Aplicaciones** (Applications) and **Pantallas** (Screens) and a
  thumbnail per source (`grim -s 0.25 -o <output>` / `grim -T <identifier>`); a click shares, `Esc` or "Cancelar"
  cancels. It talks to the portal as a `dmenu` chooser (`Monitor: …` / `Window: …` lines; the chosen one back;
  nothing = canceled). No bar, rounded corners, always on top (labwc rule; [windows](../5-desktop/3-windows-and-shortcuts.md)):
  **while a chooser is open the portal attends no other request**. **Per-program rules** (`RULES = {"steam":
  "screen"}`): it reads which app is asking and grants Steam the screen without a dialog (the desktop Steam runs with
  `-pipewire` and asks for capture permission on every start, for Remote Play and recording; it closes the capture at
  once). Log: `~/.cache/screen-share.log`.
- **`install.sh`** writes `~/.config/xdg-desktop-portal-wlr/config` (`[screencast]` `chooser_type=dmenu`,
  `chooser_cmd=` the chooser) and **`~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service`**
  (the package's, with `Exec=/usr/bin/env XDPW_PERSIST_MODE=permanent /usr/libexec/xdg-desktop-portal-wlr`), reloads
  D-Bus and restarts the portal (**that cuts a running stream**).
- **Why it asked twice or three times:** Chromium (Vesktop) opens a session for the preview of its configuration
  window and another to stream, and skips the second question only with the portal's **restore token**. The portal
  gives it only with `XDPW_PERSIST_MODE` and only for screens. **Our patches** (`legion/portal-wlr-patch/`):
  `0001-screencast-restore-window-sessions` returns the token for windows too (the `ext-foreign-toplevel` identifier);
  `0002-screencast-reuse-aborted-restored-source` reuses the source of a restored session that closed before starting
  (when switching streams Chromium was left without a token and the chooser came back); `0003-screencast-pass-request-to-chooser`
  exports `XDPW_REQUEST_HANDLE` and `XDPW_APP_ID` so the chooser knows exactly which app asks.

### Check

```bash
cat ~/.config/xdg-desktop-portal-wlr/config
tr '\0' '\n' < /proc/$(pgrep -n -f '^/usr/libexec/xdg-desktop-portal-wlr')/environ | grep XDPW   # XDPW_PERSIST_MODE=permanent
xbps-query -p pkgver,repository xdg-desktop-portal-wlr                                            # 0.8.4_2 … hostdir/binpkgs
tail ~/.cache/screen-share.log                                                                    # pide: dev.vencord.Vesktop
```

Each stream calls the chooser **once**; reconfiguring or streaming again asks anew.

### Problems

1. **The chooser does not show up:** is one already open (`pgrep -af 'screen-share$'`)? Is the labwc rule there
   (`grep -c screen-share ~/.config/xfce4/labwc/rc.xml` → 1)? If nothing reached the log, Vesktop is stuck after a
   canceled share (a known Electron bug on Wayland): **quit Vesktop from its tray icon and open it again**. Then
   `install.sh` again.
2. **It asks twice:** the portal lacks `XDPW_PERSIST_MODE` or is not the patched one (checks above); after installing
   the patched portal, reboot. To see the requests: run the portal by hand with `-l DEBUG`
   (`XDPW_PERSIST_MODE=permanent setsid -f /usr/libexec/xdg-desktop-portal-wlr -r -l DEBUG > /tmp/xdpw.log 2>&1`).
3. **A window is chosen and Vesktop's window does not appear:** that window is giving no image (some windows on
   another workspace or minimized, e.g. Steam's): look at it for a moment and come back. The chooser says so at the
   bottom of "Aplicaciones". The **Pantallas** tab does not have this problem.
4. **The chooser shows up by itself at login:** Steam; the rule should handle it (`steam: regla 'pantalla'` in the
   log); if another program shows, adjust `RULES`.

## In Game Mode

gamescope composites outside X, so by default a full-screen share is black and Vulkan games (gamescope's WSI layer)
too. SteamOS has a portal for this; here it is installed too, and Vesktop is told to use it:

```bash
sudo sh "$B/common/steam/portal-gamescope/install-portal-gamescope.sh"   # SteamOS's portal (--remove)
bash "$B/common/steam/gamescope-patch/build-gamescope.sh"               # gamescope + our patch (without root; ~6 min)
sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs gamescope      # the revision with the patch
sudo setcap cap_sys_nice=eip /usr/bin/gamescope && getcap /usr/bin/gamescope
rm -rf ~/src/void-packages                                              # 1.1 GB
```

If Void's template is still at 3.16.30_1, the Release's `.xbps` works too, with an index next to it:
`mkdir -p /tmp/gs && cp "$B/common/steam/gamescope-patch/gamescope-3.16.30_2.x86_64.xbps" /tmp/gs/ && xbps-rindex -a /tmp/gs/*.xbps && sudo xbps-install -R /tmp/gs gamescope`
(and the `setcap`). `install-game-mode.sh` already carries the portal's hook.

- **`xdg-desktop-portal-gamescope`** (Valve's package from SteamOS `holo-3.8`, BSD-3-Clause, unchanged; sha256 of the
  package `3929455f…` and of the binary `b449321f…`, checked by the installer): `ScreenCast` delivers **gamescope's
  whole image** (its PipeWire node `gamescope`), games included; screen only, no windows (one app is shown at a time
  anyway). Installed in `/usr/local` with `share/xdg-desktop-portal/gamescope-portals/` (`default=gamescope`).
  Unpacked with Python's `compression.zstd` (Void has no `zstd` tool).
- **Journal wrapper:** the binary logs to systemd's journal and crashes without its socket (`panicked at
  src/main.rs:22:10 … NotFound`). `xdg-desktop-portal-gamescope-void` runs it inside `bwrap` with a private `/run/systemd`
  and its own socket, and writes the messages to `~/.local/state/portal-gamescope.log`.
- **The launcher** exports `XDG_DESKTOP_PORTAL_DIR` before its D-Bus bus and, inside gamescope, runs
  `dbus-update-activation-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP GAMESCOPE_WAYLAND_DISPLAY XDG_DESKTOP_PORTAL_DIR`
  (log line `== portal de gamescope: …`).
- **gamescope's patch** (`common/steam/gamescope-patch/0003-pipewire-fix-use-after-free.patch`): a race in
  `src/pipewire.cpp` (`request_buffer()` takes a buffer and marks it afterwards; a PipeWire renegotiation in between
  freed it) crashed gamescope when starting or reconfiguring a stream (`Segmentation fault` after
  `pipewire: warning: out of buffers`). A mutex between "take + mark" and "remove" fixes it. The build is
  reproducible (same `/usr/bin/gamescope` sha256). Diagnosis tool: `legion/diag-gamescope-pipewire.sh` (attaches `gdb`
  in the background; needs `gamescope-dbg` from Void's debug repository).
- **Vesktop's launch options in Steam** (Propiedades → Opciones de lanzamiento / Properties → Launch Options), so that
  Chromium uses the portal: `"run" "--branch=stable" "--arch=x86_64" "--command=startvesktop" "--file-forwarding" "--env=XDG_SESSION_TYPE=wayland" "--env=WAYLAND_DISPLAY=gamescope-0" "dev.vencord.Vesktop" "--ozone-platform=x11" "@@u" "@@"`.
  No chooser appears; Vesktop's configuration window → streams the whole screen. In it, audio source **"Todo el
  sistema" ("Entire system")**, or only Steam's menu is heard.

### Problems

1. **Black or no stream:** `grep "portal de gamescope" ~/.local/state/steam-game-mode.log` and
   `cat ~/.local/state/portal-gamescope.log`; if it crashed on entry, leave Game Mode and come back (the main portal
   looks for it only on start). And the launch options above.
2. **gamescope crashes back to the desktop:** is it still the patched one? `xbps-query -p pkgver,repository gamescope`
   → `3.16.30_2` and `hostdir/binpkgs` (`void-update` warns when Void replaces it); otherwise rebuild, install and
   `setcap`.
3. **Only Steam's menu is heard:** "Todo el sistema" ("Entire system") as the audio source.
