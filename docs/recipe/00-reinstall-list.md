## Reinstall: the order, at a glance

| Step | What | How |
|---|---|---|
| 0–1 | Live, rescue, installation | below (steps 0 and 1) |
| 2–3 | xbps and the whole system, US intl keyboard, SSH + mDNS (**reboot**); avahi only over Wi-Fi, Wi-Fi without power saving and `udev-net` | `sudo bash "$B/legion/steps-1-to-3.sh"` → `sudo sh "$B/legion/avahi-wifi-only.sh"` → `sudo sh "$B/legion/wifi-no-powersave.sh"` → `sudo sh "$B/legion/udev-net.sh"` |
| 4 | SSH access in both directions | own key + `~/.ssh/config` |
| 5–12 | X11 desktop: packages, fish, fonts, themes, xterm, fastfetch, login screen | `desktop-1-root.sh` → user part → `desktop-2-root.sh` |
| 13 | Xfce configuration (**with the session closed**) + per-monitor windows | copy `legion/xfce/` + window scripts |
| 7 | Claude Code and its context | official installer + `CLAUDE-void-legion.md` + memory + log in |
| 8 | GRUB: Windows on the XS1000, silent boot, theme and **hidden GRUB**; **no Plymouth** (**after 10**; reboot) | `sudo bash "$B/legion/grub-root.sh"` → `sudo sh "$B/legion/grub-hidden.sh"` |
| 14 | Steam and Game Mode (no loading screen), desktop Steam with `-steamdeck`, xterm as a game, Decky, xterm art, **InputPlumber**, **TDP (DKMS)**, **steamos-manager** + overdrive (reboot), Steam in the background + `extest` (user), `brightness-on-wake.sh` | scripts from `common/steam/` in `~/steam/`; then `install-inputplumber.sh`, `tdp/install-tdp.sh`, `steam/steamos-manager/install-steamos-manager.sh` and `gpu-overdrive.sh` (order in step 14); `sudo xbps-pkgdb -m hold linux linux-headers`; `sudo bash "$B/legion/like-steamos.sh"`; `sudo sh "$B/legion/microsd-at-boot.sh"` (Steam closed); in Steam, "Habilitar VRR" ("Enable VRR") |
| 15 | Xfce on Wayland (labwc), **before the reboot of 14**; brings `wallpaper-watcher` | `sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"` |
| — | Verification | at the end |

The own scripts are in `<repo>/legion/` and the common ones (Steam, Xfce Wayland…) in `<repo>/common/`.
Originally they were copied to `~` before launching them, **with what they need next to them**
(`inputplumber-udevadm`, `inputplumber-x86_64.tar.gz`, the `tdp/` folder; the Steam ones to `~/steam/`, with
their `steamos-manager/` folder). With this repository they are launched from `"$B"`, where all of that
already is next to them (list, point B).

### Full list, in order (including what is done by hand)

Everything to do in a reinstall, from start to finish, including what is not a
script (Steam, desktop and controller settings). The reason and the check for each line,
in its step. **The blocks are bash:** the terminal opens fish, so first type `bash`
(in fish, `D="…"` is an error; there it would be `set D "…"`). **Every block assumes `B` set as in point
B** (`B="$REPO/build"`); in a new terminal, set it again. (Originally the files came from `Common`, mounted
from the graphical session: Thunar or `udisksctl mount -b /dev/sda4`; over SSH it is not possible.)

> `install/install.sh --list` shows this same list as numbered stages, and `install/install.sh` runs the
> scripted ones in this order (see [`install/README.md`](../../install/README.md)); what is done by hand
> (Steam, desktop) it shows and waits for.

**A. Installation (steps 0–1).** Void live (`void-live-x86_64-20250202-xfce.iso`, with Ventoy) →
`sudo void-installer` with the table of step 1, without forgetting its **two traps** (`p8` mounted and the
saved configuration). When finished, from the Legion, the `authorized_keys` line of step 1
so that the IdeaPad can get in. If in the live something was mounted on `/mnt` (rescue, step 0), already in the
installed system: `sudo rmdir /mnt/home /mnt/steamos-home` (empty; step 0).

**B. The repository on the machine.** Originally: copy the scripts from `Common` to `~` (with `Common`
mounted). With this repository: clone it, bring the binaries of the Release, get `local.env` back from its
encrypted copy (`local.env.age`, in the private repository `<owner>/void-legion-go2-private`; asks the passphrase
kept in the password manager; docs/sanitization.md) and
make `build/` (none of this needs root but installing `age`; the repository and its Release are public, but `gh`
asks to log in once, `gh auth login`, to read the private repository with `local.env.age`):

```bash
sudo xbps-install -S git github-cli age          # if they are not there yet
gh auth login                                    # GitHub account that owns the private copy of local.env
REPO=~/src/void-legion-go2
gh repo clone isaac30503/void-legion-go2 "$REPO"
bash "$REPO/install/fetch-assets.sh"             # binaries of the Release, checked with sha256
bash "$REPO/install/secrets.sh" open             # local.env from the private repository's local.env.age (the passphrase); without it:
#   cp "$REPO/local.env.example" "$REPO/local.env" && chmod 600 "$REPO/local.env" && nano "$REPO/local.env"
bash "$REPO/install/render.sh"                   # build/: the clone with the values filled in
B="$REPO/build"
```

**C. System, keyboard and network (steps 2–3).**

```bash
sudo bash "$B/legion/steps-1-to-3.sh"       # ends with "DONE OK"; if a new OpenSSH comes in, SSH is cut until reboot
sudo reboot
sudo sh "$B/legion/avahi-wifi-only.sh"     # with the dock, the name is not renamed to -3
sudo sh "$B/legion/wifi-no-powersave.sh"     # without this, SSH does not get in in either direction
sudo sh "$B/legion/udev-net.sh"            # the Wi-Fi that udev skips at boot
```

**D. SSH in both directions (step 4).** On the IdeaPad, `ssh-keygen -R Legion-Go-Gen-2.local`
(the host key changes on reinstall). On the Legion, the block of step 4 (own key,
`~/.ssh/config`) and add its `id_ed25519.pub` to the IdeaPad's `authorized_keys`.
`legion/ssh-config` already also brings `Host deck` (Steam Deck, `steamdeck.local`, user `deck`;
since 2026-10-05): to get in, `ssh-copy-id deck` (asks for `deck`'s password once; on the
Deck, SSH is enabled in its Konsole with `passwd` and `sudo systemctl enable --now sshd`).

**E. X11 desktop (steps 5–12).** `sudo bash "$B/legion/desktop-1-root.sh"` → the block of the *User
part* of step 5–12 → `sudo bash "$B/legion/desktop-2-root.sh"`.

**F. Xfce configuration (step 13), with the session closed.** The block of step 13
(`pkill -u isaac -x xfconfd` and the copies of `legion/xfce/` and of the window scripts).

**G. Claude Code (step 7).** The block of step 7 (with the `mantenedor-void` agent, `void-maintainer` here) and log in on
the Legion itself.

**H. GRUB (step 8), without Plymouth.** With the XS1000 connected:

```bash
sudo bash "$B/legion/grub-root.sh"         # Windows entry, silent boot, theme
sudo sh "$B/legion/grub-hidden.sh"         # hidden GRUB (0 s)
udisksctl unmount -b /dev/sda4   # Common, before rebooting
sudo reboot
```

Do not run `install-plymouth.sh` (the user's decision, 2026-10-04).

**I. Steam and Game Mode (steps 14 and 15).**

```bash
sudo sh "$B/common/steam/install-steam.sh"
```

Log out and log back in (`nofile` limit). **Before opening Steam for the first time**, its
desktop launcher with `-steamdeck` and `extest` (so it does not switch clients when alternating with
Game Mode; see "Why Steam took…" and "Controller on the desktop"):

```bash
D="$B"
mkdir -p ~/.local/share/applications ~/.local/lib/extest
cp "$D/legion/steam/steam-extest.desktop" ~/.local/share/applications/steam.desktop
install -m 755 "$D/legion/steam/extest/libextest.so" ~/.local/lib/extest/
```

Open Steam **from the menu** (not with `steam` in an xterm): it updates itself (~500 MB) and you
log in. Then:

```bash
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen
sudo sh "$B/common/power-button/install-power-button.sh"   # power button: press = suspend, held ~3 s = menu, like the Deck (step 14)
sudo sh "$B/common/steam/test-direct-session.sh"
sudo sh "$B/common/steam/install-passwordless-switch.sh"
sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"   # step 15: BEFORE rebooting
sudo reboot                                       # goes straight into Game Mode
```

**J. The Legion's own things (step 14).**

```bash
sudo bash "$B/legion/install-inputplumber.sh"              # Valve controller, back buttons, touchpad and gyroscope
sudo bash "$B/legion/tdp/install-tdp.sh"                   # lenovo-wmi-* via DKMS
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"
sudo xbps-pkgdb -m manual speech-dispatcher       # recommended: steamos-manager's libspeechd, so it does not hang off orca or off the build dependencies
sudo sh "$B/legion/gpu-overdrive.sh"                        # manual GPU clock
sudo sh "$B/legion/brightness-on-wake.sh"                  # brightness when coming back from suspend or hibernation
sudo bash "$B/legion/like-steamos.sh"                       # SteamOS settings (step 14, "SteamOS settings")
sudo xbps-pkgdb -m hold linux linux-headers       # the kernel does not jump off the 6.18 series
sudo reboot
```

**microSD** (step 14, "microSD"), with Steam **closed** (Steam menu → Salir / Exit): `sudo sh
"$B/legion/microsd-at-boot.sh"` and then, in Steam, add it as a library choosing `/mnt/microsd`.

The Game Mode launcher looks for `steamos-manager` every time it starts: there is no need to repeat
`install-game-mode.sh` afterwards (repeating it does no harm).

**K. By hand, in Steam and on the desktop.**

1. **Game Mode → Ajustes → Sistema → "Activar modo desarrollador"** (Settings → System → "Enable
   Developer Mode"); on the new page **"Desarrollador"** ("Developer"), **turn off "Habilitar
   administración de energía para Wi-Fi"** ("Enable Wi-Fi Power Management") (otherwise
   Steam turns the power saving that broke SSH back on).
2. **Steam → Configuración → Teclado** (Settings → Keyboard) → inglés (EE. UU.) internacional (English (US) international).
3. **xterm as a game:** `install -m 755 "$B/common/steam/xterm-steam" ~/.local/bin/`; in Steam, add
   xterm as a "juego que no es de Steam" ("non-Steam game") and in *Propiedades → Acceso directo → Destino*
   (*Properties → Shortcut → Target*) put `/home/isaac/.local/bin/xterm-steam`.
4. **Decky:** `sudo xbps-install -S hidapi` (for the Colores plugin), `sudo sh "$B/common/steam/install-decky.sh"`,
   restart Steam and, from its store, **SteamGridDB**, **CSS Loader**, **Colores** and **Panel de Control**
   (the last two, by Hooandee).
5. **xterm art:** with Steam closed (on the desktop), `python3 "$B/common/steam/art-xterm/generate.py"`;
   then open Steam.
6. **Controller on the desktop:** Steam in the background and the desktop layout. With Steam
   **closed** (`@STEAM_ACCOUNT_ID@` is the id of this Steam account; with another account, the number of its
   folder in `~/.local/share/Steam/userdata/`):

   ```bash
   D="$B/legion/steam"
   mkdir -p ~/.config/autostart && cp "$D/steam-background.desktop" ~/.config/autostart/
   rm -f ~/.config/autostart/steam-segundo-plano.desktop   # the old Spanish name, if it is there (otherwise Steam starts twice)
   K="$HOME/.local/share/Steam/steamapps/common/Steam Controller Configs/@STEAM_ACCOUNT_ID@/config/413080"
   mkdir -p "$K" && cp "$D/desktop-layout-controller_steamos_handheld.vdf" "$K/controller_steamos_handheld.vdf"
   ```

   The layout carries the trackpad click with "Pulsación doble" ("Double Press") and the gyroscope as a mouse. If
   you do not want to copy it, it is done by hand in Steam (see "Controller on the desktop").
7. **Firefox:** "Barra de título" ("Title Bar") **unchecked** (☰ → Más herramientas → Personalizar barra de
   herramientas… / More tools → Customize toolbar…), because labwc gives it only the border (step 15).
8. **Bluetooth:** pair the headphones with the block of step 5–12 (if they were paired with
   the IdeaPad, `remove` and pair again), and the **8BitDo Retro 87 Keyboard X** keyboard and the
   **8BitDo Retro R8 Mouse** (paired here: `bluetoothctl devices`; in pairing mode, from
   blueman or with `bluetoothctl pair`/`trust`/`connect` like the headphones). And the **name** with which
   the others see it, without root: `bluetoothctl system-alias Legion-Go-Gen-2` (step 5–12, "Name").
9. **VRR:** in Game Mode, with a game open, quick menu (`…`) → Rendimiento (Performance) → **"Habilitar
   VRR"** ("Enable VRR"). Without it, Steam's FPS limit gives half (step 14, "SteamOS settings"). Steam
   saves the setting; if in some game it comes out off, turn it on there too (it was not checked whether
   Steam saves it per game or for all).
10. **Firefox in Game Mode** (today it is in Steam as "Navegador web Firefox"): add it from its
   `.desktop` as a non-Steam game, `install -m 755 "$B/common/steam/firefox-steam" ~/.local/bin/` and, with
   Firefox closed, Target = `/home/isaac/.local/bin/firefox-steam` (step 14, "Firefox as a game").
   **Its art in Steam** was chosen by the user by hand (2026-10-06, files `grid/3802973322*` of
   `userdata/@STEAM_ACCOUNT_ID@/config/`): in Steam, Firefox → SteamGridDB (Decky plugin, point 4) → choose
   the art.
11. **Discord (Vesktop):** `sudo xbps-install -S gnome-software`, `flatpak remote-add --if-not-exists --user
   flathub https://dl.flathub.org/repo/flathub.flatpakrepo`, new session, Vesktop from "Software";
   add it to Steam from its `.desktop` and, with the shortcut already created, `python3
   "$B/common/steam/art-vesktop/generate.py"` (step 14, "Discord (Vesktop)"; it also
   puts the recolored icon in the menu, the panel and Alt+Tab of Xfce, and in the tray; open Vesktop once
   before, so that its data folder exists). **Rich Presence** (Discord showing what is being played;
   the user's decision): enabled inside Vesktop, in its own settings (the arRPC option; the
   exact label was not checked). It is saved as `"arRPC": true` in
   `~/.var/app/dev.vencord.Vesktop/config/vesktop/settings.json`; check with `grep -c '"arRPC": true'`
   on that file → `1`. **Portals and screen sharing:** `sudo xbps-install -S
   xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr grim fuzzel`; the wlroots portal with
   its three patches (restore windows; do not repeat the chooser when switching streams; tell the
   chooser which app is asking) (`bash "$B/legion/portal-wlr-patch/build-portal-wlr.sh"`, `sudo xbps-install -R
   ~/src/void-packages/hostdir/binpkgs xdg-desktop-portal-wlr` (with `-f` if that same revision is already there),
   `rm -rf ~/src/void-packages`); `bash
   "$B/legion/screen-share/install.sh"`, `install -D -m 644 "$B/legion/fuzzel.ini" ~/.config/fuzzel/fuzzel.ini` and **reboot** (with a new session it was not
   enough the first time; step 14, "Portals").
   **Screen sharing in Game Mode** (step 14, "Screen sharing in Game Mode"), in this order:

   ```bash
   sudo sh "$B/common/steam/portal-gamescope/install-portal-gamescope.sh"   # SteamOS's portal
   bash "$B/common/steam/gamescope-patch/build-gamescope.sh"          # without root; ~6 min
   sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs gamescope    # the revision with the patch
   sudo setcap cap_sys_nice=eip /usr/bin/gamescope && getcap /usr/bin/gamescope
   rm -rf ~/src/void-packages                                            # 1.1 GB; the .xbps, to the Release if they changed (docs/maintenance.md)
   ```

   (`install-game-mode.sh`, from block I, already brings the portal's hook: there is no need to repeat it.) If the
   Void template is still at 3.16.30_1, the `.xbps` saved in `gamescope-patch/` also works, but xbps
   needs an index next to the package: `mkdir -p /tmp/gs && cp "$B/common/steam/gamescope-patch/gamescope-3.16.30_2.x86_64.xbps" /tmp/gs/ && xbps-rindex -a
   /tmp/gs/*.xbps && sudo xbps-install -R /tmp/gs gamescope` (and the `setcap`). In Steam, **Vesktop's launch
   options** (Propiedades → Opciones de lanzamiento / Properties → Launch Options): `"run" "--branch=stable"
   "--arch=x86_64" "--command=startvesktop" "--file-forwarding" "--env=XDG_SESSION_TYPE=wayland"
   "--env=WAYLAND_DISPLAY=gamescope-0" "dev.vencord.Vesktop" "--ozone-platform=x11" "@@u" "@@"`. When
   streaming, audio source "Todo el sistema" ("Entire system") (in the stream's configuration window).
12. **Order of the audio devices** (`audio-priority`, step 6 of the IdeaPad; done here on
   2026-10-05). Today, from most to least preferred: **outputs** Bluetooth headphones METHOD 360 ANC → speakers
   (`pci-0000_c2_00.6`) → monitor HDMI (MAG 276CF) → UGREEN CM581; **inputs** UGREEN CM581
   microphone → internal microphone → headphones. With the same devices, restore the copy (in a
   terminal of the session, not over SSH; it applies from the next session):

   ```bash
   mkdir -p ~/.config/wireplumber/wireplumber.conf.d
   cp "$B/legion/wireplumber/51-audio-priority.conf" ~/.config/wireplumber/wireplumber.conf.d/
   wpctl settings -s node.restore-default-targets false     # what audio-priority does: let the priority rule
   ```

   (From `"$B"`, the copy carries the real serial number and MAC from `local.env`.)
   Or choose the order again with `audio-priority` (Salida y Entrada / Output and Input; Tab from **least to most**). If
   a device changes, its name (`node.name`, with the USB serial number or the MAC) no longer matches and
   `audio-priority` has to be repeated.

**L. Check.** The *Verification* block and a `void-update`, which must end with
"✓ Todo en orden" ("✓ All in order").

**M. Clean up** (final product, the user's decision, 2026-10-05). With everything checked, remove from `~`
what was copied in B (everything is in Common) and first save the new logs in Common. With this
repository nothing was copied to `~`: only the logs are archived (in `logs/legion/`, then commit) and
deleted:

```bash
# on the Legion: the installation logs, to the repository
mkdir -p "$REPO/logs/legion" && cp ~/*.log "$REPO/logs/legion/"   # check them for private values before committing (docs/sanitization.md)
cd ~ && rm -f -- *.log
# originally (scripts copied to ~ from Common), from the IdeaPad and then on the Legion:
#   scp 'lego:*.log' "<disk>/Backups Linux/fish/void/legion/registros-legion/"
#   cd ~ && rm -f -- *.sh *.log inputplumber-udevadm inputplumber-x86_64.tar.gz && rm -rf -- steam tdp xfce-wayland
```

What stays: `~/src/extest`, `~/.rustup` and `~/.cargo` (to rebuild `extest`) and, of the `.bak`, only
`~/.bashrc.bak`. The `.bak` of `/etc` are saved in `logs/legion/etc-bak/` and deleted (no
`--remove` uses them): see *Pending*, "Cleanup".

