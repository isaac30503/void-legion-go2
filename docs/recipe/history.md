## History

- **2026-10-14 (public repository, done properly)** — The repository had been public since it was created
  (2026-10-10). Reviewed with best practices: **MIT** for this repository's own work, every third-party piece keeps
  its authors and license (`THIRD_PARTY.md`, `LICENSES/`), the **source of the GPL binaries** is in the Release,
  **`local.env.age` moved to a private companion repository** and removed from this one's history (`git
  filter-repo`), and **ShellCheck** passes with no errors or warnings on the 83 shell scripts (it is part of
  `install/verify.sh` now). Real bugs it found: four variables of `void-update`'s update steps leaking out of
  their function, unused variables, `rm -rf` on variables that could be empty (now `${var:?}`), unquoted paths.
- **2026-10-14 (void-update summary, half a terminal)** — The user's request: the summary lines did not fit on one
  row, and then: it must fit in half a window. Now each check is `✓|↻|⚠|ℹ  name  short text` (OK, REPAIRED,
  WARNING, NOTE; the longest line ~40 columns, names shortened: `portal-wlr`, `portal-gs`, `steamos-mgr`); the full
  text (what it is, what to do) is printed under it, wrapped to ≤ 52 columns, only for WARNING, REPAIRED and NOTE
  (e.g. "Void already has the fix"), or for every line with `void-update --summary -v`.
- **2026-10-14 (power button)** — Like the Steam Deck: press = suspend, held ~3 s = power menu, in Game Mode and on
  the desktop (`common/power-button/`; step 14, *Power button*). The Legion Go 2's firmware tells them apart by
  itself (`KEY_POWER` on release of a short press; Super+F16 while held ~3 s); misread at first as "no release
  reported", the order was the other way round for a while, until a capture with a stopwatch. Found on the way:
  elogind's default powered the Legion off from Game Mode with one press; now `HandlePowerKey=ignore`, like SteamOS.
- **2026-10-13 (Spanish aliases removed)** — The user's decision ("I did not form habits"): the old Spanish
  arguments and options are no longer accepted (`--quitar`, `--parar`, `--dejar`, `--deshacer`, `--conservar`,
  `--sin-pantalla-de-carga`, `--sin-cache`, `--resumen`, `--desde-grub`, `--vista`, `TEMA_PANTALLA`/`TEMA_EQUIPO`,
  `juego`/`escritorio`/`--puede` of `switch-mode-root`, `izq`/`der`/`arr`/`abj`/`llena`/`inicio` of the window
  scripts, `--usuario`/`--diagnostico`/`--sin-claude` of `ssh-setup`, the actions `pantalla`/`cancelar` of
  `screen-share`), `install/aliases.sh` was deleted and the sudoers rule no longer allows
  `/usr/local/bin/cambiar-modo-root`. The Xfce shortcuts of both machines were moved to
  `window-focus left|right|up|down` and `window-snap left|right|up|down|home` before. What removes the old
  Spanish-named pieces when installing (used by `install/migrate.sh`) stays.
- **2026-10-13 (`local.env` encrypted in the repository)** — `local.env` only existed on the two machines.
  Now its copy encrypted with age and a passphrase, `local.env.age`, is committed (`install/secrets.sh seal | open
  | status`; `render.sh` opens it by itself in a fresh clone; `verify.sh` fails if it is older than `local.env`).
  Point B gets `local.env` from it. Detail: `docs/sanitization.md`, *Encrypted copy*. The same day, a fresh clone
  from GitHub was checked (Release binaries, `render.sh`, `verify.sh`: all fine) and `fetch-assets.sh` got 3
  attempts per download (GitHub once answered "release not found" in the middle).
- **2026-10-11 (void-update)** — `update-system` becomes **`void-update`** (bash, `common/void-update/`), like
  CachyOS's cachy-update: rootless checks (`xbps-install -Mun`), panel icon with automatic checks (on network
  connect and every 6 h), notifications, Void's news before updating, colored list, runit services with old code,
  and the same summary (identical output, checked against `update-system --resumen`). The old name is removed
  (the user's decision); its patch folders move to `~/.local/share/void-update/patches` and
  `~/.cache/void-update/patches`. Step 5–12, *void-update*.

- **2026-10-09 (this repository)** — The Legion's documentation and pieces, translated into English and
  organized as the private GitHub repository `void-legion-go2`: same content, English names for scripts,
  commands, services and files (old → new in `docs/glossary.md`; the Spanish arguments still work and the
  installers replace the old Spanish-named pieces), messages through translation catalogs (Spanish ones =
  the original texts; `docs/i18n.md`), private values as `@NAME@` with `local.env` and `install/render.sh`
  (`docs/sanitization.md`), binaries as Release assets (`install/fetch-assets.sh`) and the full list as
  resumable stages (`install/install.sh`). Checked against the originals on the IdeaPad: same output in
  Spanish (`update-system --summary`, `audit-void.sh`, `ssh-survey.sh`, GRUB theme background, patch test).
  The root installers were not run again on the Legion with the new names: the first run of each one
  migrates that piece (see `install/README.md`). The pieces copied by hand (window scripts of step 13 and
  Steam's background autostart, point K.6) are migrated by the `rm -f` of the old Spanish names added to
  those blocks (2026-10-11): without it, `ventanas-nuevas` and `new-windows` would both run, and Steam would be
  launched twice at login.

- **2026-10-09 (Decky's Colores)** — Approved by the user: `hidapi` (Void package) for Hooandee's plugin
  **Colores**, which without `libhidapi` did not detect the controller with RGB (`driver=NullDevice`).
  It works and restores the color after suspending (step 14, *Decky Loader*; full list and *Verification*).
- **2026-10-09 (Steam's keyboard and pointer)** — Diagnosis, no changes to the system: after closing the
  on-screen keyboard, Steam sometimes stays at `Set OSK active 1` and the controller does not move the pointer
  (Troubleshooting). New `legion/diag-steam-keyboard.sh` (read-only capture, stopped
  until needed).
- **2026-10-09 (testing own patches in `update-system`)** — Approved by the user: `update-system`
  and the `build-*.sh` **test** each own patch against the new code instead of assuming
  (`common/patch-test/patch-still-needed.sh` → `~/.local/bin/patch-still-needed`, patches in
  `~/.local/share/update-system/patches/`, installed here without root with `install-patch-test.sh` from
  `/tmp`, deleted afterwards; detail in the IdeaPad recipe, step 6, *Prueba de parches propios* (*Testing own patches*)).
  Pieces: gamescope, `xdg-desktop-portal-wlr`, steamos-manager (against the latest upstream tag),
  `xfdesktop` and Thunar; InputPlumber, `extest`, the DKMS TDP and gamescope's portal are not included (no
  own patch). The assumptions of `xfdesktop` (>= 4.20.3) and Thunar (`ldd`) were removed. **`update-system`**
  (common; the same on both, sha256 `0a26a320…`): `--resumen` here **14 × OK**; the four from xbps with "el parche
  sigue haciendo falta (probado…)" ("the patch is still needed (tested…)") and steamos-manager without a note (the latest upstream tag is the
  installed one, v26.4.1: no need to test); 34.6 s the first time (download), 3.1 s afterwards (cache).
- **2026-10-09 (patched Thunar, "Establecer como fondo de pantalla" ("Set as wallpaper") on Wayland)** — Approved by the
  user (option A): own patch of Thunar's wallpaper plugin (connector through `libxfce4windowing`),
  `Thunar-4.20.10_2` **built here** without root (`common/xfce-wayland/thunar-wallpaper/`, step 15); the
  same `.xbps` for the IdeaPad. **Installation pending root**, not verified. **`update-system`**
  (common; the same on both, sha256 `020e6723…`): `Thunar` line in the summary and how to reinstall it.
- **2026-10-09 (patched xfdesktop, wallpaper dialog on Wayland)** — Approved by the user (option
  A): `xfdesktop-4.20.2_2` with the upstream commit `ed26b06a` (#350), **built here** without root
  (`common/xfce-wayland/xfdesktop-wallpaper/`, step 15, *Desktop wallpaper on Wayland*); the same
  `.xbps` for the IdeaPad. **Installation pending root** (*Pending → To do*), not verified.
  **`update-system`** (common; the same on both, sha256 `de1c1337…`): `xfdesktop` line in the summary
  where there is Xfce Wayland, and how to reinstall it in `__update_system_como_recompilar`; here, until
  it is installed, AVISO (WARNING) "xfdesktop-4.20.2_1 es el de Void, SIN el arreglo…" ("… is Void's, WITHOUT the fix…").
- **2026-10-09 (comment of `install-steam.sh`)** — Text only, no changes on this machine: the
  Intel comment of `common/steam/install-steam.sh` (common) and step 14 here said that
  Intel's VA-API would be `libva-intel-driver` (not tested); on the IdeaPad `intel-media-driver` works
  (iHD 26.3.5, `vainfo`), which `ideapad-al-dia.sh --video` installs. `sh -n` correct.
- **2026-10-08 (night, steamos-manager reference)** — Approved by the user (option C):
  **`install-steamos-manager.sh`** writes by itself, on every installation, `sha256` (the two installed
  binaries, the format that `update-system` already read) and `paquete` (the tarball's name without `.tar.gz`) in
  `/usr/local/share/steamos-manager-void/` (step 14, steamos-manager); `--remove` deletes that folder. That way
  the `sha256` put by hand by the user that same day is no longer needed (command of back then, only as
  history: the output of `sha256sum` of the two binaries to that file; the content matches what
  the installer writes now). **`update-system`** (common; `cmp` equal on both) shows the package in
  the steamos-manager line, as a note and not as an AVISO: the official `…-void` is a documented option
  (to go back), and "paquete desconocido" ("unknown package") only means installed before. `--resumen` here: 12 × OK,
  steamos-manager with "paquete desconocido (repetir install-steamos-manager.sh para registrarlo)" ("unknown package (repeat … to register it)");
  simulated without root with a copy of the folder in `/tmp` → `paquete steamos-manager-v26.4.1-void-2` and,
  with `…-void`, the official one's note (both OK). Pending root: *To do*. IdeaPad: 4 × OK (without
  steamos-manager). The new installer has not been run yet (checked only with `sh -n`).
  Also checked: `strace` is no longer there.

- **2026-10-08** — *To do* solved: `speech-dispatcher` marked as manual and the empty folders
  `/mnt/home` and `/mnt/steamos-home` deleted (checked over SSH). The `strace` question remains.

- **2026-10-08 (night, `update-system`)** — The user's request: that the summary say whether what was built here
  needs maintenance after updating. **`update-system`** (common, `common/fish/functions/update-system.fish`;
  installed on both, `cmp` equal; `.bak` in Common): warning **before confirming** if the update
  replaces a package from a local repository (generic, through the pkgdb); in the summary, one line per
  local package compared with Void's (`xbps-uhelper cmpver`; **the same revision is also an AVISO**:
  the scripts build with Void's + 1, so if Void reaches it, it is a newer build of theirs
  that xbps does not install), `ldd` also of gamescope's portal, and on one line each `steamos-manager`
  (`ldd`, reference sha256, build dependencies) and `extest` (`ldd` and what is needed to
  rebuild it); the warnings say what to do. New **`update-system --summary`** (without syncing, without
  `sudo`). Tested: `--resumen` here → 11 OK and 1 AVISO (steamos-manager "sin sha256 de referencia" ("no reference sha256"): missing
  `/usr/local/share/steamos-manager-void/sha256`, which nobody writes today; **pending** the
  user approving that `install-steamos-manager.sh` records it, or creating it by hand from the tarball
  `-void-2`: `cc464424…1586c` for `/usr/lib/steamos-manager`; solved, entry "steamos-manager
  reference"); IdeaPad → 4 OK. Previous warning and cases of
  the same revision, newer revision and missing libraries, **simulated** (list and versions
  made up), not seen in a real update. Limit: without network it is not known whether there is a new upstream
  version of steamos-manager, InputPlumber, `extest` or gamescope's portal.
- **2026-10-08 (night, the user's answers to the review)** — List K.10: the **art of Firefox in Steam**
  was put by the user by hand with SteamGridDB (Decky). K.11: **Vesktop's Rich Presence** enabled on
  purpose (`"arRPC": true` in its `settings.json`). **Bluetooth name = hostname**: applied over SSH, without
  root (`bluetoothctl system-alias Legion-Go-Gen-2`; `bluetoothctl show` → `Alias: Legion-Go-Gen-2`; not
  checked after rebooting); in step 5–12 ("Name"), K.8 and *Verification*. **`/mnt/home` and
  `/mnt/steamos-home`** (empty, copied from the live by *Source: Local*): they are deleted (`rmdir`, in *To
  do*; note in step 0, in list A and line in *Verification*). **steamos-manager's build
  dependencies: kept** (the user's decision; ≈ 470 MB; *Decided*; "How it is built" says
  how to remove them); the *Verification* line now expects `5`. `speech-dispatcher` by hand, recommended
  (*To do*, list J). `strace`: open question.
- **2026-10-08 (night)** — **system ↔ recipe review, in both directions** (read-only; nothing
  changed in the system or in this recipe except this entry). From the system to the recipe: the 127 own
  files that the audit looks at have a step (0 untracked); the 21 links of `/var/service`, the 5
  own services of `/etc/sv`, `/usr/lib/steamos-manager`, `/usr/share/{steamos-manager,inputplumber}`,
  `/usr/src` (DKMS), the manual packages (besides those of the ISO), the 15 modified package
  configuration files, the user configuration (Xfce, labwc, fuzzel, portal, WirePlumber, `extest`,
  autostart, `steam.desktop`, controller layout, `~/.ssh/config`), Claude's memory and context,
  the Steam shortcuts, Decky and its two plugins, Flatpak and the Bluetooth pairings
  match the recipe and Common. From the recipe to the system: *Verification* without root, fine,
  except what is in *Pending → To do* (`speech-dispatcher` still automatic and the build
  dependencies and `strace`, installed: 0 and 6 instead of 1 and 0). Questions to the user remain (origin of the art
  of Firefox's shortcut in Steam, empty `/mnt/home` and `/mnt/steamos-home`, Vesktop's `arRPC`,
  Bluetooth alias "BlueZ 5.86").
- **2026-10-08** — **documentation of the audit of 2026-10-08** (approved by the user; nothing changed
  in the system). Step 14, InputPlumber: **consumption measured** with `diag-inputplumber-cpu.sh` (three passes
  of 20 s; results in `logs/legion/medir-inputplumber-*-2026-10-08.txt`): 3.2–3.5 % of one core
  and ~7100–7200 fixed wakeups/s, mostly because of the body's IMUs and `/dev/uhid`; **left as is**
  (*Pending → Decided*). Step 14, steamos-manager: **`set_clocks` patch and manual clock brought back,
  verified** (01:28; clock at 2000 MHz in `manual` and back to `auto`; error counter still at
  185; checked again without root at the boot of 20:45); `speech-dispatcher` must stay
  **marked as manual** (list J, "How it is built", *Verification*); removing the build
  dependencies and `strace`, in *Pending → To do* (the user runs it). *Troubleshooting*: **Known
  noise in the logs** (one line per warning; among them, why **not** to create
  `99-valve-wifi-backend.conf` or install `wireplumber-elogind`). Audit (`audit-void.sh`) with
  Common: fidelity with nothing untracked; `gnome-software`, Flatpak and Vesktop, in the recipe (list,
  point K.11).
- **2026-10-08** — step 14 (InputPlumber): **consumption diagnostic tool**
  `diag-inputplumber-cpu.sh` (new in `legion/`, read-only; approved by the user)
  to attribute by origin InputPlumber's idle CPU. Nothing changed in the system.
- **2026-10-08** — step 14: **steamos-manager with the `set_clocks` patch** (approved by the
  user): the GPU clock is only written with the level at `manual`; the `Error setting
  manual GPU clock` with the manual clock disabled come to an end and the manual clock is still available. Built here
  without root (`build-steamos-manager.sh`, new; build dependencies installed by the user;
  remove them when done, command in step 14), 248/248 tests; in Common the patch, the script and
  `steamos-manager-v26.4.1-void-2.tar.gz` (the official one stays). `install-steamos-manager.sh` uses the
  `-2` (header up to date). It is installed with `sudo sh /tmp/instalar-steamos-manager-parche.sh` (run by the
  user). Troubleshooting point 3, *Verification* and *Pending* up to date (the patch leaves
  *Optional*). **Still to verify** (*Pending*, "To test").
- **2026-10-08** — step 14: **the manual GPU clock and the overdrive come back** (approved by the
  user). They had been removed that same night (entries below) due to a misunderstanding: it was approved
  believing that it was no use here, and it was (2900 MHz in `manual`, 2026-10-04). `install-steamos-manager.sh`
  no longer removes `[gpu_performance]` (header up to date); `gpu-overdrive.sh` again applies (no option)
  and removes (`--remove`), and keeps the rebuild of the initramfs of all the kernels; it goes back to list
  J, to the Reinstall table and to the blocks of step 14. The `Error setting manual GPU clock` with
  the manual clock disabled come back and are documented as expected (Troubleshooting, point 3); the
  `set_clocks` patch, in *Pending → Optional*. On the Legion it is applied with `sudo sh
  /tmp/legion-gpu-manual.sh` (run by the user) and a reboot. *Verification* up to date. **Still to
  verify after rebooting** (*Pending*, "To test").
- **2026-10-08** — **verification after rebooting** of the two changes below. **`rtkit`** (boots
  at 00:11 and 00:48; IdeaPad, 00:14 and 00:41): no `/var/service/rtkit`, a single `rtkit-daemon`
  with parent `runit` and the `data-loop` in RR 20 (*Watch*). **GPU always on auto** (00:48): level
  `auto`, `ppfeaturemask` `0xfff7bfff`, `/etc/modprobe.d` empty, no new `manual GPU clock`
  (183, the last one from before the change), TDP and Performance profiles working (user). Step 14,
  steamos-manager: verification and why the Deck (Van Gogh) does not give those errors and this one (SMU 14) does.
  *Pending → To test* stays empty.
- **2026-10-08** — step 14: **GPU always on `auto`; no manual GPU clock or overdrive**
  (approved by the user). Steam resent the saved clock (2900 MHz) every time it reapplied the
  profile and SMU 14 rejects it outside `manual` (179 `Error setting manual GPU clock: Invalid
  argument`). `install-steamos-manager.sh` removes `[gpu_performance]` from `legion-go-series.toml`;
  `gpu-overdrive.sh` stays only for `--remove` (now it rebuilds the initramfs of all the kernels) and leaves
  list J and the Reinstall table. It is applied with `sudo sh /tmp/legion-gpu-auto.sh` (run by the
  user) and a reboot. Troubleshooting point 3 and *Verification* up to date. Patching
  steamos-manager was discarded. Verified after rebooting (verification entry above).
- **2026-10-08** — **`rtkit` out of runit** (on both machines, approved by the user): only D-Bus
  starts it on demand (`org.freedesktop.RealtimeKit1.service`); with runit besides they clashed (loop of
  2026-10-07, *Watch*). `like-steamos.sh` (step 14, "SteamOS settings") no longer links it and removes the
  link of old installations; on the already installed machines it is removed with `sudo sh
  /tmp/quitar-rtkit-runit.sh` (run by the user). New line in
  *Verification*. Verified after rebooting (verification entry above).
- **2026-10-07** — maintenance agent `mantenedor-void` (Claude Code, `claude/agents/`) and its
  audit `common/agent/audit-void.sh`, on both machines (step 7). It found the `rtkit` loop
  (*Watch*). Dump of what needs root: `zz-switch-mode`, `cap_sys_nice`, overdrive in the initramfs,
  as the recipe says; `sudoers.d/wheel` with permissions 644 (from Void's installer, the same on the IdeaPad;
  `visudo -c` warns, sudo accepts it); paired over Bluetooth, besides the headphones, the keyboard
  **8BitDo Retro 87 Keyboard X** (`@KEYBOARD_BT_MAC@`) and the mouse **8BitDo Retro R8 Mouse**
  (`@MOUSE_BT_MAC@`) (point K.8).
- **2026-10-07** — **fidelity review against the running Legion:** everything that does not belong to a package
  (75 system files and 40 user files) comes from Common, copied as is or written by a script whose
  lines match what is installed (variables aside); the 12 modified package files have
  exactly the changes their scripts describe; the manually installed packages are all in the
  recipe or in the scripts (except those of the ISO), and those that the recipe considers removed are not there; TDP
  sources, InputPlumber and `steamos-manager` manifests, `.xbps` of the portal and of gamescope: identical to what is
  installed. Missing was **the audio order of `audio-priority`**: copy in `legion/wireplumber/` and point
  K.12. Corrected: two lines of *Verification* (count of `XDPW_PERSIST_MODE`, Remote Play capture),
  the detail of the Remote Play log, the saved package of the portal (now the three-patch one, with the
  sha256 of its binary), `udev-net` (it acted twice) and Firefox in Steam (it is added).
- **2026-10-07** — review of all the documentation for reinstalling (the two recipes, the two contexts):
  here, the rule of the scripts in `~` now says that they leave when finished (point M) and the
  *Verification* line of Remote Play was wrong (`xbps-query -p` accepts a single package); `legion/xfce/`
  up to date (`xfce4-panel.xml`: known players; `xfce4-notifyd.xml`: Vesktop). On the IdeaPad,
  full list for reinstalling and the order 14 → 15 corrected (there it was already like here).
- **2026-10-07** — step 14: Remote Play in Game Mode (the guest only saw the waiting screen):
  `pipewire-32bit` and `libspa-videoconvert-32bit` were missing (Steam's client is 32-bit) and Mesa's VA-API
  (`mesa-vaapi`, `mesa-vaapi-32bit`); now `Desktop PipeWire NV12 DMABUF + VAAPI H264`.
  `install-steam.sh` includes them.
- **2026-10-07** — screen sharing verified end to end after all the changes of the day: on the
  desktop (a single question when sharing and when changing streams; Steam without a dialog on start,
  restored by token) and in Game Mode (whole screen with the game, through gamescope's portal).
- **2026-10-07** — step 14/15: screen-share chooser without bar or buttons, with rounded
  corners and buttons that look like buttons; third portal patch (`0003`): the chooser knows which app
  is asking (before, a stuck Firefox request also showed up). Solved what was in "To decide".
- **2026-10-07** — step 14: second patch of the wlroots portal (`0002`): when changing streams in
  Vesktop, the request that arrived without a token (the previous restored session closed without starting) reuses
  that source: no repeated chooser. Diagnosed with the portal in `-l DEBUG`.
- **2026-10-07** — step 14/15: screen-share chooser **always on top** (labwc rule +
  fixed identifier; it stayed behind Vesktop and blocked the portal). Windows that give no image
  while not visible (Steam through Xwayland): fixed note in the chooser; discarded detection through
  thumbnail (not reliable) and bringing the window to the front (`wlrctl`, workspace jumps). Documented
  Vesktop's bug when canceling in the portal and the "who is asking" limitation.
- **2026-10-07** — step 14: sharing windows without repeating the dialog, **without depending on timings**:
  `xdg-desktop-portal-wlr` 0.8.4_2 with an own patch that also restores windows
  (`legion/portal-wlr-patch/`); the chooser loses its memory (the Steam rule stays);
  `update-system` warns if Void replaces the portal.
- **2026-10-07** — **full review of the recipe against the running Legion:** of 96 own installed
  files, 41 identical to their Common copy, 2 adapted on purpose (`labwc/environment` with the
  keyboard, the brightness hook) and the rest generated by the installers, identical to what their
  current versions write (variables aside); the 54 Common paths cited exist; the
  *Verification* block gives what is expected. `screen-share/install.sh` and `build-gamescope.sh` were run
  again: same files and the same gamescope binary. Corrected what had become old
  (Vesktop's options in Steam, "black full screen" in Game Mode, pending check on the
  Deck, `drm_info`/`wlr-randr` already removed, `STEAM_DISPLAY_REFRESH_LIMITS` listed as not copied,
  versions of Decky and of the fallback kernel, comments of the *Verification* block for Wayland);
  added *Troubleshooting* for screen sharing and the exact command to install the saved `.xbps`.
  `legion/xfce/xfce4-panel.xml` up to date.
- **2026-10-07** — step 14: screen sharing in Game Mode like SteamOS: its gamescope portal
  (`portal-gamescope/`, with a wrapper for systemd's journal), Vesktop through the portal (whole screen,
  games included) and **gamescope 3.16.30_2 with an own patch** against a race in its PipeWire
  capture (diagnosed with `gdb`); `update-system` warns if it is lost. Debugging removed (`gdb`,
  `gamescope-dbg`, `~/src/void-packages`).
- **2026-10-06** — step 14: the portal's token (`XDPW_PERSIST_MODE=permanent` in a user D-Bus
  service) against Chromium/Vesktop's double question (screens; windows, the chooser); the desktop
  Steam asks for a screen on start (to check whether it remembers it); in Game Mode, black full
  screen and black Vulkan games except `ENABLE_GAMESCOPE_WSI=0` per game (to test).
- **2026-10-06** — step 14: Flatpak portals (`xdg-desktop-portal` + `-gtk` + `-wlr`), `fuzzel` as
  fallback and own chooser with previews for screen sharing (`legion/screen-share/`),
  which answers Vesktop's second request by itself. Pending: nothing to do.
- **2026-10-06** — step 15: focus no longer raises the window (`raiseOnFocus` no in labwc, `raise_on_focus`
  false in xfwm4); it is raised with a click. The same on the IdeaPad.
- **2026-10-06** — step 14: Discord via Flatpak (GNOME Software, Flathub for the user, Vesktop) and
  minimalist Vesktop art with Discord's colors (`art-vesktop/generate.py`), and the same icon in
  Xfce (copy of the launcher with its own `Icon=`, by the same script) and in the tray (Vesktop's
  `userAssets`, by the same script). Pending: portals.

- **2026-10-06** — step 15: `<xwaylandPersistence>yes` in the common `rc.xml` (on the IdeaPad, xterm came out without a
  theme: Xwayland shut down after 10 s without X programs and lost `~/.Xresources`; here Steam in the background
  kept it alive). Detail in the IdeaPad recipe, step 15.

- **2026-10-06** — cleanup finished (`.bak` of `/etc`, `drm_info`/`wlr-randr`, Borderlands 3's
  launch option): **nothing pending**; only the *Watch* points remain.

- **2026-10-05** — step 14: Firefox in Game Mode maximized and without frame (`firefox-steam`:
  `MOZ_GTK_TITLEBAR_DECORATION=system` + `xdotool windowsize 100% 100%`).

- **2026-10-05** — functions `audio-ctrl` and `audio-priority` adapted to Void (`fish/void/`; detail in
  step 6 of the IdeaPad recipe) and installed here and on the IdeaPad.

- **2026-10-05** — **final product cleanup**: out of `~` the scripts, copies and logs of the
  installation (all verified identical in Common; logs and `.bak` of `/etc` archived in
  `logs/legion/`). New step M in the list; *Troubleshooting* uses the scripts from Common.

- **2026-10-05** — unplugged suspend measured: 54 → 53 % in 30 min (29.9 min of real sleep),
  ≈ 2 %/h ≈ 1.5 W. Nothing pending to test on the Legion.

- **2026-10-05** — step 14: Steam's FPS limit gave half: the screen modes that
  gamescope fabricates (outside the native 144 Hz) lose one refresh in every two. Range
  `STEAM_DISPLAY_REFRESH_LIMITS=48,144` in the launcher and **VRR** enabled in Steam: exact limits.

- **2026-10-05** — step 14: **SteamOS settings**, compared live with a Steam Deck
  (`like-steamos.sh`: `split_lock_mitigate=0`, inotify, `fq_codel`, huge pages `always`, `rtkit`
  → real-time audio, `earlyoom`, `gamemode`, `gamescope-32bit`, `-pipewire`, `preempt=full`,
  `memlock` 8 MiB; `install-game-mode.sh`: gamescope's Vulkan layer, FPS limiter and
  variable rate shading). **All verified**, also in Game Mode with Borderlands 3 (gamescope's layer
  loaded in the game, FPS limit at 30 and half-rate shading working).
  Gyroscope of each controller: left as is on purpose (tests in *Pending*).

- **2026-10-05** — step 14: **microSD** (SteamOS's Steam library + emulators) always mounted
  at boot on `/mnt/microsd` (`fstab` with `nofail`; Steam, with the new path),
  verified after rebooting (44 apps). Cleanup: `.bak` and diagnostic outputs (archived in
  Common), `/etc/plymouth`; Rust, `gcc-multilib` and the diagnostic tools stay.

- **2026-10-05** — recipe **reordered for reinstalling** (without losing text; the step numbers do not
  change): full list in *Reinstall* (with what is done by hand in Steam, Firefox and the
  controller), the Legion sections of step 14 in installation order, new *Troubleshooting*,
  *Pending* split into to test/to decide/watch/cleanup (what was verified moves to
  *Verification*). Copy of `legion/xfce/` brought up to date (the `displays.xml` is now Wayland's).
  Corrected what was old: `udev-net` already acted and is also on the IdeaPad, the gyroscope in a game
  was already verified, fallback kernel 6.12.112, leftover `/etc/plymouth`.

- **2026-10-04** — metapackages `linux` and `linux-headers` held (6.18 LTS). `update-system` with a final summary (OK/REPARADO (REPAIRED)/AVISO (WARNING)): DKMS TDP, kernel
  held, gamescope, libraries of InputPlumber/`steamos-manager`/`extest`, `.new-*`, reboot.

- **2026-10-04** — Borderlands 3 (Proton 9.0-2RC, without launch options): Windows game and
  gyroscope in a game, verified.

- **2026-10-04** — step 14: **body's gyroscope in Steam** (InputPlumber: `imu` sources without
  `blocked` and `mount_matrix` ×100/×10 because of the kernel's wrongly declared scale); on the desktop,
  as mouse with the thumb on the right trackpad.

- **2026-10-04** — "Modo Juego" (Game Mode) launcher from Xfce Wayland verified; detached controllers verified (buttons; the gyroscope of each controller, not tested).

- **2026-10-04** — step 14: **hibernation verified** (twice) and elogind hook that restores the
  built-in screen's brightness on wake.

- **2026-10-04** — `udev-net` acted in a real boot (Wi-Fi recovered as `wlp193s0`);
  long suspend (several hours, plugged in) without incidents.

- **2026-10-04** — step 14: Steam in the background on the desktop with **`extest`** (controller pointer
  on Wayland) and trackpad click at "Pulsación doble" ("Double Press"); **race with elogind** when switching
  modes (panels through X11 and flicker) → `restart-lightdm` under runit (`sv once mode-switch`;
  the version with `setsid` left the screen off), verified. Step 15: Steam's keyboard is excepted
  from the window rules.

- **2026-10-04** — step 14: **Steam closes cleanly when logging out from the desktop** (wrapper
  `/usr/local/bin/xfce4-session`; before it died with the session and on start it did the full
  verification) and when switching between Wayland and X11 (`switch-mode-root` closes Steam before restarting
  lightdm). Verified on both machines.

- **2026-10-04** — step 14: InputPlumber **hides the originals** (wrapper `inputplumber-udevadm`
  with the `M:`/`U:` lines that eudev does not give, and `acl-progs`): Steam sees a single controller.

- **2026-10-04** — `s2idle` suspend verified (controller, Wi-Fi and InputPlumber fine on wake).

- **2026-10-04** — step 14: **steamos-manager** (runit service with `tracefs`; the user one
  from the launcher), without GPU power profile (it does not exist in the normal kernel), **overdrive**
  for the manual GPU clock, and Wi-Fi power saving off in Steam. Steps 2–3:
  **`udev-net`** (the Wi-Fi stayed at `wlan0` unmanaged: udev event lost at boot).

- **2026-10-04** — step 14: **fine TDP**, `lenovo-wmi-gamezone`/`-other` of 6.18.55 via DKMS
  (`custom` profile and `ppt_*` limits from 5 to 35/37/45 W).

- **2026-10-04** — step 14: **InputPlumber** 0.81 (official binary, runit service) with profile
  `deck-uhid`: the controller shows as a Valve controller, the same as in SteamOS.

- **2026-10-04** — step 15: `wallpaper-watcher` (internal screen without wallpaper when coming from Game Mode); HDR/VRR and PSR discarded. Order table with steps 14–15 and the network fixes.
- **2026-10-04** — step 14: Decky Loader (SteamGridDB, CSS Loader) and xterm library art.
- **2026-10-04** — steps 2–3: Wi-Fi without power saving (SSH did not get in in either direction).
- **2026-10-04** — step 14: Game Mode follows the monitor hot-connected or removed
  (options and variables of SteamOS's session, without the Steam Deck's resolution ones).
- **2026-10-04** — step 14: Volantes cursor in Game Mode (SteamOS's `steam` was not found).
- **2026-10-04** — steps 2–3: avahi only over Wi-Fi (with the dock it renamed itself to `-3`).
- **2026-10-04** — step 8: **hidden GRUB** (0 s, without video mode change) and **without Plymouth**;
  Game Mode **without loading screen** (`--no-loading-screen`): "lo minimalista" ("the minimalist way"). Steam closed
  cleanly when switching modes and when powering off.
- **2026-10-03** — step 8: Plymouth with frames at the panel's scale (112 px, `DeviceScale=1`).
- **2026-10-03** — step 8: GRUB with the XS1000's Windows entry (`chainloader`), silent
  boot and the void-xterm theme adapted to 1920×1200 (scaled; identical on the IdeaPad).
- **2026-10-03** — `new-windows` exits on Wayland; the three window scripts, installed
  on the IdeaPad too (its recipe, step 13).
- **2026-10-03** — created. Live test, rescue of SteamOS's `/home`, installation (32 GB
  swap, traps of `p8` mounted and of the installer's saved configuration), steps 2–3
  (6.18.55, US international keyboard, mDNS), SSH access in both directions, X11 desktop
  like the IdeaPad, and per-monitor windows (snap, focus, new windows almost maximized,
  Super+Shift+Space).
