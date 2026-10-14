# Void Linux on the Legion Go 2

Recipe for the **Legion Go 2** (Lenovo 83N0, Ryzen Z2 Extreme, Radeon 890M) with **Void Linux + Xfce**,
installed on **2026-10-03**, wiping SteamOS. It replaces `Handheld/new/steamos-nativo-legion-go2.md`,
which stays as a reference (just like the Fedora one with the IdeaPad).

**This recipe copies the IdeaPad one** (`void-ideapad-100.md`) and only explains what changes. Where
it says "same as the IdeaPad, step N", it means exactly that: the commands of that step as they are
(in this repository: [`docs/reference/void-ideapad-100-steps.md`](reference/void-ideapad-100-steps.md)). `<disk>`
is `/run/media/isaac/Common` (the external Kingston XS1000 SSD connected to the Legion).

> **In this repository** (not in the original). The original lived on the external disk, in
> `<disk>/Backups Linux` (folders `fish/void/…` and `herramientas/`); here every one of those paths is
> written with this repository's layout, where `<repo>` is the clone (any folder). Three things are
> done once before the blocks below (list, point B): `install/fetch-assets.sh` brings the binaries
> (`.xbps`, `.tar.gz`, fonts, `libextest.so`…; they are not in git, they are assets of the GitHub Release)
> to the paths where the scripts look for them; `local.env` (git-ignored) holds the real values that the
> files write as `@NAME@` (MACs, UUIDs, Wi-Fi name, Steam account id: see
> [`docs/sanitization.md`](sanitization.md)); and `install/render.sh` makes **`build/`**, the clone with
> those values filled in. **The blocks use `"$B"` = `<repo>/build`**: what is copied from there lands on
> the system exactly as on the original machine, and the scripts run from there.
> **Names:** scripts, commands, services and files that the original wrote in Spanish have English names
> here (`pasos-1-a-3.sh` → `steps-1-to-3.sh`, `cambiar-modo-root` → `switch-mode-root`…); the full table,
> old → new, is [`docs/glossary.md`](glossary.md). Only the English names and arguments are accepted (the
> old Spanish ones, `--quitar`, `juego`, `izq`…, were removed on 2026-10-13); the installers replace the
> old Spanish-named pieces on a system that already has them. Their messages follow the system's language ([`docs/i18n.md`](i18n.md)): in
> Spanish they are the original ones, so the quotes in Spanish below are still what one sees there. The
> logs that programs read (and that this recipe greps) are always in English. Files archived in
> `logs/` keep their original names and contents (see [`logs/README.md`](../logs/README.md)).
> Steam's, Xfce's and Firefox's menus and buttons are quoted as they appear in Spanish, with the English
> label in parentheses.

Work rules, the same as on the IdeaPad: whatever needs root is run by the user on the machine itself
(originally the scripts were copied to `~` and launched with `sudo bash ~/script.sh`; **with this
repository they are launched from the clone**, `sudo bash "$B/legion/<script>.sh"`, because each script
finds `lib/` next to it); each script leaves its log in `~/<script>.log`; **when finished, the logs leave
`~`** (point M: archived in `logs/`); before editing a file of the documentation (originally, in
`Common`), a single `.bak` copy.

**Order of the document (2026-10-05): that of a reinstall**, not the chronological one. First the full
list (*Reinstall*), then each step with its reason in the order it is applied, and at the end
*Troubleshooting*, *Verification*, *Pending* and *History*. **Step numbers do not change**
(they are those of the IdeaPad recipe, and the scripts and the Claude contexts cite them): that is why
7 comes after 13 and 15 is installed inside 14.

## Starting point

| | |
|---|---|
| Device | Legion Go 2, `83N0` (fastfetch: "Legion Go 8ASP2"); BIOS `RRCN16WW` |
| CPU / GPU | AMD Ryzen Z2 Extreme (6+10 cores, 16 threads) / Radeon 890M (`gfx1150`) |
| RAM | 32 GB physical: 21 GB for the system, **10 GB reserved for the GPU** |
| Internal disk | SK Hynix `HFS001TEM4X182N`, 1 TB NVMe (`nvme0n1`) |
| Screen | Samsung `SDC 4301`, **1920×1200 at 144 Hz, 8.8", landscape from the factory** (comes out upright on its own) |
| Wi-Fi / Bluetooth | MediaTek MT7922 (`mt7921e`) / `hci0` of the same chip |
| Sound | Realtek ALC257 + ACP coprocessor (`snd_acp_pci`, SOF) |
| microSD | `mmcblk0p1`, 953 GB **ext4**, from the SteamOS days: its **Steam library** and emulator games; always mounted at **`/mnt/microsd`** (step 14, "microSD") |
| Keyboard | **US international** (`us` + `intl`, with dead keys), not `latam` like the IdeaPad |

It is used with an **external 27" monitor** (MSI, 1920×1080) to the left of the Legion's screen
(x = 1920): the desktop (panels) is on the monitor. Output names: on X11 `DisplayPort-0` and
`eDP`; on Wayland (labwc, the normal session) and in gamescope, `DP-1` and `eDP-1`. Scale **1×
(96 DPI)**, the user's decision (2026-10-03): on X11 the DPI is a single one for both screens.

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
> scripted ones in this order (see [`install/README.md`](../install/README.md)); what is done by hand
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

## 0. Before installing: live test and rescue of SteamOS (2026-10-03)

**Live test.** With the Void ISO (`void-live-x86_64-20250202-xfce.iso`, kernel 6.12.11,
booted from a USB with **Ventoy**) it was checked, without installing anything, that Void's normal kernel
recognizes the Legion: screen, Wi-Fi (5 GHz, Wi-Fi 6, 1200 Mbps), controllers as in SteamOS
("Legion Controller" keyboard/mouse/touchpad + "Generic X-Box pad" with `xpad`), gyroscope and
accelerometer (`amd_sfh`, they respond when moving it), speakers, battery, Bluetooth and
`platform_profile` (`low-power`/`balanced`/`performance`). Missing: InputPlumber, `lenovo_wmi_*`
(fine TDP) and maybe `hid_lenovo_go` (**solved on 2026-10-04**, step 14: InputPlumber and the
`lenovo-wmi-*` installed; `hid_lenovo_go` is not needed for the buttons). Full results in *Pendientes* (*Pending*) of the
IdeaPad recipe. SSH access to the live: there `sudo sv up sshd` (user `anon`, password
`voidlinux`) and `ip a` for the IP.

> **In this repository:** the IdeaPad recipe's *Pending* section is not included (only the steps the Legion
> recipe uses, see [`docs/reference/`](reference/)). `voidlinux` is the public default password of the Void
> live ISO, not a personal one.

**Rescue of SteamOS's `/home`.** Before wiping, the `/home` (`nvme0n1p8`, ext4) was mounted
**read-only and without touching the journal** and compared file by file with `Common`:

```bash
sudo mkdir -p /mnt/steamos-home && sudo mount -o ro,noload /dev/nvme0n1p8 /mnt/steamos-home
```

What was missing is in `Handheld/new/rescate-steamos-2026-10-03/` (with its `LEEME.md`): Claude
Code's memory of the Legion, the video fix of the Strix GPU, final `xterm-steam-fix`, Decky
settings, etc. The fish functions were already identical in `Common`. The reduced animated wallpapers
(1.2 GB) were uploaded by the user to their Google Drive.

> **In this repository:** `Handheld/new/` (the SteamOS-era recipe and the rescue) is not included: it
> describes the previous system (SteamOS), and stays on the disk as a reference.

**The live's mount folders pass to the installed system:** with *Source: Local* (step 1) the
installer copies the live's `/`, and with it `/mnt/steamos-home` and `/mnt/home` (empty, owned by root). In the
installation of 2026-10-03 they stayed like that. When the installation ends, check that they are empty and not
mounted (`ls -A /mnt/home /mnt/steamos-home` lists nothing; `findmnt /mnt/home /mnt/steamos-home`
says nothing) and delete them: `sudo rmdir /mnt/home /mnt/steamos-home` (`rmdir` only deletes empty folders).

## 1. Installation with `void-installer`

From the live (the same ISO), **with the internal disk not mounted** (see the trap below):
`sudo void-installer`.

| Setting | Value |
|---|---|
| Keyboard | another one was chosen; step 2 sets it properly (`us-acentos`). In a reinstall: `us-acentos` |
| Source | **Local** (copies the live: Xfce + lightdm) |
| Hostname | **`Legion-Go-Gen-2`** (the same one SteamOS had: `ssh lego` keeps working) |
| Locale / Timezone | `es_MX.UTF-8` / `America/Mexico_City` |
| User | `isaac` (in `wheel`; the installer adds `audio video kvm floppy cdrom optical users xbuilder`) |
| Bootloader | **`/dev/nvme0n1`** |
| Partition (`cfdisk`, `gpt`) | delete **all** of SteamOS's (`p1`…`p8`) and create: `p1` 500M *EFI System* · `p2` **32G** *Linux swap* · `p3` the rest (921.4G) *Linux filesystem* |
| Filesystems | `p1` vfat → `/boot/efi` · `p2` swap · `p3` **btrfs** → `/` (no subvolumes; `/home` is a folder) |

- **32 GB swap** (= physical RAM, 2026-10-03): leaves hibernation ready (the only suspend
  is `s2idle`, which drains battery). **Hibernation works** (verified on 2026-10-04: dracut puts `resume=` in the initramfs; see "Hibernation and brightness on wake", step 14).
  The "1.5 × RAM" rule is from when there were 1–4 GB.
- **Trap 1: `p8` mounted.** If SteamOS's `/home` is still mounted (here it was twice:
  `/mnt/steamos-home` from the rescue and `/mnt/home`), `cfdisk` cannot delete `p8` and the kernel does not
  load the new table: only about 10 GB remained free and the swap and btrfs did not fit. Before
  partitioning: close whatever has files open there (it was **Firefox**, uploading the videos) and

  ```bash
  sudo umount -A /dev/nvme0n1p8 && sudo partx -u /dev/nvme0n1; lsblk /dev/nvme0n1
  ```

- **Trap 2: `void-installer` remembers what was assigned.** It saves the configuration in
  `/tmp/.void-installer.conf` (readable by everyone, **with the passwords in plain text**; it is
  deleted when the live powers off). An old assignment to `p8` was still there although `p8` no longer existed, and
  the *Filesystems* list showed it. Remove it before *Install*:

  ```bash
  sudo sed -i "/^MOUNTPOINT \/dev\/nvme0n1p8 /d" /tmp/.void-installer.conf
  grep ^MOUNTPOINT /tmp/.void-installer.conf     # only p1, p2 and p3
  ```

The installer leaves active `NetworkManager`, `lightdm`, `dbus`, `polkitd`, `chronyd`, `udevd`, the
`agetty` and `sshd`. It writes its own entry in the firmware (that is already done; from here on,
**do not write to the firmware**, same as on the IdeaPad).

**First login over SSH** (still without mDNS, by the IP of the USB cable or of the Wi-Fi): from the Legion,
with `isaac`'s password on the IdeaPad, so that the IdeaPad can get in:

```bash
mkdir -p ~/.ssh && ssh isaac@<IdeaPad IP> cat .ssh/id_ed25519.pub >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

## 2–3. System up to date, keyboard and SSH (one script)

```bash
sudo bash "$B/legion/steps-1-to-3.sh"       # log: ~/steps-1-to-3.log
sudo reboot                       # when it ends with "DONE OK"
```

It does what steps 1–3 of the IdeaPad do, with these differences:

1. **xbps first and then everything** (`xbps-install -Syu xbps`; `xbps-install -Syu -y`). The mirror
   was already summithq (the installer sets it if it is chosen). 2026-10-03: from 6.12.11 to **6.18.55**.
   If it brings a new OpenSSH, **SSH connections are cut** ("Connection reset by peer") until
   the reboot: that is expected.
2. **US international keyboard**: `/etc/X11/xorg.conf.d/00-keyboard.conf` with `XkbLayout "us"` and
   `XkbVariant "intl"` (backed up in `legion/00-keyboard.conf`), and `KEYMAP=us-acentos` in
   `/etc/rc.conf` (leaves `rc.conf.bak`; the installer had set `KEYMAP=en`, which does not exist).
   With `intl`, `'` + `a` = á and **AltGr+n = ñ**.
3. `openssh avahi nss-mdns` and the services `dbus`, `sshd`, `avahi-daemon`. **`xbps-install`
   prints `ERROR: Package 'openssh' already installed.` and continues**: it is not a failure, it installs the
   rest. **Do not query `sv status` right after creating the link:** runit takes up to 5 s to
   see the service and answers `unable to open supervise/ok`; with `set -e` that cut the script
   (it happened the first time; the backed-up script no longer does it).

After the reboot, check: `uname -r` (6.18.x), `pgrep -a avahi-daemon` (`running
[Legion-Go-Gen-2.local]`), `setxkbmap -query` in the session (`us` / `intl`) and from the IdeaPad
`ssh lego hostname`. 4 `.new-*` remain in `/etc` (`libc-locales`, `issue`, `passwd`, `rc.conf`),
the same as on the IdeaPad: **they are not applied** (`passwd.new-*` has no users). Step 5
deletes them.

**Network name with the dock (2026-10-04): avahi only over Wi-Fi.** With the dock, the Legion
has two networks at once (Wi-Fi `wlp193s0`, 192.168.0.x, and the dock's `enp196s0f3u1u1`,
192.168.1.x); avahi heard its own announcement over the other one, thought the name was taken and **renamed itself to
`Legion-Go-Gen-3.local`** (adds 1 to the final number of the name): `ssh lego` stopped
resolving. `sudo sh "$B/legion/avahi-wifi-only.sh"` (in `legion/`; `--remove` undoes it) puts
`allow-interfaces=wlp193s0` in the `[server]` section of `/etc/avahi/avahi-daemon.conf` (leaves `.bak`)
and restarts avahi. The Wi-Fi is always there, with dock or without it (and the IdeaPad is on that network); the name
of the dock's interface depends on the adapter. **Trade-off:** with only cable and the Wi-Fi off
there is no `.local` name. Check: `pgrep -a avahi-daemon` → `running [Legion-Go-Gen-2.local]`;
from the IdeaPad, `getent hosts Legion-Go-Gen-2.local`. **Verified on 2026-10-04.**

**Wi-Fi without power saving (2026-10-04).** From the factory the MT7922 runs with `Power save: on`
(`iw dev wlp193s0 get power_save`): the radio went to sleep and **did not answer ARP or mDNS until the
Legion itself transmitted**, so SSH did not get in in either direction and `Legion-Go-Gen-2.local` did not
resolve (from the IdeaPad, the Legion's IP showed `INCOMPLETE` in `ip neigh` and port 22 did not
answer; a `ping` from the Legion fixed it instantly). `sudo sh "$B/legion/wifi-no-powersave.sh"` (in
`legion/`; `--remove` undoes it) writes `/etc/NetworkManager/conf.d/wifi-no-powersave.conf`
(`[connection]` `wifi.powersave = 2`, for all Wi-Fi connections) and turns it off right away with `iw … set
power_save off`, without reconnecting. Check: `iw dev wlp193s0 get power_save` → `Power save: off`
(also after rebooting); from the IdeaPad, `ping` to the Legion of a few ms. **Verified on
2026-10-04:** 25 pings of 2–14 ms (average 5.8; with power saving, 55–100 ms).
**The engine is still wpa_supplicant** (NetworkManager's factory one), not iwd as on the
IdeaPad: the switch to iwd there fixed wpa_supplicant's continuous scans with the
RTL8723BE, and here it does not happen (0 scans in 30 s with `iw event`, 5 GHz and strong signal). Switch to
iwd only if those symptoms appear.

**Network interfaces that udev skips at boot: `udev-net` (2026-10-04).** After a reboot the
Wi-Fi came out as **`wlan0`** (not renamed to `wlp193s0`) and NetworkManager had it **"unmanaged"**
(`nmcli -f GENERAL.REASON d show wlan0` → *The device is unmanaged because the link is
not initialized by udev*); with no network on the IdeaPad, `Legion-Go-Gen-2.local` did not resolve. **Cause (Void's,
not the Legion's):** udev starts in stage 1 (`/etc/runit/core-services/02-udev.sh`) and the
stage-2 `udevd` service (`/etc/sv/udevd/run`: `udevadm control --exit` and `exec udevd`)
replaces it; **whatever the kernel announces in that gap is lost**. In `dmesg`, three `udevd …
starting` (0.6 s initramfs, 3.8 s stage 1, **5.4 s** stage 2) and the MT7922 creating its interface on
finishing loading the firmware (~4.3 s): it fell in the gap (no `n<ifindex>` entry in
`/run/udev/data`). It had been fine for days: it is a race, and the boot changed pace that day
(`lenovo-wmi-*` modules, overdrive). **Fix on the spot:** `sudo udevadm trigger --action=add
--subsystem-match=net` (`wlp193s0` comes back and connects). **Permanent fix:** `sudo sh "$B/legion/udev-net.sh"` (in
`legion/`; `--remove`): runit service **`udev-net`** which, with `udevd` already running
(`sv check udevd` + `udevadm settle -t 30`), repeats to udev the announcement of every interface with no entry in
`/run/udev/data` and stays in `pause`. The `run` of `udevd` belongs to the package: it is not touched. Log in
`/var/log/udev-net/current`, **only if it had to act**. **Installed on 2026-10-04 and it already
acted** in a real boot that same day (see *Pending*, "Watch"). The IdeaPad has the same
gap: also installed there on 2026-10-04 (its step 4).

## 4. SSH access in both directions

**On the IdeaPad** (`~/.ssh/config`): `Host lego` → `HostName Legion-Go-Gen-2.local`, **`User
isaac`** (formerly `deck`). On reinstall, the host key changes:
`ssh-keygen -R Legion-Go-Gen-2.local`.

**On the Legion** (without root):

```bash
ssh-keygen -q -t ed25519 -N "" -C "isaac@Legion-Go-Gen-2" -f ~/.ssh/id_ed25519
cp "$B/legion/ssh-config" ~/.ssh/config && chmod 600 ~/.ssh/config   # Host ideapad, msi and deck
cat ~/.ssh/id_ed25519.pub        # add this line to the IdeaPad's ~/.ssh/authorized_keys
```

On the IdeaPad the old key `deck@Legion-Go-Gen-2` was **replaced** (its private part went away with
SteamOS) by the new `isaac@Legion-Go-Gen-2` (2026-10-03; `authorized_keys.bak` next to it).
Check from the Legion: `ssh ideapad hostname` → `ideapad-100`.

## 5–12. X11 desktop

### Root part 1: packages, Papirus teal and Bluetooth

```bash
sudo bash "$B/legion/desktop-1-root.sh"     # log: ~/desktop-1-root.log
```

Deletes the `.new-*` of `/etc`; installs what steps 5, 6, 7 and 9 of the IdeaPad install in a single command
(`fish-shell fzf ntfs-3g curl git ripgrep xdg-utils` + the whole list of step 9: 63 packages on
2026-10-03; plus `xrandr`, for step 13); `papirus-folders -C teal --theme Papirus-Dark`; and enables `bluetoothd`.

**Bluetooth: the Legion does not come with it blocked** (`rfkill`: `ideapad_bluetooth` and `hci0`
unblocked): the IdeaPad's `bluetooth-at-boot.sh` is **not needed**. If one day it comes back
blocked after a reboot, set it up the same as there.

**Name: `Legion-Go-Gen-2`, its hostname** (2026-10-08, approved by the user; same as the IdeaPad,
step 9 of its recipe). From the factory it announced itself as "BlueZ 5.86" (bluez takes it from `systemd-hostnamed`,
which Void does not have). The adapter's **alias** is changed, without root (on 2026-10-08 it also worked over SSH):

```bash
bluetoothctl system-alias Legion-Go-Gen-2      # "Changing Legion-Go-Gen-2 succeeded"
bluetoothctl show | grep Alias                 # Alias: Legion-Go-Gen-2 (Name stays at "BlueZ 5.86")
```

bluez saves it in `/var/lib/bluetooth/` (on the IdeaPad it survives the reboot; here, not checked after
rebooting on 2026-10-08). Alternative with root: `Name = Legion-Go-Gen-2` in `/etc/bluetooth/main.conf`.

**Bluetooth headphones (Skullcandy Method 360 ANC, `@HEADPHONES_BT_MAC@`), 2026-10-03.** With
`libspa-bluetooth` and PipeWire registered in bluez (`bluetoothctl show` lists `Audio Sink`/`Audio
Source`), they connect with the `a2dp-sink` profile. **Trap: they only keep the last pairing properly.**
Paired with the Legion and then with the IdeaPad, on the Legion they "connected" and dropped instantly with
`Failed to connect: org.bluez.Error.Failed br-connection-create-socket`, with no audio output. Also,
if they are connected to the other machine, first they have to be released there (`bluetoothctl disconnect
@HEADPHONES_BT_MAC@`). Fix, with the headphones in pairing mode (light blinking), without root:

```bash
M=@HEADPHONES_BT_MAC@
bluetoothctl remove $M
{ echo "scan on"; sleep 12; echo "scan off"; } | bluetoothctl >/dev/null
bluetoothctl pair $M && bluetoothctl trust $M && bluetoothctl connect $M
pactl set-default-sink "$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')"   # if the sound stays on another output
```

Check: `bluetoothctl info $M` → `Paired/Bonded/Trusted/Connected: yes`; `pactl list cards`
→ `Active Profile: a2dp-sink`. To use them again on the IdeaPad, the same there.

### User part (without root)

```bash
V="$B/common"      # originally: C="<disk>/Backups Linux"; V="$C/fish/void"
# 5. fish from bash (the login shell stays /bin/bash: getent passwd isaac)
mkdir -p ~/.bashrc.d && cp "$V/shell/99-exec-fish.sh" ~/.bashrc.d/
cp ~/.bashrc ~/.bashrc.bak && cat "$V/shell/bashrc-block.sh" >> ~/.bashrc
# 6. functions (and the translations of their messages: docs/i18n.md)
mkdir -p ~/.config/fish/functions ~/.local/bin
bash "$B/install/install-i18n.sh"   # ~/.local/share/void-legion (without it, the messages come out in English)
cp "$V/fish/functions/"{__vl_t,fish_prompt,fish_greeting,disk-ops}.fish ~/.config/fish/functions/
cp "$V/fish/functions/"{install-pkg,remove-pkg,audio-ctrl,audio-priority}.fish ~/.config/fish/functions/   # audio-*: see step 6 of the IdeaPad
cp "$V/ssh-setup/ssh-setup.fish" ~/.config/fish/functions/
cp "$V/ssh-setup/ssh-survey.sh" ~/.config/fish/ && chmod +x ~/.config/fish/ssh-survey.sh
fish -c 'fish_add_path -U ~/.local/bin'
bash "$V/void-update/install-void-update.sh" --no-tray   # void-update + its patch test (without root; see "void-update" below)
# 9. fonts, Orchis, Volantes
mkdir -p ~/.local/share/fonts ~/.themes ~/.local/share/icons
cp "$V/fonts/"*.ttf ~/.local/share/fonts/
cp -r "$V/xterm/jetbrains-blocks" ~/.local/share/fonts/ && chmod +x ~/.local/share/fonts/jetbrains-blocks/regenerate.sh
fc-cache -f ~/.local/share/fonts
tar xzf "$V/xfce/orchis-themes.tar.gz" -C ~/.themes/
tar xzf "$V/xfce/volantes-cursors.tar.gz" -C ~/.local/share/icons/
# 11. xterm and default terminal
X="$V/xterm"; mkdir -p ~/.config/xfce4
cp "$X/Xresources" ~/.Xresources && cp "$X/xterm-papirus.xpm" ~/.local/share/icons/
cp "$X/helpers.rc" ~/.config/xfce4/helpers.rc && cp "$X/xprofile" ~/.xprofile
cp "$X/xdg-terminal-exec" ~/.local/bin/ && chmod +x ~/.local/bin/xdg-terminal-exec
# 12. fastfetch
mkdir -p ~/.config/fastfetch && cp "$V/fastfetch/gen-config.py" ~/.config/fastfetch/ && python3 ~/.config/fastfetch/gen-config.py
```

- **`~/.local/bin` has to exist before `fish_add_path`:** otherwise it returns an error (with
  `set -e` it cut the first time, without a message).
- Check: `fish -c 'functions -q install-pkg disk-ops ssh-setup; and echo OK'` and `void-update --version`;
  `fc-list | grep -ci jetbrains` → 100 (104 after root part 2, which copies the 4 Blocks to
  `/usr/local/share/fonts/`); `fc-match "JetBrainsMono NFM Blocks:charset=23fa" family`
  → `Adwaita Mono`; `ls ~/.themes` → the 6 variants of Orchis.
- **Step 7 (Claude Code):** goes separately, further down.

### void-update: updates, panel icon and automatic checks (2026-10-11)

It replaces the fish function `update-system` (the user's decision, 2026-10-11: the old name is removed),
modeled on CachyOS's **cachy-update** (a fork of *arch-update*), in `common/void-update/`, on both machines.
Installed without root by the block above (`install-void-update.sh`, which also installs the patch test and the
translations, removes `~/.config/fish/functions/update-system.fish` and moves the date of the last update to
`~/.local/state/void-update/last-update`, the one fastfetch shows). After step 13, the panel icon:

```bash
void-update --tray --enable      # starts it now and at every login (~/.config/autostart/void-update-tray.desktop)
```

| | |
|---|---|
| `void-update` | full update: syncs; shows **Void's news** published since the last update (https://voidlinux.org/atom.xml; on 2026-03-10 one asked for a manual step with `linux-firmware`); the **list colored like cachy-update** (the changed part of each version in red → green) with the download size; the warning about packages built here that the update would replace (patch test); **one** confirmation; xbps first, then everything; sshd if OpenSSH changed; Flatpak; orphans except kernels; cache; loose kernels; `.new-*`; LazyVim; **runit services still running old code** (a process with a replaced library or executable, `(deleted)` in `/proc/<pid>/maps`, followed up to its `runsv`): it offers to restart them (`sv restart`; never `lightdm`, `dbus` or the consoles); the **summary** OK / REPAIRED / WARNING (the same checks as before); and if there is a new kernel or glibc, it **asks** whether to reboot (`[y/N]`: it never reboots by itself). A lock prevents two at a time |
| `void-update --check` | looks for updates **without root**: `xbps-install -Mun` fetches the repositories' index into memory (~5–10 s), and `flatpak remote-ls --updates`. Updates the icon and, if the list changed, sends a notification with a "Run void-update" button |
| `void-update --list` · `--news [N]` · `--services` · `--summary` | the pending list (exit 7 if none) · Void's latest news · services with old code · only the summary, without sudo |
| `void-update --tray [--enable\|--disable]` | the icon (Ayatana AppIndicator, already installed: nm-applet needs it) |
| `void-update --gen-config` · `--show-config` · `--edit-config` | `~/.config/void-update/void-update.conf` (interval, notifications, Flatpak, news…; example in `common/void-update/void-update.conf.example`) |

**The icon**, like cachy-update's: **Void's symbol in one color** (white, for the black panel; black with
`tray_icon_style=dark`) with a status badge in its corner: ✓ up to date, ↓ updates available, ··· checking,
! the check failed (2026-10-13, the user's request: the distribution's symbol in black and white, consistent with
the panel; the first version used Papirus' update icons). SVGs in `common/void-update/icons/`, made by its
`generate.py` from `/usr/share/void-artwork/void-logo.svg` (the arcs and the dot, as vectors); the "updates
available" one is also the launcher's and the notification's (`~/.local/share/icons/hicolor/scalable/apps/void-update.svg`). Its menu: "N
updates available" (runs it), submenus *Packages (N)*, *Flatpak (N)* and *All (N)* with the list, last and
next check, **Run void-update**, **Check for updates**, **Exit**; the middle click runs it too (in Ayatana the
left click opens the menu). "Run" opens `void-update.desktop` in a terminal (xterm, as the rest of the
system), which waits for Enter at the end. **Automatic checks:** when the network connects (NetworkManager's
`StateChanged` over D-Bus) if the last one is older than the interval, and every `check_interval_hours`
(6 by default, like cachy-update's timer; 0 = only on connect). The icon reacts to void-update's state file
event-driven (file monitor), never polling it. It does not start in Game Mode (no session autostart there).
**Verified on the IdeaPad on 2026-10-11:** `--check` found 3 updates in 10 s without root; `--summary`
identical to `update-system --resumen` (same lines, in Spanish); the icon shows in the top panel's tray.

### Root part 2: login screen same as the session (step 10)

```bash
sudo bash "$B/legion/desktop-2-root.sh"     # log: ~/desktop-2-root.log
```

The same as step 10 of the IdeaPad (system copies of Orchis, Volantes and the font;
`lightdm-gtk-greeter.conf`; black bar), with one correction: **the greeter's `gtk.css` is copied
with `install -o lightdm -g lightdm -m 644`** and not with `sudo -u lightdm cp`, because `Common`, mounted
by udisks for `isaac`, cannot be read by the user `lightdm` ("Permiso denegado" / "Permission denied"; the same would happen
to the IdeaPad). The script does not overwrite `lightdm-gtk-greeter.conf.bak` if it already exists (on repeating it,
it would save the new configuration on top of the original).

## 13. Xfce configuration and per-monitor windows

**With the session closed** (Log out and stay at the login screen; from SSH works, there is no
need for Ctrl+Alt+F2). Before logging out, if `Common` could be unmounted on exit,
copy what is needed to `~/.cache`. Then:

```bash
pkill -u isaac -x xfconfd
L="$B/legion"; X="$B/common/xfce"     # originally: L="<disk>/Backups Linux/fish/void/legion"; X="…/fish/void/xfce"
mkdir -p ~/.config/xfce4/xfconf ~/.config/gtk-3.0 ~/.local/bin ~/.config/autostart
cp -r "$L/xfce/xfce-perchannel-xml" ~/.config/xfce4/xfconf/
cp -r "$L/xfce/panel" ~/.config/xfce4/
cp "$L/xfce/gtk.css" ~/.config/gtk-3.0/gtk.css
cp "$X/"{window-snap,window-focus,new-windows} ~/.local/bin/ && chmod +x ~/.local/bin/{window-snap,window-focus,new-windows}
cp "$X/new-windows.desktop" ~/.config/autostart/
rm -f ~/.local/bin/{ventana-acoplar,ventana-foco,ventanas-nuevas} ~/.config/autostart/ventanas-nuevas.desktop   # the old Spanish names, if they are there (otherwise two watchers run)
```

> **In this repository:** `legion/xfce/xfce-perchannel-xml/xfce4-panel.xml` contains the Wi-Fi name
> (`@WIFI_SSID@`, in remembered tray tooltips) and the keyboard shortcuts carry `@TARGET_HOME@`: that is
> why the block copies from `"$B"` (rendered).

`legion/xfce/` is the IdeaPad configuration (step 13 of its recipe: themes, panels, Docklike,
Omarchy shortcuts, focus, `gtk.css`) **with the Legion's own things**:

- **The Legion's `displays.xml`**, not the IdeaPad's (which describes its 1366×768 screen). The
  first time the IdeaPad's was restored and the one the Legion's session had created was put back.
  **Since 2026-10-05 the backed-up one is the Wayland session's:** labwc calls the outputs
  `DP-1` (monitor, `0,0`, 1920×1080 at 60 Hz) and `eDP-1` (Legion, `1920,0`, 1920×1200 at 144 Hz); X11,
  `DisplayPort-0` and `eDP`. When Wayland was used, `xfsettingsd` rewrote the `Default` profile and the
  X11 entries disappeared. In the backup X11 session, arrange the screens once in
  *Configuración → Pantalla* (*Settings → Display*) (monitor on the left).
- **Copy of `legion/xfce/` brought up to date on 2026-10-05** (it was the one from 2026-10-03), copied from the
  running Legion: besides `displays.xml`, Num Lock active on login (`keyboards.xml`), the
  Clipman notifications (`xfce4-notifyd.xml`), the known tray icons (`nm-applet`,
  `blueman`, `steam`, in `xfce4-panel.xml`) and window sizes of Thunar and of the settings
  manager. `panel/` and `gtk.css` had not changed. The previous copy stays in
  `legion/xfce/xfce-perchannel-xml.bak/`. **Again on 2026-10-07** (full review): only
  `xfce4-panel.xml` (the tray already knows Vesktop's icon, `vesktop_status_icon_1`) and `xfwm4.xml`
  (with `raise_on_focus` = false, already backed up); the rest was identical to the Legion (except the state of
  Thunar's windows and `ristretto.xml`, which are not saved).
- **Super+Shift+1…0 shortcuts with the US international symbols.** xfwm4 registers them with the
  symbol that Shift+number gives (in `latam` they were `exclam`, `quotedbl`…). Read from the
  active layout (`xkbcomp -xkb $DISPLAY -`, keys `<AE01>`…`<AE10>`), not from memory: `exclam`, `at`,
  `numbersign`, `dollar`, `percent`, **`dead_circumflex`** (with `intl`, Shift+6 is a dead key, not
  `asciicircum`), `ampersand`, `asterisk`, `parenleft`, `parenright`. Each one:
  `xdotool getactivewindow set_desktop_for_window N set_desktop N` (N = 0…9). Done with
  `xfconf-query` (live): first `-r` of the ten old ones and then `-n -t string -s` of the
  new ones (Shift+7 was `ampersand` in `latam` and now it is Shift+7 → all are deleted before creating).
- **Super+Shift+Space** → `window-snap home` (new, see below).

> **In this repository:** `legion/xfce/xfce-perchannel-xml.bak/` (the previous copy) is not included: git
> history replaces the `.bak` copies.

### Per-monitor and almost-maximized windows (2026-10-03)

With the external monitor, the IdeaPad shortcuts split the window between the two screens:
**`_NET_WORKAREA` is a single rectangle for the whole desktop** (here 3840×1200). The scripts
(common to both machines, in `common/xfce/`; with a single screen they behave the same):

- **`window-snap left|right|up|down|full|home`**: works on the **window's monitor**. Its
  rectangle comes from `xrandr --listactivemonitors` and only the panels (`DOCK` windows
  with `_NET_WM_STRUT_PARTIAL`) that fall on it are subtracted: external monitor → `0,26 1920×1054`
  (top panel); the Legion's screen → `1920,0 1920×1200` (no panel). Without `xrandr`, the
  whole desktop, as before. **Almost maximized ("llena" / "full" region) is the intermediate step between the two halves**, inside
  the monitor (2026-10-03): left half + → = full; full + → = right half (same with
  ↑/↓). **Towards the edge it does nothing** (← on the left half, or outwards from a quarter),
  and **quarters never go to full** with arrows: inwards they grow to the half. (Before it was
  repeating the arrow outwards, "as if leaving the monitor": not intuitive.) Same in labwc (step 15 of the IdeaPad).
  Checked with an xterm (←, ←, →, →, →, ↑, →, ←, ↓, ←, ↓ → full, left half, nothing, full, right
  half, nothing, top-right quarter, nothing, top half, full, left half, bottom-left quarter).
  Super+Shift+Space (`inicio`) → "full", or to the center if it is a dialog, fixed-size or the finder.
  - **Windows with a big minimum size** (e.g. *Preferencias del panel* / *Panel Preferences*, 562×625): they do not reach the
    requested size and the state, deduced by measuring, came out wrong (erratic behavior). Now
    their minimum is used, stuck to the edge it touches (right/bottom), and **where each
    window was sent is recorded** (`$XDG_RUNTIME_DIR/window-snap/<id>`: destination and geometry without frame, as
    `getwindowgeometry` gives it); if it is still there (±20 px), what was recorded is valid. Checked with *Panel
    Preferences*: →, ↓, ←, ↑, ↑, →, → give full, bottom half, corner, left half, corner,
    top half, corner, without leaving the monitor.
- **`window-focus`**: Super+arrows only jumps between windows **of the same monitor**.
- **`new-windows`** (autostart `new-windows.desktop`): every **new** window opens almost
  maximized on its monitor, like the labwc rule. **Event-driven:** `xprop -spy -root
  _NET_CLIENT_LIST` (no periodic queries). It does not touch those that were already there at start, the non-
  normal ones (without type, like xterm, counts as normal), dialogs and windows with a parent, the
  fixed-size ones, `xfce4-appfinder` nor those that open fullscreen (games). A single copy
  per session (`flock`). **In a Wayland session it exits without doing anything** (`WAYLAND_DISPLAY`): labwc's
  also declares itself XFCE and would start the autostart, but there its rules do it. Checked: a new xterm opened at `8,34 → 1912,1072` (8 px gap and
  below the panel); the finder, centered and untouched.
- **Needs `xrandr`**, which Void does not install with Xfce. On 2026-10-03 it was installed by hand
  (`sudo xbps-install -Sy xrandr`); the backed-up `desktop-1-root.sh` already includes it.
- **X11 limit with no fix:** xfwm4's workspaces are **shared by the
  two monitors** (Super+1…5 switches both screens at once).
- **Bottom panel:** always hidden (`autohide-behavior` = 2). While *Panel Preferences* is open,
  Xfce leaves it visible to show which one is being edited.

After changing something of Xfce on the Legion, copy again `xfce-perchannel-xml/`, `panel/` and
`gtk.css` to `legion/xfce/` (not to `common/xfce/`, which is the IdeaPad's).

**Copying from Claude Code over SSH** (2026-10-03): `.Xresources` (common, `common/xterm/`)
allows OSC 52 only for putting text in the clipboard (`disallowedWindowOps` without `SetSelection`);
detail in the IdeaPad recipe, step 11. Shift + drag selects on top of Claude Code.

## 7. Claude Code (2026-10-03)

`curl`, `git`, `ripgrep` and `xdg-utils` already come from step 5–12. Without root (the installer refuses
with sudo):

```bash
curl -fsSL https://claude.ai/install.sh | bash          # ~/.local/bin/claude (2.1.289 on 2026-10-03)
mkdir -p ~/Work ~/.claude/projects/-home-isaac-Work/memory
cp "$B/claude/CLAUDE-void-legion.md" ~/Work/CLAUDE.md
cp "$B/claude/memory/"*.md ~/.claude/projects/-home-isaac-Work/memory/
cd ~/Work && claude                                      # log in (on the Legion itself)
```

> **In this repository:** `CLAUDE-void-legion.md` → [`claude/CLAUDE-void-legion.md`](../claude/CLAUDE-void-legion.md),
> `claude-memoria-legion/` → [`claude/memory/`](../claude/memory/), `claude-agentes/mantenedor-void.md` →
> [`claude/agents/void-maintainer.md`](../claude/agents/void-maintainer.md) (the agent is called
> `void-maintainer` here). They are translated into English and are installed as they are: the context and
> the agent describe the same things, and the memory still asks Claude to answer in Spanish. The Spanish
> originals stay on the external disk. The context and the agent name this repository's paths; on the
> machine, `<repo>` is the clone of point B.

The installer's warning that `~/.local/bin` is not in the `PATH` is bash's: in fish it already is
(`fish_add_path`, step 6). **The context is its own** (`CLAUDE-void-legion.md`: describes the Legion
as "this machine"; the IdeaPad's would confuse the session) and the memory carries only the two
general notes (answer in Spanish, explicit recipe), in `claude/memory/`. If Claude
saves something new here, copy that folder to the disk again (with this repository: to `claude/memory/`,
in English, and commit). Check: `claude --version` and
`ls ~/.claude/.credentials.json` (after logging in).

**`mantenedor-void` agent** (`void-maintainer` in this repository): same as on the IdeaPad (its step 7): `mkdir -p ~/Work/.claude/agents && cp
"$B/claude/agents/void-maintainer.md" ~/Work/.claude/agents/`. Its first audit
(2026-10-07) found here the `rtkit` loop (see *Watch*).

## 8. GRUB: Windows on the XS1000, silent boot, theme and hidden GRUB (2026-10-03 and 04)

It goes **after step 10** (the theme uses the copy of the font that step makes). With the XS1000
connected and `Common` mounted:

```bash
sudo bash "$B/legion/grub-root.sh"       # log: ~/grub-root.log
udisksctl unmount -b /dev/sda4 # before rebooting
sudo reboot
```

It does, in order:

1. **Checks Windows's loader** by mounting the XS1000's EFI (`sda1`, `SYSTEM`, UUID
   `@XS1000_EFI_UUID@`) **read-only**: `\EFI\Microsoft\Boot\bootmgfw.efi` (3 087 200 bytes on
   2026-10-03). If it is not there, it does not add the entry.
2. **Windows entry** in `/boot/grub/custom.cfg` (loaded by `41_custom`: survives
   `grub-mkconfig`; leaves `custom.cfg.bak` if there already was one):

   ```
   menuentry "Windows (disco externo Kingston XS1000)" {
       insmod part_gpt
       insmod fat
       insmod chain
       search --no-floppy --fs-uuid --set=root @XS1000_EFI_UUID@
       chainloader /EFI/Microsoft/Boot/bootmgfw.efi
   }
   ```

   (The menu title stays in Spanish, as on the machine: "Windows (external disk Kingston XS1000)".)
   **Much simpler than on the IdeaPad**: the Legion boots the XS1000 from its own firmware,
   so GRUB (which uses the firmware's drivers) sees it and it is enough to jump to its loader. No UEFI
   shell, no `startup.nsh` or OpenCore drivers. **Windows booted from this entry**
   (2026-10-03; the user went in and updated it). A later attempt did not go in (cause not
   found; for a while the XS1000 was disconnected) and **afterwards it booted fine again**.
3. **Removes the ISO's kernel** (`vkpurge rm 6.12.11_1`); 6.12.111 stays as a fallback (the
   `linux6.12` package keeps being updated: 6.12.112 on 2026-10-05; it shows as orphan and `void-update`
   respects it).
4. **Silent boot**: the IdeaPad's `silent-boot.sh`, as is (here too there was
   `/etc/modules-load.d/dm-raid.conf`, from the installer: it stays `.desactivado`). Kernel line:
   `quiet loglevel=3 rd.udev.log_level=3 udev.log_level=3 vt.global_cursor_default=0`.
5. **"void-xterm" theme** with `install-theme.sh` (installs `python3-Pillow` and `fonttools`). **The
   theme was adapted to any screen** (2026-10-03, common scripts in `common/grub-theme/`):
   - `install-theme.sh` reads the panel's resolution (`/sys/class/drm/card*-eDP-*/modes`, first
     line) and puts it in `GRUB_GFXMODE` (here `1920x1200,auto`; on the IdeaPad `1366x768,auto`).
   - `build.py` takes it from `GRUB_GFXMODE` and **scales all sizes** by height/768 (logo,
     rows, margins, letters; PF2 fonts of 25 px for the console and 31 px for the countdown);
     under the logo it puts the **machine name** (`Legion-Go-Gen-2`), formerly a fixed "ideapad-100".
   - **On the IdeaPad it comes out identical**: generated with the old script and with the new one, the 16 files
     of the theme match byte for byte. Preview of another machine without installing anything:
     `THEME_SCREEN=1920x1200 THEME_HOST=name python3 build.py folder "Entry 1" … --preview preview.png`.

   Painted entries (they must be those of the menu, in this order): Linux 6.18.55, Linux 6.12.111 (today
   6.12.112: the hooks of `/etc/kernel.d/` redo the background when the kernel changes), UEFI Firmware
   Settings and Windows. **Verified by the user** after rebooting: the menu looks
   fine.

Rules, the IdeaPad's: **unmount `Common` before booting that Windows**, shut it down with
**Shift + Apagar** (Shift + Shut down) (otherwise Fast Startup leaves it hibernated and Linux does not mount its NTFS) and **do not
write to the firmware** (`MODIFY_EFI_ENTRIES=0` in `/etc/default/efibootmgr-kernel-hook`, already
like that by default). Revert: `sudo rm /boot/grub/custom.cfg`, `sudo sh
"$B/common/boot/silent-boot.sh" --remove` and `sudo bash
/usr/local/share/grub-theme/install-theme.sh --remove`.

### Hidden GRUB: straight to the newest kernel (2026-10-04)

**The user's decision:** no menu and no wait. `grub-hidden.sh` (in `legion/`):

```bash
sudo sh "$B/legion/grub-hidden.sh"            # applies (regenerates the menu)
sudo sh "$B/legion/grub-hidden.sh" --remove   # back to the menu with the theme, 5 s
```

It puts in `/etc/default/grub` (leaves `.bak`):
- `GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden`: no menu; it boots the first entry, which is
  always the newest kernel. **With 0 s there is no way to bring up the menu at power-on** (0 was chosen and
  not 1 s with Esc): the **Windows on the XS1000**, from the Legion's firmware boot menu;
  the **fallback kernel**, `--remove` from the system (or from a live if it did not boot).
- **`GRUB_TERMINAL_OUTPUT=console`** and **`GRUB_GFXPAYLOAD_LINUX=keep`**: even hidden, GRUB changed
  the video mode for its theme (`gfxterm`, 1920×1200) and **the firmware logo went off for an
  instant**; this way GRUB does not touch it and the kernel boots in the mode the firmware left. The theme
  (point 5 above) stays installed but is not seen while this is set.
- Removes `amdgpu.seamless=1` if it finds it (see below).

Check: in `/boot/grub/grub.cfg`, `set timeout_style=hidden`, `set timeout=0`. **Verified
by the user** (2026-10-04): from the firmware logo straight to the system. **Trap:** if it is run twice,
the `.bak` already keeps the new value (it does not matter: `--remove` sets 5 s without looking at the `.bak`).

### Plymouth: tried and REMOVED (2026-10-03 and 04)

**Today the Legion boots without Plymouth, like stock Void** (the user's decision, 2026-10-04: "lo
minimalista, todo por defecto" — "the minimalist way, everything default"): from the firmware logo to the session, with no animation. **In a
reinstall: do not install Plymouth** (do not run `install-plymouth.sh`) and Game Mode with
`--no-loading-screen` (step 14). To remove it from a system that already has it (what was done on
2026-10-04 with a one-shot script, already deleted), in this order: `sudo sh
"$B/common/boot/install-plymouth.sh" --remove` (theme, `splash`, gives back
`agetty-tty1`); `sudo xbps-remove plymouth plymouth-data` (they only depend on each other); remove from
`GRUB_CMDLINE_LINUX_DEFAULT` what came from the tests (`amdgpu.seamless=1`, `video=…`); `sudo sh
"$B/legion/grub-hidden.sh"` (regenerates the menu); `sudo dracut --force --regenerate-all` (check with
`sudo lsinitrd /boot/initramfs-<version>.img | grep plymouthd`: nothing); and `sudo sh
~/steam/install-game-mode.sh --no-loading-screen`. **Leftover:** `xbps-remove` left
`/etc/plymouth/plymouthd.conf` (`[Daemon]` `Theme=bgrt`); without the package it does nothing and can be
deleted (`sudo rm -r /etc/plymouth`; see *Pending*). What was learned,
in case it comes back:
- **Scale:** with such a dense screen Plymouth uses scale 2 by itself and stretched the
  56 px frames (the symbol, blurry). `install-plymouth.sh` now computes the panel's scale (height/768
  rounded: 1200 → 2) and generates the frames at that size (112 px) with **`DeviceScale=1`**
  (common; on the IdeaPad, identical to before).
- **Trap: `DeviceScale` goes AFTER `Theme`** in `plymouthd.conf`: the reader of
  `plymouth-set-default-theme` (and dracut, which uses it to choose the initramfs theme) only looks at the
  first key of `[Daemon]`; in front, it says `spinner`. The installer stops if it does not read `bgrt-void`.
- **Flickers** (why it was removed): with hidden GRUB, the firmware logo went to black **when the
  symbol appeared** and **two more times** before Steam (with the external monitor one was seen; without
  it, all of them, on the Legion's screen). `sudo dmesg`: `efifb` uses the firmware's image
  (0.27 s), Plymouth starts at 0.77 s but waits for `amdgpu` (1.85–2.34 s) and programs the screens
  at 2.46 s; the panel's preferred mode is **1920×1200 at 144 Hz** (EDID), gamescope also goes at
  144 Hz. **`amdgpu.seamless=1`** was tried (active, `/sys/module/amdgpu/parameters/seamless` = 1:
  not enough) and **`video=eDP-1:1920x1200@60`** (test A, a script already deleted; it was not evaluated).
  Every screen handover (amdgpu, Plymouth, gamescope, the loading screen) could leave a black;
  without Plymouth or loading screen there are fewer handovers and **the user sees it "better, faster"**.
  (A false lead: the `MST_DSC dsc precompute` of `dmesg` also shows without the dock: it is not from the MST.)
- **Hibernation:** dracut puts in the initramfs `resume=UUID=@LEGION_SWAP_UUID@` (the swap); it does not depend on
  Plymouth (see "Hibernation and brightness on wake", step 14; verified on 2026-10-04).

**The XS1000 is seen through the dock and directly:** the Legion detects it directly on the USB-C (10 Gbps,
`usb6`) and through the dock (Genesys USB 3.1 hub, 5 Gbps). For a while it did not show up anywhere:
it was disconnected (checked with `udevadm monitor`). What **has not been checked** is whether the
**firmware** sees it at boot through the dock (GRUB depends on that).

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

### InputPlumber: the Legion's controller as a Valve controller (2026-10-04)

SteamOS's bridge: it joins the controller (through `hidraw`), its touchpad and the body's gyroscope
(`gyro_3d`/`accel_3d`, `amd_sfh`) into a virtual Valve controller. **"Body" = the tablet, the part
with the screen:** it is the only gyroscope that reaches Steam (the emulated Deck controller has only one;
InputPlumber's capabilities are `Gamepad:Gyro` and `Gamepad:Accelerometer`, without one per controller).
With the controllers attached it makes no difference (everything moves together); **with the controllers detached, moving them does
nothing**: only moving the tablet counts (observed by the user on 2026-10-05; see *Pending*). With it Steam sees all the buttons
(back ones included), the Deck-style touchpad and the gyroscope, and on the desktop Steam handles it
with its desktop layout. **It is not in Void**, but the official binary works as is (it only
lacks `libiio.so.0` = Void's `libiio` 0.26) and **it does not need `hid_lenovo_go`**.

```bash
cp "$B/legion/"{install-inputplumber.sh,inputplumber-x86_64.tar.gz,inputplumber-udevadm} ~/
sudo bash "$B/legion/install-inputplumber.sh"          # remove: --remove
# afterwards: close Steam completely and open it again
```

- **Download:** `inputplumber-x86_64.tar.gz` of **v0.81.0** (GitHub `ShadowBlip/InputPlumber`,
  14-09-2026), copy in `legion/`; the script checks its SHA-256 (`bb167707…f777b`).
- **What it does:** installs `libiio` and `acl-progs` if missing; copies the package's files (binary, profiles, udev
  rules, hwdb, D-Bus and polkit policy) **except** the systemd units and
  `90-inputplumber-autostart.rules` (list in `/usr/local/share/inputplumber-void/manifest`, used
  by `--remove`); reloads udev and D-Bus; runit service **`inputplumber`** (`sv check dbus` and
  `LOG_LEVEL=info`), with a readable log in **`/var/log/inputplumber/current`** (`svlogd`).
- **Hiding the original devices (2026-10-04).** InputPlumber hides the original controller from the other
  programs (`chmod 000` + `setfacl -b` with its own rules in `/run/udev/rules.d/`). On Void
  it failed with `WARN … Failed to hide device '…': "Unable to create match rule for device"` because of
  **two differences with SteamOS**: it reads the name and the subsystem from the `M:` and `U:` lines of
  `udevadm info` (`src/udev/mod.rs`, `get_device`), which **eudev's `udevadm` does not print** (only
  `P:`/`N:`/`E:`), and its rules use **`setfacl`**, which was not there (`acl-progs`). Consequence:
  Steam also saw the `Generic X-Box pad` and created **two** controllers (`Microsoft X-Box 360 pad 0` and
  `1`). Fix without touching packages: **`inputplumber-udevadm`** (in `legion/`) installed
  as `/usr/local/lib/inputplumber-void/bin/udevadm` and put **first in the service's `PATH`**
  (only for InputPlumber): for `udevadm info <device>` it adds `M:`, `U:` and `T:` from
  `P:`, `E: SUBSYSTEM=` and `E: DEVTYPE=`; everything else goes to the real `udevadm`. **Verified on 2026-10-04,
  also after rebooting:** 0 `Failed to hide` warnings, originals (`Generic X-Box pad`, keyboard,
  mouse and touchpad of the "Legion Controller", the controller's `hidraw`) with permissions `000`, **a single
  controller** in Steam (Ajustes → Mando / Settings → Controller) and all buttons in the button test.
- **Own profile** `/etc/inputplumber/devices.d/50-legion_go_2.yaml` (takes priority over
  `/usr/share/inputplumber/devices/`): the package's one with `deck-uhid` instead of `xbox-elite`. Without
  it Steam would see an Xbox Elite.
- **The body's gyroscope and accelerometer** (`gyro_3d`/`accel_3d` through `amd_sfh`, InputPlumber's `iio`
  sources): 0.81 declares them in its Go 2 profile (SteamOS's 0.78 does not, and there it did not
  work), but they did not reach Steam. **Debugging of 2026-10-04**, in order:
  1. **Symptom:** with "Uso: Giroscopio" ("Usage: Gyro") as mouse in the desktop layout, turning the
     console moved nothing. Steam's "Probar entradas del dispositivo" ("Test Device Inputs") **does not show the gyroscope**
     (it is no use for this).
  2. **The sensor does work:** `/sys/bus/iio/devices/iio:device*/in_anglvel_{x,y,z}_raw` (the one
     named `gyro_3d`) changes when turning: integers of up to ±60 in a normal turn.
  3. **Cause 1 — essential, checked:** `inputplumber device 0 capabilities` did not have
     `Gamepad:Gyro` or `Gamepad:Accelerometer`. The profile's two `imu` sources carry **`blocked:
     true`**: InputPlumber opens them but discards their data. The profiles of other consoles with a
     gyroscope (Ayaneo, GPD, AYN) do not carry it. The installer removes it from the own profile (only from
     those two; the other 4 `blocked`, the ones that hide the original keyboard, mouse and touchpad,
     stay). Afterwards, the capabilities do include `Gamepad:Gyro` and `Gamepad:Accelerometer`.
  4. **Cause 2 — the scale the kernel declares:** the gyroscope gives raw **integer °/s** (a
     slow turn ≈ 28) but declares `in_anglvel_scale` 0.000174532 (0.01 °/s in rad/s), **100 times
     less**; the accelerometer gives **integer m/s²** (gravity ≈ 9) and declares `in_accel_scale` 0.098
     (gravity 0.9: **10 times less**). InputPlumber does `(raw + offset) × scale`, then the
     **`mount_matrix`** (linear) and then ×916.73 to Deck units (code of v0.81:
     `src/drivers/iio_imu/driver.rs`, `src/input/source/iio/accel_gyro_3d.rs`; there is no scale
     option in the profile, `ImuConfig`/`IIO` only accept `mount_matrix`). The installer puts a
     diagonal `mount_matrix` **100** (gyroscope) and **10** (accelerometer), axes untouched.
     **Need of the ×100: deduced, not proven with an A/B test** — without it ≈15
     units would arrive when turning (≈1 °/s, noise) instead of ≈1500; the test after unblocking is no use
     to rule it out because it was done **without touching the trackpad** (see 6). **The accelerometer's ×10
     is not necessary for the gyroscope as mouse** (it does not use the accelerometer); it corrects gravity
     for Steam's modes that orient themselves with it. To prove the ×100: `GYRO=1` in the
     installer, reinstall (see warning below) and check that the pointer barely moves.
  5. **Check of what Steam receives:** reading the virtual Valve controller (the `/dev/hidraw*`
     of `28DE:12FB`; the Deck's report 0x09: accelerometer `int16` in bytes 24–29, gyroscope in
     30–35, 0.0625 °/s per unit): accelerometer ≈ 15,190 (1 g = 16,384), gyroscope from hundreds to
     ≈ 1500 when turning, following the sensor second by second. Script: **`diag-gyro.sh`** (in
     `legion/`, without root: `sh "$B/legion/diag-gyro.sh"` and turn the console for 20 s).
     **Reference result (2026-10-04):** capabilities with `Gamepad:Gyro` and
     `Gamepad:Accelerometer`; when turning, rotation towards Steam from hundreds to 1535 following the sensor
     **axis by axis** (sensor x = 60 °/s → first axis 1135; y = 49 → second axis 1023: X→X, Y→Y, Z→Z);
     at rest, acceleration (0, −14409, −4803), magnitude ≈ 15,190 (0.93 g). **The sensor has low
     resolution:** the gyroscope goes 1 °/s at a time and the accelerometer 1 m/s² at a time (steps of 1601
     Deck units); enough for the pointer, it can feel stepped when aiming very finely.
     It is the same sensor and driver as in SteamOS.
  6. **In Steam, the gyroscope as mouse only acts with the thumb resting on the right trackpad**
     (like on the Deck, so the pointer does not move when picking up the console): it was not a failure, nothing had to be
     changed. With that, **it works** (verified by the user on 2026-10-04). "Uso: Giroscopio" ("Usage: Gyro")
     as mouse stayed in the desktop layout (copy in Common); "Ninguno" ("None") removes it.
  **Correct axes** (the pointer goes where you turn; verified by the user on 2026-10-04):
  the `mount_matrix` does not need to reorder them. **In a game it also works:** Borderlands 3
  (verified by the user on 2026-10-04). The gyroscope of each detached controller is something else
  (without `hid_lenovo_go` it is not activated). In the log there are warnings `Unable to read available scales
  … ENOENT` from the IMU: they are normal.
- **Reinstalling or restarting InputPlumber can leave the session unresponsive:** on start it asks
  udev to remove and add again all the input devices (to hide the originals) and
  labwc can be left without keyboard or mouse (in `~/.xsession-errors`: `libseat … Could not close
  device: Device not taken`). It happened once on 2026-10-04: reboot (over SSH, `sudo reboot`).
- **Check:** `pgrep -a inputplumber`; `ls /sys/bus/hid/devices/ | grep 28DE` →
  `0003:28DE:12FB…` with `HID_NAME=Legion Go 2 Controller` (**the same virtual controller as in
  SteamOS**); in `/proc/bus/input/devices`, `InputPlumber Mouse/Keyboard/Touchpad` and, with Steam
  open, **a single** `Microsoft X-Box 360 pad 0`; `grep -c 'Failed to hide'` in the log does not
  grow when restarting the service. The kernel still sees `Generic X-Box pad`, hidden (permissions
  `000`; InputPlumber only uses it for vibration).
- **Verified by the user on 2026-10-04** on the desktop (Xfce Wayland, Steam open).
  In Game Mode, all the buttons (2026-10-04). **Suspend:** systemd's `inputplumber-suspend.service`
  (HookSleep/HookWake) has no equivalent here and **is not needed**: on wake the
  controller reconnects over USB and InputPlumber adds it again by itself (`Found missing hidraw device
  … adding source device`); the controller works entirely (2026-10-04). The gyroscope in a game, verified later
  (Borderlands 3, point 6 above).
- **CPU usage: measured on 2026-10-08 and left as is** (the user's decision). Tool:
  **`legion/diag-inputplumber-cpu.sh`** (read-only; it does not restart InputPlumber or touch the
  profile). It does **three passes of 20 s, ~65 s in total** (`DUR=30 sudo -E …` changes the duration): 1)
  **without strace** (the reliable figure): CPU of the process and per thread, context switches and reads and
  writes per second; 2) `strace -f -c`, call summary; 3) trace counted **per descriptor
  translated to its path** (which `/sys/bus/iio/…`, `/dev/hidraw*`, `/dev/uhid` or `/dev/input/event*` is read
  or written and how many times per second) and the wait timeouts. It needs root and `strace` (`sudo
  xbps-install -S strace`; without it, it does only pass 1; remove it when done): `sudo bash
  diag-inputplumber-cpu.sh <label>` (`modojuego` and `escritorio` without touching the controller;
  `modojuego-mando` moving it all the time); result in `/tmp/medir-inputplumber-<label>.txt`
  (644; the script's header explains how to read it). While strace is attached (passes 2 and 3) the
  input can be somewhat slower.
  **Results of 2026-10-08** (pass without strace; the three files, archived in
  `fish/void/logs/legion/medir-inputplumber-{modojuego,escritorio,modojuego-mando}-2026-10-08.txt`):

  | Situation | CPU (% of one core) | Wakeups/s |
  |---|---|---|
  | Game Mode, idle | 3.2 | ~7170 |
  | Desktop (Xfce Wayland, Steam in the background and `extest`) | 3.5 | ~7110 |
  | Game Mode, moving the controller | 3.3 | ~7200 |

  **It is a fixed cost, the same in all modes.** Where it comes from: (1) **the body's IMUs**
  (`iio:device1` `gyro_3d` and `iio:device2` `accel_3d`, with the iio buffer off, at 200 Hz):
  InputPlumber **opens, reads and closes** each of the 6 `in_*_raw` files about 389 times per second
  (double the sensor's 200 Hz), ~9000 calls/s, with a `clock_nanosleep` loop of 2.1–2.4
  ms; (2) **the virtual Valve controller:** ~830–920 `write`/s to `/dev/uhid` (necessary: it is what
  Steam sees); (3) little from the physical controller (`/dev/hidraw1` 33/s, `event10` ~190–310/s). **Unexplained:** the
  average since the process started is around 10 % (there were periods of higher usage that the measurement did not catch).
  **Option studied and NOT applied:** lowering `AngvelSampleRate`/`AccelSampleRate` (writable D-Bus
  properties of `org.shadowblip.Input.Source.IIOIMUDevice`, today 200) to 100 live. It would save more
  or less half, at the cost of fewer gyroscope samples, without knowing whether the sensor accepts it (it does not
  publish available frequencies) and without persisting (it is lost when InputPlumber restarts). Blocking
  the IMUs again, as it comes from the factory, would remove the body's gyroscope: discarded. See
  *Pending → Decided*.

### Fine TDP: `lenovo-wmi-*` modules via DKMS (2026-10-04)

`lenovo-wmi-gamezone` and `lenovo-wmi-other` (with `-helpers`, `-events` and `-capdata01`) **are in the
normal 6.18 but Void does not enable them** (`CONFIG_LENOVO_WMI_GAMEZONE`/`_TUNING`). They give the profile
**`custom`** and the power limits in `/sys/class/firmware-attributes/lenovo-wmi-other-0`,
which is what `steamos-manager` uses. No own kernel: a DKMS package with the sources of 6.18.55.

```bash
cp -r "$B/legion/tdp" ~/
sudo bash "$B/legion/tdp/install-tdp.sh"               # remove: --remove
```

- **Sources:** `drivers/platform/x86/lenovo/wmi-*.{c,h}` and `firmware_attributes_class.h` of the
  stable **v6.18.55** (`git.kernel.org`, `plain/…?h=v6.18.55`), **unchanged**, in
  `tdp/lenovo-wmi-tdp/` with a `Kbuild` (the same module names as the kernel) and its
  `dkms.conf` (`BUILD_EXCLUSIVE_KERNEL="^6\.18\."`, `AUTOINSTALL`, destination `/updates`).
- **What it does:** `xbps-install dkms linux6.18-headers`; copies to `/usr/src/lenovo-wmi-tdp-6.18.55`;
  `dkms install`; `modprobe`. At boot they load by themselves (they go by the firmware's WMI GUIDs) and
  DKMS rebuilds them when another 6.18 is installed (hook in `/etc/kernel.d/`). **With a 6.19 they are not
  built** (on purpose): its new sources will have to be brought or check whether Void already enables them.
- **Updates** (2026-10-04): within 6.18, `void-update` installs the new kernel and the
  hook `/etc/kernel.d/post-install/10-dkms` rebuilds the modules by itself (the headers
  `linux6.18-headers` are updated in the same transaction); when deleting old kernels,
  `pre-remove/10-dkms` removes them. **The risk was the series change**: the `linux` metapackage
  (installed) would bring `linux6.19` when Void changes series, the hidden GRUB would boot the
  newest and there there are no modules (on purpose, `BUILD_EXCLUSIVE_KERNEL`). As **6.18 is LTS** and
  Void maintains its LTS (`linux6.1`, `6.6`, `6.12` are still there), **the metapackages are held**:

  ```bash
  sudo xbps-pkgdb -m hold linux linux-headers   # linux6.18 keeps updating; it does not jump series
  xbps-query -H                                 # linux-6.18_1, linux-headers-6.18_1
  # moving to another series, on purpose: sudo xbps-pkgdb -m unhold linux linux-headers (and bring the
  # lenovo-wmi-* sources of that series, or check whether Void already enables them)
  ```

  **Held on 2026-10-04**; that day `void-update` ended with the 9 checks OK
  ("✓ Todo en orden" / "✓ All in order": TDP for 6.18.55_1, kernel held, 6.18 series = the recommended one,
  gamescope, libraries of InputPlumber/`steamos-manager`/`extest`, no `.new-*`, no reboot).
  Also, **the summary of `void-update`** (step 6 of the IdeaPad recipe) checks that the
  module is built for the newest kernel (if it is 6.18.x and missing, it rebuilds it), warns if
  the metapackages are not held and **warns when Void recommends another series** (compares the
  repository's `linux` with the installed one): that way you know when to consider the change.
- **The Go 2 is foreseen in the driver:** DMI `Legion Go 8ASP2` in its `fwbug_list`.
- **Check:** `dkms status` → `installed`; `cat /sys/class/platform-profile/*/{name,choices}` →
  `lenovo-wmi-gamezone` with `low-power balanced performance custom` (the other one is `amd-pmf`, with 3);
  in `…/lenovo-wmi-other-0/attributes/`: `ppt_pl1_spl` 5–35 W, `ppt_pl2_sppt` 5–37 W,
  `ppt_pl3_fppt` 5–45 W (factory values: the maximum). The limits only apply with the profile
  `custom`. The usual `/sys/firmware/acpi/platform_profile` says `custom` when the two
  drivers do not match: it is not an error.
- **Verified on 2026-10-04** (built on the first try, 6.18.55_1).

### steamos-manager: TDP, profiles and GPU clock from Steam (2026-10-04)

Valve's service with which Steam handles **Rendimiento** (Performance) (the `…` menu). The Go 2 has an official
profile (`/usr/share/steamos-manager/devices/legion-go-series.toml`: `83N0`/`83N1` →
`legion_go_2`): TDP through `lenovo-wmi-other-0` (profile `custom`), profiles of
`lenovo-wmi-gamezone`, GPU level and manual clock through `amdgpu` (`[gpu_performance]`), and it sets
in InputPlumber `deck-uhid, keyboard, mouse`. **It needs the modules of the previous section.** Binary v26.4.1
**with an own patch** (`set_clocks`, below; since 2026-10-08), built here with
`build-steamos-manager.sh`; everything in `common/steam/steamos-manager/`, with the official tarball without
patch (the one from the Void container, IdeaPad recipe, step 14) to go back.

```bash
cp -r "$B/common/steam/steamos-manager" ~/steam/
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"   # remove: --remove
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen # the launcher starts the user one
sudo sh "$B/legion/gpu-overdrive.sh" && sudo reboot                     # manual GPU clock (below)
```

- **Two processes, as in SteamOS:** the **root** one (`steamos-manager -r`, system bus) is the
  runit service **`steamos-manager`** (log `/var/log/steamos-manager/current`); the
  **user** one (session bus: Steam talks to it) is started by the Game Mode launcher
  (`install-game-mode.sh`, since 2026-10-04: only if `/usr/lib/steamos-manager` exists; its
  log goes to `steam-game-mode.log`). On the desktop it does not run: Performance belongs to Game Mode.
- **The installer** (`xbps-install` of `speech-dispatcher` and `glib` if missing) copies the tree of
  `make install` **without** systemd units, sddm setting or D-Bus activation files
  (`Exec=/bin/false` + `SystemdService`), with a list in `/usr/local/share/steamos-manager-void/manifest`
  (used by `--remove`), removes `[gpu_power_profile]` from the profiles if `pp_power_profile_mode` is missing
  (below), and reloads D-Bus. The rest of `legion-go-series.toml` stays as it comes. In the same folder
  it records, on every installation (since 2026-10-08), the **reference that `void-update` reads**: `sha256`
  (output of `sha256sum /usr/lib/steamos-manager /usr/bin/steamosctl` as they were installed; it is
  checked by `sha256sum -c`) and `package` (the tarball's name without `.tar.gz`, e.g.
  `steamos-manager-v26.4.1-void-2`: with it `void-update` says whether it is the patched one or the official one).
  `--remove` deletes the whole folder.
- **It needs `tracefs`**, which Void does not mount: without it, it crashed on start with `Error: No such file or
  directory (os error 2)` after "Starting SLS log receiver" (its `ftrace` creates
  `/sys/kernel/tracing/instances/…`). It was found by `diag-steamos-manager.sh` (in the foreground with
  `RUST_LOG=debug`: without tracefs exit 1; with it, 124 = running). The `run` mounts it
  (`mountpoint -q /sys/kernel/tracing || mount -t tracefs nodev /sys/kernel/tracing`).
- **GPU power profile: impossible with this kernel.** It reads `device/pp_power_profile_mode`,
  which the normal amdgpu **does not provide** on this GPU (SMU 14.0.0: its table in 6.18.55 has no
  `get_power_profile_mode`; **neither does Valve's**: checked on 2026-10-04 in the source of
  `linux-neptune-618-6.18.50.valve2`, SteamOS's on this Legion, where only
  `smu_v14_0_2` has it, from the RDNA 4 dedicated graphics cards; nor in Linux 7.3-rc5). The installer removes `[gpu_power_profile]` from
  the profiles if the file does not exist: Steam does not show the option and there are no errors (a `WARN
  Can't add GpuPowerProfile1 interface` remains, expected).
- **Manual GPU clock: overdrive** (`gpu-overdrive.sh`, in `legion/`; `--remove`).
  Without bit `0x4000` of `amdgpu.ppfeaturemask` (factory `0xfff7bfff`), writing to
  `pp_od_clk_voltage` gives `Invalid argument`. It goes in **`/etc/modprobe.d/amdgpu-overdrive.conf`**
  (`options amdgpu ppfeaturemask=0xfff7ffff`), not in GRUB (`silent-boot.sh` rewrites the whole
  kernel line), and the script rebuilds with `dracut` the initramfs **of all installed
  kernels** (it copies it inside; new kernels already bring it when installed; until 2026-10-08,
  only that of the running kernel). The kernel becomes *tainted* ("Overdrive is enabled" in `dmesg`): only a
  warning. With "Reloj de GPU manual" ("Manual GPU Clock") enabled in Steam it works (verified on 2026-10-04 at 2900 MHz,
  below).
- **With the manual clock disabled, the official steamos-manager fills the log with `Error setting
  manual GPU clock: Invalid argument`** (harmless: the GPU stays at `auto`; **the patch removes it**,
  next point). Steam reapplies its performance
  profile many times per session and always sends the saved clock (`manual gpu clock enabled: 0`
  + `manual gpu clock hz: 2900` in `steamui_steamos.txt`); steamos-manager 26.4.1 writes it to
  `pp_od_clk_voltage` even if the level is `auto` (`AmdgpuPerformanceLevelDriver::set_clocks`:
  *Only used when GPU Performance Level is manual, but write whenever called*) and **this GPU's SMU 14
  only accepts a fixed clock in `manual` mode** (`smu_v14_0_od_edit_dpm_table`: *Only allowed in
  manual mode*). Hundreds show up per session (179 until 2026-10-08; not 1–3 at start, as was believed
  at first). Removing `[gpu_performance]` removes them, but also the manual clock: do not do it.
- **Patch `0001-gpu-set_clocks-only-in-manual.patch`** ("set_clocks only in manual") (2026-10-08, approved by the user): at the
  start of `AmdgpuPerformanceLevelDriver::set_clocks` (`steamos-manager/src/gpu.rs`) it reads the level
  and, if it is not `manual`, it writes nothing (`debug!`, which with `RUST_LOG=info` does not show) and returns OK. **Nothing
  is lost:** outside `manual` the driver rejected that clock anyway. It assumes that Steam,
  when enabling "Reloj de GPU manual" ("Manual GPU Clock"), sets the level to `manual` **before** sending the clock: in
  `steamui_steamos.txt` it always writes `Set manual gpu clock enabled` before `hz`, but with the clock
  enabled **too** (confirmed on 2026-10-08, below: the clock is applied immediately). It adjusts
  two tests (`test_set_amdgpu_gpu_clocks`: with `auto` it does not write, with `manual` it does;
  `manager/root.rs` `manual_gpu_clock`: sets `manual` before). The process that writes is the **root** one
  (the user one only passes `SetManualGpuClock` over D-Bus): restarting the service is enough.
- **How it is built** (without root, on this machine; 1 min 30 s): dependencies `sudo xbps-install -S
  glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config` (plus `git`, `make` and the Rust
  of rustup in `~/.cargo/bin`, `extest`'s; on 2026-10-08, Rust 1.99.0), and then

  ```bash
  bash "$B/common/steam/steamos-manager/build-steamos-manager.sh" /tmp
  ```

  Before anything it **tests the patch** against that tag (`patch-still-needed git`, since
  2026-10-09; YA_INCLUIDO (ALREADY_INCLUDED) → it does not build; CONFLICTO (CONFLICT) → it stops; on 2026-10-09, HACE_FALTA (STILL_NEEDED) on v26.4.1, commit
  `a0d399defebd`, the same that the script checks). `void-update` also looks at the latest upstream
  tag and, if it is new, tests the patch against it (NOTA (NOTE) on its line).
  It clones the tag `v26.4.1` in `~/src/steamos-manager` (checks commit `a0d399d`), applies the
  `0*.patch` of its folder, `make build`, `make test` inside `dbus-run-session` (two tests, the
  `job` one and the `ftrace` one, need a session bus: over SSH they fail without it, also without the patch),
  `make install DESTDIR=…` and packs `/tmp/steamos-manager-v26.4.1-void-2.tar.gz` (owner `root`), which
  is copied by hand to the Common folder. It checks `ldd`, `steamosctl --version` and that the list of
  files, permissions and owners is that of the official tarball; when done it deletes `~/src/steamos-manager`.
  **Result of 2026-10-08:** 248 of 248 tests fine; same 62 entries as the official tarball (only
  the two binaries change); `ldd` without `not found` (here and on the IdeaPad); `steamosctl --version` =
  `steamos-manager 26.4.1`; binary `/usr/lib/steamos-manager` with sha256 `cc464424…1586c`, **identical
  bit for bit** in two consecutive builds (the official one installed until now: `a4b222d7…5faf6`).
  **The build dependencies are kept on purpose** (the user's decision, 2026-10-08: they are
  needed to rebuild steamos-manager with `build-steamos-manager.sh` after an update, and that
  script stops if any is missing). Cost: 34 packages, **≈ 470 MB** installed (with `libllvm21`, which
  only clang uses; Mesa uses `libllvm22`), which `void-update` updates with the rest. They are only
  steamos-manager's: `extest` uses rustup's Rust and `gcc-multilib`, and gamescope and the wlroots portal are
  built with `xbps-src`, which installs their dependencies inside its own environment
  (`binary-bootstrap`, in `~/src/void-packages`), not in the system. To remove them one day (before,
  `speech-dispatcher` marked as manual, below): `sudo xbps-remove -R glib-devel eudev-libudev-devel
  speech-dispatcher-devel clang pkg-config` (`xbps-remove -Rn …` shows the list first). The crates
  cache stays in `~/.cargo/registry` (from 24 to 151 MB).
  **`speech-dispatcher`, marked as manually installed** (recommended): `sudo xbps-pkgdb -m manual
  speech-dispatcher`. It provides `libspeechd`, which steamos-manager needs (the binary does not come from xbps, so
  xbps does not know). `install-steamos-manager.sh` only installs it if missing, and with the ISO's `orca`
  it is already there, as an automatic dependency. Today it is held by `orca` and `speech-dispatcher-devel`; if one day
  both were removed (or an `xbps-remove -R` dragged it along), steamos-manager would stop starting. That is why
  the command also goes in list J. `strace` (from the InputPlumber diagnosis) is still installed:
  pending the user's decision (*Pending → To do*).
- **Installing the patch on the already installed Legion** (2026-10-08): `install-steamos-manager.sh` already uses
  `steamos-manager-v26.4.1-void-2.tar.gz` (to go back to the official one, change `TAR` to the one without `-2` and
  repeat it). It is installed with `sudo sh /tmp/instalar-steamos-manager-parche.sh` (run by the user;
  copies of the installer and of the tarball in `/tmp/sm-parche`, without Common): it checks the tarball's sha256,
  calls the installer, which reinstalls and restarts the service, and shows the binary's sha256 and `sv
  status`. The user process keeps the old binary in memory until leaving and entering
  Game Mode again (or rebooting): it is not needed for the fix, but that way both run the same.
  **Verified on 2026-10-08** (below).
- **Why it does not happen on the Steam Deck:** the Deck does not carry a Z1 (that one is the ROG Ally's and the Legion Go
  1's), but an APU of Valve's own, **Van Gogh** ("Aerith" in the LCD, "Sephiroth" in the OLED; SMU
  11.5), whose driver accepts writing the clock (`OD_SCLK`) at any level. The Legion Go 2 carries the
  **Z2 Extreme** (Strix Point, SMU 14.0.0), and there `smu_v14_0_od_edit_dpm_table` rejects it outside
  `manual`. steamos-manager is designed for the Deck and always writes the clock, and Steam resends the
  saved value on every performance update: hence the errors.
- *History (2026-10-08):* the manual clock and the overdrive **were removed due to a misunderstanding** (it
  was approved believing that it was no use here; it was: 2900 MHz in `manual` on 2026-10-04).
  `install-steamos-manager.sh` removed `[gpu_performance]` from `legion-go-series.toml` and
  `gpu-overdrive.sh --remove` deleted the `.conf`; verified after rebooting (00:48): GPU at `auto`,
  `ppfeaturemask` `0xfff7bfff`, no new error, and TDP and profiles working (checked by the
  user: they do not depend on `[gpu_performance]`). The same day **they were brought back**: the installer again
  leaves the profile as it comes (except `[gpu_power_profile]`) and `gpu-overdrive.sh` is applied again.
  On the already installed Legion, with `sudo sh /tmp/legion-gpu-manual.sh` (run by the user; it adds
  `[gpu_performance]` in its original place if missing, runs `/tmp/gpu-overdrive.sh` and restarts
  `steamos-manager`) and rebooting. **Verified on 2026-10-08, already with the patch** (below).
- **Wi-Fi power saving: Steam asks for it.** Here it broke SSH (steps 2–3). In Game Mode:
  **Ajustes → Sistema → "Activar modo desarrollador"** (Settings → System → "Enable Developer Mode"), and on the new page **"Desarrollador"** ("Developer"),
  **turn off "Habilitar administración de energía para Wi-Fi"** ("Enable Wi-Fi Power Management") (texts of
  `steamui_latam-json.js`: `Settings_System_EnableDeveloperMode`, `Settings_Developer_WifiPowersave`).
  The "Desarrollador" page does not exist without developer mode, nor in the desktop's Big Picture.
- **Remaining noise:** `SetWifiBackend … Wi-Fi backend not found in config` every time Steam
  starts (it asks to set the Wi-Fi engine and steamos-manager only knows how to do it with systemd: it does not touch
  NetworkManager, which is what we want), and warnings from `org.freedesktop.systemd1`. **Do not "fix it"
  by creating `99-valve-wifi-backend.conf`** (Troubleshooting, *Known noise in the logs*).
- **Check:** `sudo sv status steamos-manager` → `run`; in Game Mode, `pgrep -a -f
  '^/usr/lib/steamos-manager'` → the two processes; `cat /sys/module/amdgpu/parameters/ppfeaturemask`
  → `0xfff7ffff` (overdrive); `grep -c '^\[gpu_performance\]'
  /usr/share/steamos-manager/devices/legion-go-series.toml` → `1`; `cat
  /sys/class/drm/card*/device/power_dpm_force_performance_level` → `auto` (`manual` only with "Reloj de
  GPU manual" ("Manual GPU Clock") enabled in Steam); `sha256sum /usr/lib/steamos-manager` → `cc464424…1586c` (with the
  patch); with the manual clock disabled, `grep -c 'Error setting manual GPU clock'
  /var/log/steamos-manager/current` does not grow after entering Game Mode; `iw dev wlp193s0 get
  power_save` → `off`.
- **Verified on 2026-10-04** in Game Mode: power profiles (the power button's LED
  changes color with each one: it is Lenovo's firmware), TDP limit (`ppt_pl1_spl` following
  Steam) and manual clock at 2900 MHz (`power_dpm_force_performance_level` = `manual`, `OD_SCLK`
  2900/2900, `freq1_input` = 2900 MHz; removed and brought back on 2026-10-08, above); Wi-Fi `off` with Steam's setting disabled.
  **InputPlumber in Game Mode: all the buttons** (Steam's button test).
- **`set_clocks` patch and manual clock brought back: verified on 2026-10-08** (after `sudo sh
  /tmp/instalar-steamos-manager-parche.sh` and rebooting at 01:28): `sha256sum /usr/lib/steamos-manager`
  = `cc464424…1586c`; with the manual clock **disabled**, Steam still sends `enabled: 0` / `hz: 2900`
  (01:28:48, 01:29:48, 01:31:48) and **no new `Error setting manual GPU clock`** (the counter
  stayed at 185, the last one at 01:10, before the patch); **enabled at 2000 MHz** (01:30:32): level
  `manual`, `OD_SCLK` 2000/2000 and `pp_dpm_sclk` at 2000\*; **disabled** (01:31:25): back to
  `auto`. Steam sends first `enabled` and then `hz` (`steamui_steamos.txt`). Checked again, without
  root, at the boot of 20:45 (with Game Mode used): sha256 the same, counter at 185 (the last one,
  `2026-10-08_07:10` UTC = 01:10), `ppfeaturemask` `0xfff7ffff`, `[gpu_performance]` present and level
  `auto`.

### Decky Loader (2026-10-04)

```bash
sudo sh "$B/common/steam/install-decky.sh"            # the same as the IdeaPad's (common/steam/), unchanged
```
The same as on the IdeaPad (its recipe, step 14, *Decky Loader*): `psmisc` and `inotify-tools`,
`~/homebrew/{services,plugins}`, `~/.steam/steam/.cef-enable-remote-debugging`, `/home/deck` →
`/home/isaac`, `PluginLoader` **v3.2.9** from GitHub (it updates itself from its menu: v3.2.10 on 2026-10-07; the `run`
restarts it when it detects it) and the runit service `decky`. Then restart
Steam (it reads the debugging file on start). Check: `pgrep -a -f
homebrew/services/PluginLoader`, port `127.0.0.1:1337` open and the plug icon in the
quick menu. **Verified on 2026-10-04.** Plugins installed from its store: **SteamGridDB**
(`decky-steamgriddb`) and **CSS Loader** (`SDH-CssLoader`); on 2026-10-09, **Colores** (v0.31.0) and
**Panel de Control** (v0.67.1), both by Hooandee.

**Colores (the controllers' RGB LEDs) needs `hidapi`** (2026-10-09). The plugin talks to the LEDs through
`libhidapi-hidraw.so.0`, which it loads with `ctypes`; SteamOS ships it and Void does not. Without it the plugin
disables all HID and says it does not detect a controller with RGB (its log,
`~/homebrew/logs/Colores/*.log`: `driver=NullDevice … available=False`). Fix: Void's official
package, and restart Decky so that the plugin loads again:

```bash
sudo xbps-install -S hidapi
sudo sv restart decky
```

Check: in the plugin's log, `Found Legion Go device: PID=0x61EB … usage_page=0xFFA0` and
`Successfully set Legion Go RGB`. The plugin runs as root (`flags: root`), so it opens the controller even though
InputPlumber has it hidden (`/dev/hidraw0`–`2` with permissions `000`), and they do not step on each other. After suspending
it sets the color again (`restored lighting after … suspend`), although it warns `No such file or directory:
'systemd-inhibit'` (Void does not have it; it does not matter). **Verified by the user on 2026-10-09**, also
after suspending.

### xterm library art (2026-10-04)

As in SteamOS (§13.7 of its recipe), with a generator now saved:
**`common/steam/art-xterm/generate.py`** (without root; it uses `rsvg-convert`, the system's `python3-Pillow`
—no venv needed here— and `fc-match` for the font). Papirus's xterm icon
(`utilities-x-terminal.svg`) rasterized at 1024 px, centered on a radial gradient + halo + scan
lines, and "XTERM" in JetBrainsMono Nerd Font Mono bold, Super Game Bro palette. It looks in
`shortcuts.vdf` for the shortcut whose `Exe` contains `xterm`, takes its **unsigned** `appid`
(`appid & 0xFFFFFFFF`: here `-178361309` → `4116605987`) and writes in
`~/.local/share/Steam/userdata/@STEAM_ACCOUNT_ID@/config/grid/`: `<appid>p.png` (600×900), `<appid>.png`
(920×430), `<appid>_hero.png` (1920×620), `<appid>_logo.png` (1200×400, transparent),
`<appid>_icon.png` (512×512) and `<appid>.json` (logo bottom left, 50 %).
**Quick menu icon:** it comes from the `icon` field of `shortcuts.vdf`, not from `grid/`: the generator
puts there `~/.local/share/icons/steam-shortcuts/xterm-color-256.png` (Papirus at 256 px), **only with
Steam closed** (otherwise Steam overwrites it on exit; it warns with `!!` and it has to be repeated), with a copy
`shortcuts.vdf.bak`.
```bash
cp "$B/common/steam/art-xterm/generate.py" ~/steam/art-xterm/
python3 "$B/common/steam/art-xterm/generate.py"      # with Steam closed (on the desktop), and then open Steam
```
Check: in the library, xterm with cover, banner and logo; in the quick menu, its icon.
**What was done here (2026-10-04):** the art, with the generator with Steam open (it shows after
restarting Steam); the **icon**, from Steam's own interface, without closing it: *xterm →
Propiedades → Acceso directo* (*Properties → Shortcut*) → click on the icon box → choose
`~/.local/share/icons/steam-shortcuts/xterm-color-256.png` (Steam saves it itself in
`shortcuts.vdf`). The generator with Steam closed is the alternative. **Verified by the user.**

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

### Remote Play (Remote Play Together) in Game Mode: 32-bit PipeWire and VA-API (2026-10-07)

**Symptom:** from the desktop it worked; from Game Mode, the guest only saw **Steam's waiting
screen** (diamond background) and "La entrada está temporalmente desactivada mientras el host está
ocupado" ("Input is temporarily disabled while the host is busy"). Diagnosis in `~/.local/share/Steam/logs/streaming_log.txt`, in three steps:

1. `CDesktopCapturePipeWire: Failed to create PipeWire main loop` when the stream starts (it also shows
   on the desktop, where Steam captures in another way; in gamescope it depends on PipeWire). **Steam's
   client is 32-bit** and there was `libpipewire-32bit` but not its modules: `/usr/lib32/spa-0.2/` did not exist
   (`support/libspa-support.so`). They come with **`pipewire-32bit`**.
2. With that: `PipeWire stream state changed to connecting` → `Could not connect receiving stream` (the
   `gamescope` node did exist, `Video/Source`, in the same PipeWire) and `Capture method set to Desktop
   Placeholder` (the waiting screen). **`libspa-videoconvert-32bit`** was missing (the 64-bit one was there).
   Also the hardware encoder did not load (`libva: Trying to open
   /usr/lib32/dri/radeonsi_drv_video.so` → `va_openDriver() returns -1`; it fell back to x264 on the CPU):
   **`mesa-vaapi-32bit`** was missing. And not even the 64-bit **`mesa-vaapi`** was there (no hardware video
   decoding in any program; SteamOS ships it).
3. With everything: **`Capture method set to Desktop PipeWire NV12 DMABUF + VAAPI H264`** (gamescope's direct image
   through PipeWire, without copies, and encoded by the GPU). The occasional jumps to `Desktop
   Placeholder` while Steam's menu has the focus are the "host busy" notice, not failures.

```bash
sudo xbps-install -S pipewire-32bit libspa-videoconvert-32bit mesa-vaapi-32bit mesa-vaapi
# leave Game Mode and come back (Steam loads the modules on start)
```

**`install-steam.sh` (common) installs them since 2026-10-07:** `pipewire-32bit` and
`libspa-videoconvert-32bit` always; `mesa-vaapi` and `mesa-vaapi-32bit` only with an AMD GPU (on Intel it does not
install VA-API: on the IdeaPad, HD 5500, `intel-media-driver` works, iHD driver 26.3.5, verified with
`vainfo` on 2026-10-09; it is installed by `ideapad-al-dia.sh --video`). On this Legion they were installed by hand, so they are not in
`legion/steam/installed-packages.txt` (its `--remove` does not remove them). **Verified by the user**
(2026-10-07, Nuclear Throne with a guest): the stream loads and you can play. In the log: it starts at
22:48:17 (`Streaming started`), a few seconds alternating with `Desktop Placeholder` while Steam's menu
had the focus, and from 22:48:25 `Desktop PipeWire NV12 DMABUF + VAAPI H264` continuously until
the end (22:55:58, where a last `Desktop Placeholder` shows when the stream closes: it is normal).

### Controller on the desktop: Steam in the background, `extest` and the desktop layout (2026-10-04)

Like SteamOS's desktop mode: Steam runs in the background on the desktop (Xfce Wayland or
X11) and the controller (InputPlumber's Valve one) handles the desktop with Steam's **"Disposición del
escritorio"** ("Desktop Layout") (pointer with the right trackpad or the right joystick, clicks with the
triggers, on-screen keyboard with RT+X…). Three pieces, all user ones:

```bash
D="$B/legion/steam"
mkdir -p ~/.config/autostart ~/.local/share/applications ~/.local/lib/extest
cp "$D/steam-background.desktop" ~/.config/autostart/
rm -f ~/.config/autostart/steam-segundo-plano.desktop   # the old Spanish name, if it is there (otherwise Steam starts twice)
cp "$D/steam-extest.desktop" ~/.local/share/applications/steam.desktop
install -m 755 "$D/extest/libextest.so" ~/.local/lib/extest/   # or build it (below)
# the desktop layout (with Steam CLOSED):
cp "$D/desktop-layout-controller_steamos_handheld.vdf" \
   "$HOME/.local/share/Steam/steamapps/common/Steam Controller Configs/<account id>/config/413080/controller_steamos_handheld.vdf"
```

- **Steam in the background:** `~/.config/autostart/steam-background.desktop` → `steam -steamdeck
  -silent` (`-steamdeck`: the same client as Game Mode; `-silent`: without a window), with
  `extest`'s `LD_PRELOAD` in front. `xfce4-session` starts it in both sessions. It closes cleanly
  on logout (`xfce4-session` wrapper), when going to Game Mode (`steamos-session-select`) and when
  switching Wayland/X11 (`switch-mode-root`). Remove: delete the file.
- **The pointer did not move on Wayland:** Steam moves the mouse with **XTest**
  (`XTestFakeRelativeMotionEvent`) through Xwayland, which does not pass it to labwc's pointer: an invisible
  pointer acted only on the X windows (the trackpad **selected text in xterm** without moving
  the cursor; the right joystick, the same) and no `uinput` mouse was created. Known bug of
  Steam on Wayland (`steam-for-linux` #10814, #6615, #13185 on Hyprland). On SteamOS's X11 it does not
  show.
- **Tested and discarded:** InputPlumber's `touchpad` target (live, `SetTargetDevices
  deck-uhid,keyboard,mouse,touchpad` over D-Bus) moves the real pointer, but Steam kept
  acting at the same time through XTest (stray clicks and selections); it was put back to `deck-uhid, keyboard,
  mouse` (what `steamos-manager` sets).
- **`extest`** (GitHub `Supreeeme/extest`, the piece that Bazzite and similar ship; on CachyOS with
  Hyprland the desktop controller worked like this): a library loaded into Steam with
  `LD_PRELOAD`, it intercepts its XTest calls and creates a **`uinput` mouse/keyboard** (`extest fake
  device`), which labwc uses like a real one. It is not in Void and has no compiled release; **32-
  bit** (Steam's client is). Built like this on 2026-10-04 (copy of the exact source,
  `extest-1.0.3-src.tar.gz` with its `Cargo.lock`, and of the library in `legion/steam/extest/`):

  ```bash
  sudo xbps-install -Sy gcc-multilib        # link in 32-bit (brings glibc-devel-32bit)
  curl -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
  sh /tmp/rustup-init.sh -y --profile minimal --no-modify-path    # Rust in ~/.rustup and ~/.cargo
  . ~/.cargo/env && rustup target add i686-unknown-linux-gnu
  git clone --depth 1 --branch 1.0.3 https://github.com/Supreeeme/extest ~/src/extest   # commit 0d06867
  cd ~/src/extest && cargo build --release  # its .cargo/config.toml already points to i686
  install -D -m 755 target/i686-unknown-linux-gnu/release/libextest.so ~/.local/lib/extest/libextest.so
  ```

  Rust takes ~770 MB (`~/.rustup`, `~/.cargo`) and `~/src/extest` 78 MB: they can be deleted after
  building (`rm -rf ~/.rustup ~/.cargo ~/src/extest`). **Permissions:** `/dev/uinput` already has the ACL
  `user:isaac:rw` (Steam's rules): the `input` group that its README asks for is not needed. The
  `ld.so: … wrong ELF class: ELFCLASS32` in `~/.xsession-errors` are normal (the 32-bit library
  is also offered to the 64-bit processes Steam launches, which ignore it). The desktop
  Steam also carries the `LD_PRELOAD` (`steam-extest.desktop` → `~/.local/share/applications/
  steam.desktop`; the generic `steam.desktop` of that folder, without it, is the IdeaPad's). **Game
  Mode does not need it** (gamescope accepts XTest).
- **Ghost clicks from the trackpad:** the factory template (`~/.local/share/Steam/controller_base/
  desktop_neptune.vdf`) puts on the right trackpad (`absolute_mouse` mode) the left click with the
  activator **`Soft_Press` ("Pulsación suave" / "Soft Press")**, and the Legion's touchpad gave it with light touches. In
  the controller's "Calibración y configuración avanzada" ("Calibration & Advanced Settings") **there are no trackpad settings** (only joysticks,
  gyroscope and haptic response: no click pressure for the virtual controller). The
  activator was changed to **"Pulsación doble"** ("Double Press") (`Double_Press`; "Duración de doble toque" ("Double Tap Duration") 325 ms, in the
  settings of "Como mouse" ("As Mouse")): Steam → **Configuraciones de Steam → Control** (Steam Settings → Controller) → current layout of
  the buttons "… Desktop - Desktop Configuration" → **"Editar disposición"** ("Edit Layout") → right trackpad
  ("Como mouse") → its click action (left mouse click) → gear → activator. Other possible
  activators: "Presionado normal" ("Regular Press") (full press) or "Ninguna - Eliminar activador" ("None - Remove Activator").
  The triggers, from the factory: **right = left click, left = right click** (`Full_Press`).
  Steam saved it in `Steam Controller Configs/@STEAM_ACCOUNT_ID@/config/413080/
  controller_steamos_handheld.vdf` (413080 = the desktop layout; copy in Common).
- **Check:** `grep '^N:' /proc/bus/input/devices | grep extest` → `extest fake device`; `pgrep
  -af 'steam.*-silent'`; on the desktop, the trackpad moves the pointer and only clicks with a double
  tap, the right joystick moves the pointer, RT+X opens the keyboard and types. **Verified by the
  user on 2026-10-04.**

### Hibernation and brightness on wake (2026-10-04)

**It works without configuring anything else:** 32 GB swap (`nvme0n1p2`) and **`/sys/power/resume` =
`259:2`** (= `nvme0n1p2`), set by dracut's initramfs (`resume=UUID=@LEGION_SWAP_UUID@`; the kernel
line does not carry it); `/sys/power/disk` = `platform`, lockdown `none`. From the session:

```bash
loginctl hibernate        # powers off completely; on power-on (hidden GRUB) it restores the session
```

- **Check that it restored and did not boot anew:** `uptime -s` gives the same time as before (the
  `uptime` does not count the time hibernated). Over SSH, `loginctl` answers `challenge` (it is not the
  active session); from the session, without password.
- **Verified on 2026-10-04, twice** (22:5x and 23:09; boot 22:46:26 in both): session with
  its windows, Wi-Fi with `Power save: off`, Wayland (`wayland-0`), InputPlumber adds the
  controller again by itself (a stray `Failed running device evdev://event2` and right away `Found missing input
  device`), `extest`, Steam in the background and the overdrive; whole controller (user). Without `Common`
  or another NTFS mounted (mounted, hibernating risks the volume).
- **The built-in screen's brightness changed:** at 100 % before, ~32 % (151040/472000) after.
  Writing the same value again did not fix it (`brightness` stayed at 151040; amdgpu's
  `actual_brightness` goes on another scale and is no use to compare it); it was the value that
  was lost. **elogind hook** (`brightness-on-wake.sh`, in `legion/`; `--remove`):
  `/etc/elogind/system-sleep/brightness` (the folder that elogind reads on Void, next to
  `/usr/libexec/elogind/system-sleep/`) saves the brightness of each screen in `pre` (in
  `/run/brightness-before-sleep`: it is memory and travels in the image) and puts it back in `post`, for
  hibernating and suspending. Log: `/run/brightness-on-wake.log`. **Verified on 2026-10-04:**
  `23:09:15 hibernate: brillo repuesto (amdgpu_bl0 472000)` (brightness restored), brightness 472000/472000.

```bash
sudo sh "$B/legion/brightness-on-wake.sh"
```

### microSD: Steam library, always mounted at boot (2026-10-05)

**What it has** (`mmcblk0p1`, ext4, UUID `@MICROSD_UUID@`; 378 of 938 GB, read
on 2026-10-05): the **Steam library from the SteamOS days** (`steamapps`, 307 GB: 44
manifests = 41 games + Protons and runtimes; the biggest, Monster Hunter: World
99 GB and Warframe 45 GB) and, outside Steam (~72 GB), the emulator things: Switch games (Zelda
Tears of the Kingdom, Pokémon Púrpura (Violet) and Legends Arceus, Splatoon 3, with mods, DLC and updates),
`Keys 17.0.0/prod.keys`, `Firmware 17.0.0`, 3DS Monster Hunter, the GeForce NOW installer and
`emuladores.txt` (SteamOS's shortcuts: Citra via Flatpak, Yuzu EA as AppImage; their paths
are from `/home/deck` and `/run/media/deck`, they no longer exist). In the root, its `libraryfolder.vdf`
(`contentid` 2598751261084087311): that is why Steam recognizes it as a library.

**The problem:** the desktop session (udisks) mounted it on login, in
`/run/media/isaac/<UUID>`, and Steam saved it with that path in its two `libraryfolders.vdf`
(`~/.local/share/Steam/config/` and `…/steamapps/`). Booting straight into Game Mode there is no desktop
session to mount it. **Fix** (the user's decision): `microsd-at-boot.sh` (in
`legion/`; `--remove` undoes it), **with Steam closed** (otherwise, Steam rewrites its
`.vdf` on exit; the script refuses if it is open):

```bash
sudo sh "$B/legion/microsd-at-boot.sh"
```

- **`/etc/fstab`** (leaves `fstab.bak`):
  `UUID=@MICROSD_UUID@ /mnt/microsd ext4 defaults,noatime,nofail,x-gvfs-show 0 0`.
  **`nofail` is essential:** on Void, if `mount -a` fails at boot,
  `/etc/runit/core-services/03-filesystems.sh` opens the emergency console; with `nofail`, without the
  card it boots anyway. `fsck` pass 0 (like when udisks mounted it). `x-gvfs-show`: it shows in Thunar.
- It moves it from `/run/media/isaac/<UUID>` to **`/mnt/microsd`** and changes that path in the two
  `libraryfolders.vdf` (with `sed`, like the user).
- **Verified on 2026-10-05** after rebooting (19:32): `findmnt /mnt/microsd` → `/dev/mmcblk0p1
  ext4 rw,noatime` (without the `nosuid,nodev` that udisks sets: the boot mounted it, not the session) and in
  `~/.local/share/Steam/logs/content_log.txt`: `Mounted library folder "/mnt/microsd"` and `Loaded 44
  apps`. The mount is the system's, before any session: it is equally valid for Game Mode (it has not
  yet been booted straight into it with the card).
- **In a reinstall** Steam's `.vdf` do not have it: after the script, add it in Steam as a
  library choosing `/mnt/microsd` (Steam reads its `libraryfolder.vdf` and the games already there).
  **Not tested** on a new installation.
- Leftovers on the card, untouched: `.Trash-1000` (28 KB) and an `.ovpn` in `Monster Hunter/`.

### SteamOS settings: compared live with a Steam Deck (2026-10-05)

**How it was compared:** a Steam Deck LCD at home (`ssh deck`, SteamOS 3.8.16, kernel
6.16.12-valve24.5; access set up in the Claude context) and the Legion, both running, reading
the same on both (read-only): kernel and its line, `sysctl`, huge pages, swap, CPU, disk
scheduler, mounts, limits, modules, background processes, audio priority, global environment and
versions. For Game Mode, SteamOS's session (the Deck's `/usr/lib/steamos/gamescope-session`,
**identical** to that of this Legion's SteamOS saved in the rescue,
`gamescope-session-valve-original`) against our launcher. What differed and was applied:

| What | Deck (SteamOS) | Legion before | Where it is applied |
|---|---|---|---|
| `kernel.split_lock_mitigate` | 0 (`/usr/lib/sysctl.d/30-splitlock.conf`) | 1 | `like-steamos.sh` |
| `fs.inotify.max_user_watches` / `_instances` | 524288 / 1024 (`10-arch.conf`) | 175875 / 128 | `like-steamos.sh` |
| `net.core.default_qdisc` | `fq_codel` (systemd's `50-default.conf`) | `pfifo_fast` | `like-steamos.sh` |
| Transparent huge pages | `always` | `madvise` | `like-steamos.sh` (`/etc/rc.local`) |
| Audio (PipeWire, WirePlumber) | real time, RR 20, nice −11 (`rtkit`) | normal | `like-steamos.sh` (`rtkit` installed; D-Bus starts it) |
| `earlyoom` | running, `-M/-S 409600,307200 -r 3600` | no | `like-steamos.sh` |
| `gamemoded` | running | no | `like-steamos.sh` (`gamemode`, `libgamemode-32bit`) |
| 32-bit gamescope Vulkan layer | yes | no (`gamescope-32bit`) | `like-steamos.sh` and `install-steam.sh` |
| Steam with `-pipewire` | always (`/usr/bin/steam-jupiter`) | no | `like-steamos.sh` (desktop), `install-game-mode.sh` (Game Mode) |
| Kernel preemption | `CONFIG_PREEMPT=y` (full) | voluntary (`PREEMPT_DYNAMIC`) | `like-steamos.sh`: `preempt=full` |
| `memlock` | 8 MiB (systemd) | 1 MiB (`10-gcr-memlock.conf` of the `gcr` package) | `like-steamos.sh` |
| `ENABLE_GAMESCOPE_WSI=1` (gamescope's Vulkan layer in games) | yes | no | `install-game-mode.sh` |
| `GAMESCOPE_LIMITER_FILE` (Steam's FPS limiter) | yes | no | `install-game-mode.sh` |
| `STEAM_USE_DYNAMIC_VRS` + `RADV_FORCE_VRS_CONFIG_FILE` ("1x1") | yes | no | `install-game-mode.sh` (AMD GPU only) |
| `STEAM_DISPLAY_REFRESH_LIMITS` (screen range for Steam) | 40,60 (LCD) | nothing | `install-game-mode.sh`: 48,144 on the Legion Go 2 (DMI `83N0`/`83N1`) |

```bash
sudo bash "$B/legion/like-steamos.sh"               # with bash; if Steam is open, it closes it cleanly
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen
sudo reboot
# undo: sudo bash "$B/legion/like-steamos.sh" --remove   (the packages stay)
```

- **`like-steamos.sh`** ("like SteamOS"; in `legion/`; log `~/like-steamos.log`), in order:
  1. `/etc/sysctl.d/30-like-steamos.conf` (the table's four keys) and `sysctl -p`. Void
     loads it at boot (`/etc/runit/core-services/08-sysctl.sh` goes through `/etc/sysctl.d/*.conf`).
     The `fq_codel` queue applies to interfaces created afterwards; the Wi-Fi shows `noqueue`
     (its driver carries its own queue): it mostly affects the dock's network.
  2. Block `# >>> like-steamos` … `# <<< like-steamos` in `/etc/rc.local` with `echo always >
     /sys/kernel/mm/transparent_hugepage/enabled` (and applies it right away).
  3. Installs what is missing of `rtkit earlyoom gamemode libgamemode-32bit gamescope-32bit` (74
     packages with their 32-bit dependencies on 2026-10-05), `/etc/sv/earlyoom/conf` with
     `OPTS="-M 409600,307200 -S 409600,307200 -r 3600"` and enables `earlyoom` in runit. **`rtkit` does not go
     in runit** (2026-10-08): D-Bus starts it on demand when PipeWire asks for it
     (`/usr/share/dbus-1/system-services/org.freedesktop.RealtimeKit1.service`); with both they clashed
     (see *Watch*). If it finds `/var/service/rtkit` (installation from before 2026-10-08), it does
     `sv down rtkit` and removes the link; `--remove` also removes it if present (**verified after
     rebooting on 2026-10-08**, on both machines: see *Watch*). `gamemoded` is not a
     service: D-Bus starts it in the session when a game asks for it. The
     packages create the user `rtkit` and the groups `rtkit` and `gamemode` (2026-10-05); `isaac` is not
     in `gamemode`, same as `deck` on the Deck: it is not needed.
  4. `-pipewire` in `~/.local/share/applications/steam.desktop` and
     `~/.config/autostart/steam-background.desktop` (with `sed`, as the user; Common's copies
     `steam-extest.desktop` and `steam-background.desktop` already carry it).
  5. `preempt=full` in `GRUB_CMDLINE_LINUX` of `/etc/default/grub` (creates it if not there) and
     `update-grub`. **Not in `GRUB_CMDLINE_LINUX_DEFAULT`**: that one is rewritten entirely by
     `silent-boot.sh` and `grub-hidden.sh` (checked: they only touch that one).
  6. `/etc/security/limits.d/91-like-steamos.conf`: `isaac - memlock 8192` (the user's rules
     over `gcr`'s `@users`).
  - **Steam open:** the desktop one starts by itself in the background, so asking to close it was
    no use (the first time the script refused and did nothing). Now it closes it itself, like
    `05-close-steam.sh`: `steam -shutdown` with the process's own environment and `pidwait` (30 s).
- **`install-game-mode.sh`** (common, `common/steam/`): in the direct-screen branch,
  `ENABLE_GAMESCOPE_WSI=1`, `GAMESCOPE_LIMITER_FILE` and, if the GPU is AMD (`vendor` `0x1002`),
  `STEAM_USE_DYNAMIC_VRS=1` with its file `RADV_FORCE_VRS_CONFIG_FILE` (`1x1` = no reduction;
  Steam changes it from Performance). The files in `/tmp`, like SteamOS: games read them
  from inside Steam's container (pressure-vessel). And Steam with `-pipewire`. The 64-
  bit layer already came with the `gamescope` package (`VkLayer_FROG_gamescope_wsi.x86_64.json`, enabled
  with `ENABLE_GAMESCOPE_WSI=1` and disabled with `DISABLE_GAMESCOPE_WSI=1`).
- **Verified on 2026-10-05** after rebooting (20:58): the four `sysctl` keys, huge pages
  `always`, `rtkit` and `earlyoom` running, **PipeWire and WirePlumber in real time (RR 20, nice
  −11, same as the Deck)**, the five packages, and the desktop Steam with `-steamdeck -pipewire
  -silent`. **`preempt=full` and `memlock` verified the same day** after the second pass and another
  reboot (21:08): `preempt=full` in `/proc/cmdline`; `Max locked memory` 8388608 bytes in the
  graphical session (`/proc/<labwc pid>/limits`) and `ulimit -l` 8192 over SSH. **Game Mode verified
  the same day** (21:15–21:27) with Borderlands 3 and the Deck in its Game Mode next to it:
  - Steam with the same arguments as on the Deck (`-steamos3 -steampal -steamdeck -gamepadui
    -pipewire`) and its same gamescope variables plus the three new ones; in the game's process
    (`Borderlands3.exe`, `/proc/<pid>/environ`): `ENABLE_GAMESCOPE_WSI=1`, `GAMESCOPE_LIMITER_FILE`,
    `RADV_FORCE_VRS_CONFIG_FILE`, `STEAM_USE_DYNAMIC_VRS=1` (and `DXVK_HDR=1`), and **the layer loaded**
    (`/run/host/usr/lib/libVkLayer_FROG_gamescope_wsi_x86_64.so` in `/proc/<pid>/maps`).
  - **FPS limit at 30:** in `~/.local/share/Steam/logs/console-linux.txt`, `[Gamescope WSI]
    Swapchain received new refresh cycle: 33.33ms` (the game's layer applies it). Gamescope:
    screen at 120 Hz (`GAMESCOPE_DISPLAY_REFRESH_RATE_FEEDBACK`), VRR supported and off.
  - **Half-rate shading** (Performance): the `RADV_FORCE_VRS_CONFIG_FILE` file went from
    `1x1` to `2x2` when enabling it (RADV reads it live).
- **FPS limit at half without VRR (2026-10-05, found and solved with VRR).** With the layer already
  active, Steam's limit gave half: 30 → 15 and 60 → 30 in MangoHud, with the game without its own limit
  or with 60 (the game's own limit did work). Without the layer (`DISABLE_GAMESCOPE_WSI=1`),
  the limit did nothing: **before these settings the FPS limit did not work on the Legion**.
  - **Cause: the screen modes that gamescope fabricates.** The panel (EDID) only has one
    native mode, **1920×1200 at 144 Hz** (clock 380.16 MHz). gamescope recognizes the screen (`Got known
    display: lenovo_legiongo2_oled`, script `lenovo.legiongo2.oled.lua`, from gamescope 3.16.30; the
    Deck's, 3.16.23, does not have it) and for the other frequencies (48–144) it **fabricates** modes by stretching the
    vertical blanking time with the same clock. Steam sets the screen to a multiple of the limit that
    fits in the range (its help text says so: "ajustará automáticamente la frecuencia de
    actualización de la pantalla a un múltiplo de la frecuencia de fotogramas" — "will automatically adjust
    the display refresh rate to a multiple of the frame rate"). The user's test,
    limit → screen → result: **36 → 144 Hz → 36 ✓; 48 → 144 Hz → 48 ✓; 40 → 120 Hz → 20 ✗;
    50 → 100 Hz → 25 ✗** (32 → 128 Hz gave ~30, unexplained). With the fabricated modes one
    of every two refreshes is lost. Before `STEAM_DISPLAY_REFRESH_LIMITS` the screen stayed fixed in the
    fabricated 120 Hz mode and **all** the limits came out at half.
  - **Why the fabricated modes fail: not found out.** Unchecked suspicions: the amdgpu
    patches of Valve's kernel (with which that script was made), the panel's self-refresh (PSR;
    live test: `echo 1 > /sys/kernel/debug/dri/0000:c2:00.0/eDP-1/disallow_edp_enter_psr`,
    with debugfs mounted) or `amdgpu.freesync_video=1`. Not tested: with VRR it is not needed.
  - **`STEAM_DISPLAY_REFRESH_LIMITS=48,144`** in the launcher (only `83N0`/`83N1`, by DMI; like
    SteamOS with the Deck: 40,60 the LCD, 45,90 the OLED): Steam knows the range and governs the frequency
    (`GAMESCOPE_DYNAMIC_REFRESH`); without a limit it goes back to the native 144 Hz. The flicker when changing
    the limit is the mode change (it already happened before).
  - **Fix: VRR** (Rendimiento (Performance) → **"Habilitar VRR"** ("Enable VRR"); the screen supports it,
    `GAMESCOPE_VRR_CAPABLE` = 1). With VRR gamescope stays in the native 144 Hz mode and the screen
    refreshes when each frame arrives: the limit comes out exact (verified by the user on
    2026-10-05: `GAMESCOPE_VRR_ENABLED` = 1, screen 144 Hz, limit 40 → `refresh cycle: 25.00ms`).
    Steam saves the setting. Without VRR, use limits that divide 144 (36, 48, 72). **No flicker or
    brightness changes with VRR** on the OLED (user, 2026-10-05): **it stays like this** (the user's decision).
  - **Why VRR works** (explanation): without VRR the screen refreshes at a fixed pace and, to
    limit to 40, Steam sets it to 120 Hz and the layer shows a frame every 3 refreshes; as the
    panel only knows 144 Hz, gamescope fabricates the 120 mode by lengthening the pause between refreshes, and with
    that mode the refreshes arrive at half pace: 3 refreshes take twice as long and 20 come out. With VRR
    no mode is fabricated: the panel stays in its native 144 Hz mode but waits for each frame
    and refreshes when it arrives; Steam only spaces the frames (25 ms at 40 FPS) and does not count
    refreshes, so there is no half. Inside, VRR also lengthens the pause, but the
    driver does it refresh by refresh its own way (which works here), not with a complete mode change with
    the fixed pause (which is what fails).
  - **Limit inside the game or with Steam?** In consumption, the same: in both cases the GPU and the CPU
    stop making frames that are not going to be shown. Differences:

    | | Game's limit | Steam's limit (gamescope layer) |
    |---|---|---|
    | Consumption | same | same |
    | Input delay | lower if the game's limiter is good (it waits *before* reading the controls) | may add some (Steam's help warns: "mayor retraso de entrada" / "higher input latency") |
    | Regularity | depends on the game (some stutter) | very regular, the same in all |
    | Convenience | setting in each game | one control in the quick menu |

    **Recommendation:** by default Steam's, with VRR. In games where response matters
    (shooters, fighting), if the controls feel heavy, the game's with Steam's off.
    **Do not set both with different values** (they fight and stutter): if both are used, the game's
    somewhat above Steam's (e.g. 45 and 40) or disabled. In Borderlands 3 the game's
    limit works fine (user, 2026-10-05).
  - That day Steam set **Proton 11.0** for Borderlands 3 (on 2026-10-04, 9.0-2RC).
  - In Steam's log there are `[Gamescope WSI]` lines also from 2026-10-04, before enabling it:
    in some case it already loaded; from now on, always in Game Mode.
  - **Differences that remain with the Deck, on purpose:** here `--adaptive-sync` (the screen has
    VRR); there `-w 1280 -h 800`, the `steam` cursor and what belongs to its hardware or to systemd (see below), and
    the statistics pipe `-T` / `GAMESCOPE_STATS` (not copied: it is not known what Steam uses from it).
- **What was seen and NOT copied:**
  - **zram** (the Deck: zstd, half the RAM, priority 100): discarded by the user; with 21 GB
    of RAM it would hardly be used. Nor **zswap** (the Deck's kernel enables it, but there zram rules).
  - **PipeWire block size** (Deck: `clock.quantum` 512, minimum 256, maximum 8192, in
    `/etc/pipewire/pipewire.conf.d/context-properties.conf`; Legion: 1024/32/2048 from the factory):
    tuned to the Deck's sound; touch it only if there are crackles.
  - The Deck's kernel line (`amd_iommu=off`, `ttm.pages_min=2097152`,
    `amdgpu.sched_hw_submission=4`, `amdgpu.lockup_timeout`…): its chip's.
  - What systemd or SteamOS pieces require: `STEAM_LAUNCH_WRAPPER_SCOPE` (a cgroup per game),
    `STEAM_ALLOW_DRIVE_UNMOUNT/ADOPT` (format/unmount from Steam), `steamos-cfs-debugfs-tunings`
    (disabled on the Deck too; they are settings of the old scheduler, CFS).
  - The Deck's hardware: `STEAM_ENABLE_FAN_CONTROL`, `STEAM_ENABLE_STATUS_LED_BRIGHTNESS`,
    `jupiter-fan-control`. (`STEAM_DISPLAY_REFRESH_LIMITS` also belongs to its screen, but it **was
    applied** with the Legion's range, 48,144: see the table and "FPS limit at half".) `STEAM_ENABLE_CEC` (HDMI-CEC with dock)
    and `WINEDLLOVERRIDES=dxgi=n` (it goes with a Valve Mesa patch).
  - **Wi-Fi power saving:** the Deck has it on; here it was turned off on purpose (steps 2–3).
  - `sched_ext`: disabled on the Deck; Void's kernel does not have it.
- **It was already the same or better:** `vm.max_map_count`, `amd-pstate-epp` with `balance_performance`,
  `ntsync` (`/dev/ntsync` open to all), swappiness and disk writeback, `nofile`
  (524288 here; 1024/524288 on the Deck), and **newer versions on the Legion**: Mesa 26.2.4
  (Deck 26.0.0-devel) and gamescope 3.16.30 (Deck 3.16.23.4).

## 15. Xfce on Wayland (labwc) (2026-10-03)

**It is installed before the first boot into Game Mode:** `install-passwordless-switch.sh`
makes "Cambiar a escritorio" ("Switch to Desktop") go to `xfce-wayland`, and without labwc that session does not start (you
would be left without a desktop). `sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"` (the folder
`common/xfce-wayland/` copied to `~`). **labwc's keyboard now comes from `00-keyboard.conf`**
(`XKB_DEFAULT_LAYOUT=us` + `XKB_DEFAULT_VARIANT=intl` here; on the IdeaPad, `latam` and the file
the same as before, checked). **Firefox and Steam with only labwc's border** (`SetDecorations
border forceSSD`; in Firefox, "Barra de título" ("Title Bar") unchecked): detail in step 15 of the IdeaPad.
**Verified:** Game Mode's "Cambiar a escritorio" enters Xfce Wayland (labwc 0.20.2).

### Power button: press = suspend, held ~3 s = power menu, in both modes, like the Deck (2026-10-14)

The user's request: the Steam Deck's power button (a short press suspends, held opens the power menu) in Game Mode
and on the desktop. **What the Deck does** (read on it, SteamOS 3.8.28): logind ignores the key
(`HandlePowerKey=ignore`); in Game Mode `steamos-powerbuttond` (Valve, C, a user service started with the gamescope
session) reads the button and sends `steam -ifrunning steam://shortpowerpress` or, if still held after 1 s
(`alarm(1)`), `steam://longpowerpress`; its devices are marked by udev (`STEAMOS_POWER_BUTTON`, `TAG+="uaccess"`).
On its desktop, KDE: `PowerButtonAction=1` (suspend), no long press.

**What the Legion Go 2 sends** (captured on 2026-10-14, read-only, the last time with the lines printed live and a
stopwatch): the firmware tells the two presses apart by itself, at **~3 s**:
- **released before ~3 s:** the ACPI `Power Button` gives `KEY_POWER` pressed and released in the same millisecond,
  **when the button is released**;
- **held ~3 s:** the embedded controller types **Super+F16** on the internal keyboard (`AT Translated Set 2
  keyboard`, scancodes `0xdb`/`0x67`; Void's hwdb already maps `0x67` to F16, the same as Valve's for 83N0/83N1)
  **while it is still held**, and no `KEY_POWER` at all.
So each event is one action and nothing is timed here (the ~3 s is the firmware's; the Deck's 1 s cannot be had).
Holding much longer, the firmware powers off at once (happened on 2026-10-14). **How it was misread first** (kept,
so as not to repeat it): the first captures did not show when the button was released, `KEY_POWER` looked like
"at every press" and F16 like "~3–5.5 s after it" (it was the time since an earlier short press), so the order
was turned around for a while (press = menu, held = suspend); the stopwatch capture settled it.

**Before (careful):** elogind's default is `HandlePowerKey=poweroff`. On the desktop xfce4-power-manager blocks
it (inhibitor `handle-power-key`), but in **Game Mode one press powered the Legion off** (2026-10-14).

`common/power-button/`, installed with `sudo sh "$B/common/power-button/install-power-button.sh"` (and then
`sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen`, whose launcher starts it):
- **`/usr/local/bin/power-button --mode game|desktop`** (Python, standard library; not C: the user's decision, no
  build step, the same speed here, ~10 MB of memory and 0 % CPU at rest). Event-driven, no timers: it sleeps in
  `poll()` on the marked devices, a pidfd of its session's process (it ends with it) and a `timerfd` with
  `TFD_TIMER_CANCEL_ON_SET`, which the kernel cancels on every resume (`timerfd_resume()`): presses in the 2 s after
  waking up are ignored (the waking press would suspend it again). Game Mode: press → `steam://shortpowerpress`
  (Steam suspends), held → `steam://longpowerpress` (Steam's power menu); desktop: press → `loginctl suspend`,
  held → `xfce4-session-logout` (shut down, restart, suspend, hibernate, log out). One per user
  (the newest session's). Log: `~/.local/state/power-button.log`.
- **`/etc/udev/rules.d/70-power-button.rules`**: `POWER_BUTTON=1` and `uaccess` for the ACPI `Power Button` and, on
  83N0/83N1 only, the internal keyboard (the embedded controller's: no other keys come through it).
- **`/etc/elogind/logind.conf.d/50-power-button.conf`**: `HandlePowerKey=ignore`, `HandlePowerKeyLongPress=ignore`
  (reloaded with `SIGHUP`, no session touched; check: `busctl get-property org.freedesktop.login1
  /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey` → `s "ignore"`).
- **`/etc/xdg/autostart/power-button.desktop`**: the desktop's (X11 and Wayland). Game Mode: its launcher, only if
  the program is installed.
- xfce4-power-manager: `power-button-action` = 0 (nothing), in `legion/xfce/` (in the X11 session it would act too).

### Internal screen without wallpaper when coming from Game Mode: `wallpaper-watcher` (2026-10-04)

**Symptom:** when going from Game Mode to the desktop, the Legion's screen stayed **black** (the
external monitor fine). The cursor and the windows were visible on it: only `xfdesktop`'s wallpaper
was missing. Switching workspace fixed it until the next mode switch.
**Cause:** when the session starts, `xfsettingsd` applies the display profile
(`~/.config/xfce4/xfconf/xfce-perchannel-xml/displays.xml`: external at `0,62` back then (today `0,0`, step 13), Legion at `1920,0` at
144 Hz) **after** `xfdesktop` painted the wallpaper, and `xfdesktop` does not paint it again on the
internal screen. `xfdesktop --reload` brings it back (tested over SSH with the screen black).
**Fix:** `~/.local/bin/wallpaper-watcher` ("wallpaper watcher"; Python + the system's GTK, `common/xfce-wayland/`),
started from labwc's `autostart`. **Event-driven:** it waits for GTK's signals (screen
added/removed, geometry or scale change) and, half a second after the last one (they arrive in a
burst), calls `xfdesktop --reload` once. It also works when connecting or removing the monitor with the
session open. `install-xfce-wayland.sh` installs it (and its `--remove` removes it); to put it without
redoing everything: copy `wallpaper-watcher` to `~/.local/bin/` (755) and `labwc/autostart` to
`~/.config/xfce4/labwc/`. **Check:** `~/.local/state/wallpaper-watcher.log` (redone every
session) after coming back from Game Mode:
```
03:21:06 vigilando 2 pantallas
03:21:06 geometry: Unknown 1920x1080+0+62
03:21:06 geometry: Unknown 1920x1200+1920+0
03:21:07 xfdesktop --reload (rc=0)
```
("vigilando 2 pantallas" = "watching 2 screens") and the internal screen with wallpaper. **Verified by the user on 2026-10-04.**
**Discarded along the way** (so as not to repeat it):
- **SteamOS's Game Mode variables** (HDR, VRR, color): with `drm_info` at the black moment,
  `Colorspace=Default`, `HDR_OUTPUT_METADATA=0`, `VRR_ENABLED=0`, without `GAMMA_LUT`/`CTM`; the screen
  on, with its mode and its image assigned.
- **The panel's self-refresh (PSR)**: the panel supports it and it was in use, but blocking it
  live (`echo 1 > /sys/kernel/debug/dri/0000:c2:00.0/eDP-1/disallow_edp_enter_psr`, mounting
  debugfs first; it is lost on reboot) **changed nothing**. Panel Replay: the panel does not support it.
  The kernel was not touched (`amdgpu.dcdebugmask`).
- **The screen's state in amdgpu** (`sudo sh "$B/legion/diag-edp.sh" black|fine`, in `legion/`: reads the
  debugfs of `eDP-1`, the backlight and `dmesg`): **identical** black and with image.
- Tools used for this (read-only): `drm_info` and `wlr-randr`. **Removed on 2026-10-06**
  (final product, *Pending*, "Cleanup"); if they are needed again: `sudo xbps-install -S drm_info
  wlr-randr`. `drm_info` runs without root; `wlr-randr` needs `WAYLAND_DISPLAY=wayland-0` (over SSH, plus
  `XDG_RUNTIME_DIR=/run/user/1000`).

### Xwayland always alive: `xwaylandPersistence` (2026-10-06)

In the common `rc.xml`, inside `<core>`: `<xwaylandPersistence>yes</xwaylandPersistence>`. Without it,
labwc starts Xwayland on demand and closes it after 10 s without X programs (`Xwayland … -terminate`); what
the `autostart` loads with `xrdb` (`~/.Xresources`) was lost and xterm came out without a theme. **It was seen on the
IdeaPad** (detail in its recipe, step 15); **here it was not noticed** because Steam runs in the background on the
desktop (an X program) and keeps Xwayland alive; it would only happen when closing Steam completely. Put here
too (the same `rc.xml`) on 2026-10-06; it takes effect in the next desktop session (it changes when
labwc restarts). In Game Mode it does not apply (the Xwaylands are gamescope's). Check:
`grep -c xwaylandPersistence ~/.config/xfce4/labwc/rc.xml` → 1.

### Focus without raising: raise only on click (2026-10-06)

The user's request for both machines: focus follows the mouse, but the window **only comes to the front
with a click** (or with Alt+Tab, Super+arrows). In the common `rc.xml`, `<raiseOnFocus>no</raiseOnFocus>`
(before `yes`; clicks already focus and raise through the `mousebind`s of `<default/>`), and in xfwm4 (backup X11
session) `raise_on_focus` = `false` (`xfconf-query -c xfwm4 -p /general/raise_on_focus -s false`;
backed up in `legion/xfce/xfce-perchannel-xml/xfwm4.xml`). Applied live on 2026-10-06:
`rc.xml` copied with `mv` and labwc reloaded (`kill -HUP $(pgrep -x labwc)`, the same as `labwc
--reconfigure`). Detail in the IdeaPad recipe, step 13, *Foco* (*Focus*).

### Screen-share chooser always on top (2026-10-07)

In the common `rc.xml`, at the end of `<windowRules>`:

```xml
<windowRule identifier="screen-share">
  <action name="ToggleAlwaysOnTop"/>
</windowRule>
```

The chooser (`~/.local/bin/screen-share`, step 14) sets that identifier with
`GLib.set_prgname`. With focus without raising it stayed behind Vesktop and the portal kept waiting for it.
Installed on both machines with `mv` and `kill -HUP $(pgrep -x labwc)`; on the IdeaPad it does nothing (there
is no chooser). **Verified by the user** (2026-10-07). The same rule also carries `<action
name="SetDecorations" decorations="none"/>` (no bar or buttons; the user's request, 2026-10-07).

### Steam's on-screen keyboard: exception in the window rules (2026-10-04)

Steam's keyboard (RT+X) is a Steam Xwayland window (`WM_CLASS` `"steamwebhelper",
"steam"`, title "Teclado en pantalla de Steam Input" ("Steam Input On-Screen Keyboard"), **`_NET_WM_WINDOW_TYPE_UTILITY`**; the
main window is `NORMAL`; read with `xprop` on `DISPLAY=:0`) and two labwc rules fell on it:
the `llena` (full) region of `identifier="*"` and the forced border of `identifier="steam"`. It is excepted **by
type**, which does not depend on the language, with a rule at the end of `<windowRules>` that undoes them:

```xml
<windowRule identifier="steam" type="utility">
  <action name="UnSnap"/>
  <action name="SetDecorations" decorations="none"/>
</windowRule>
```

In the common `rc.xml` (`common/xfce-wayland/labwc/rc.xml`, also on the IdeaPad), installed with
`mv` and reloaded with `kill -HUP $(pgrep -x labwc)` (= `labwc --reconfigure`). It applies to the
windows that open afterwards. Applied on both machines on 2026-10-04.

### Desktop wallpaper on Wayland: patched xfdesktop (2026-10-09; installed)

**The same as on the IdeaPad** (its recipe, step 15, *Fondo de escritorio en Wayland* (*Desktop wallpaper on Wayland*): the bug, the
upstream commit `ed26b06a` and the pieces of `common/xfce-wayland/xfdesktop-wallpaper/`). In Xfce
Wayland the wallpaper dialog of `xfdesktop` 4.20.2 writes to `/backdrop/screen0/monitorUnknown/…` and
`xfdesktop` reads `monitor<connector>/…`: choosing a wallpaper does nothing. **Here there are two screens**, each one
with its connector: **`eDP-1`** (the Legion's) and **`DP-1`** (the external monitor; in
`/sys/class/drm/card0-*` on 2026-10-09). That day only `monitoreDP-1/workspace0/last-image` existed
(`xfce-x.svg`); no key for `DP-1`.

**Built here** on 2026-10-09 (2 min 47 s with `binary-bootstrap`): `build-xfdesktop.sh` run
from `/tmp/xfdesktop-wallpaper/` (no scripts in `~`), `xfdesktop-4.20.2_2.x86_64.xbps` (Void's revision +
1; sha256 `6f36c3908bd2ea75e834f268ce8194a58894c95e26f9c181d738d441579446d0`) copied to `Common`, and
`~/src/void-packages` and `/tmp/xfdesktop-wallpaper` deleted. It is **the same package** installed on the
IdeaPad.

**Installation** (root; `Common` is usually not mounted here, so it goes from `/tmp`; with this
repository, from the clone, where `install/fetch-assets.sh` left the package next to the installer):

```bash
# on the Legion (asks for the password and to confirm):
sudo bash "$B/common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh"
# originally: on the IdeaPad (or wherever Common is), copy the installer and the package to the Legion's /tmp,
#   scp "<disk>/Backups Linux/fish/void/xfce-wayland/xfdesktop-fondo/"{instalar-xfdesktop-fondo.sh,xfdesktop-4.20.2_2.x86_64.xbps} lego:/tmp/xfdesktop-fondo/
# then on the Legion, and delete when done:
#   sudo bash /tmp/xfdesktop-fondo/instalar-xfdesktop-fondo.sh
#   rm -rf /tmp/xfdesktop-fondo
```

**Check** (in Xfce Wayland, with the wallpaper dialog closed before installing): in an xterm,
`xfconf-query -c xfce4-desktop -m`; open the dialog **on the Legion's screen** and choose a wallpaper:
`/backdrop/screen0/monitoreDP-1/workspace<N>/last-image` must show up and the wallpaper of that screen must change;
take the dialog **to the external monitor** and choose another: `monitorDP-1/…` and that one's changes (the dialog
takes the screen **when it opens**: dragged to the other one it does not notice; you have to close it and open it on the screen
you want, checked on 2026-10-09). Never `monitorUnknown`. `xbps-query -p pkgver xfdesktop`
→ `xfdesktop-4.20.2_2`. **Verified on 2026-10-09 on both screens** (`monitoreDP-1` and `monitorDP-1`, each one with its wallpaper;
without `monitorUnknown`). `void-update` watches it **by testing the patch** against Void's code (since
2026-10-09; before it assumed "fixed in >= 4.20.3"): OK while it is needed, NOTA (NOTE) with the command to go back
to Void's if it already has it, AVISO (WARNING) if it does not apply (IdeaPad recipe, step 6, *Prueba de parches propios* (*Testing own patches*)).

### Wallpaper from Thunar on Wayland: patched Thunar (2026-10-09; installed)

**The same as on the IdeaPad** (its recipe, step 15, *Fondo desde Thunar en Wayland* (*Wallpaper from Thunar on Wayland*): the bug, the own
patch and the pieces of `common/xfce-wayland/thunar-wallpaper/`). In Xfce Wayland, Thunar's "Establecer como fondo de
pantalla" ("Set as wallpaper") writes to `monitorUnknown/…` (it uses `gdk_monitor_get_model`) and the wallpaper does not change; no
upstream fix on 2026-10-09. The patch asks `libxfce4windowing` for the connector (like `xfdesktop`) and
**still chooses the screen of Thunar's window** (`gdk_display_get_monitor_at_window`): here, with
two screens, `eDP-1` or `DP-1` depending on where the window is.

**Built here** on 2026-10-09: `Thunar-4.20.10_2` (Void's template was already 4.20.10_1, although the
mirror still gave 4.20.9_1; with 4.20.9 the next update would have replaced it without the patch), 1 min
2 s; `build-thunar.sh` run from `/tmp/thunar-wallpaper/` (no scripts in `~`). A first build
came out **without** `libxfce4windowing` (its `.pc` asks for wnck, xrandr and wayland-client in `Requires.private`):
the script adds those `-devel` and now **fails** if `configure` does not find it. `Thunar-4.20.10_2.x86_64.xbps`
(sha256 `70ccff54505dd70d09f6cdd0d00925c8113a1810843d480da0c351bab060999b`) and `Thunar-devel` copied to
`Common`; `~/src/void-packages` and `/tmp/thunar-wallpaper` of the build, deleted. **The same package**
installed on the IdeaPad. Only `Thunar` is needed (the plugin goes in it; `Thunar-devel` is not
installed).

**Installation** (root; from `/tmp`, already copied on 2026-10-09 together with the `xfdesktop` one; with
this repository, from the clone):

```bash
# on the Legion (asks for the password and to confirm):
sudo bash "$B/common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh"
thunar -q                      # as user: closes Thunar with the old plugin
# originally, from /tmp; if /tmp was emptied (reboot), from the IdeaPad or wherever Common is:
#   ssh lego mkdir -p /tmp/thunar-fondo
#   scp "<disk>/Backups Linux/fish/void/xfce-wayland/thunar-fondo/"{instalar-thunar-fondo.sh,Thunar-4.20.10_2.x86_64.xbps} lego:/tmp/thunar-fondo/
#   sudo bash /tmp/thunar-fondo/instalar-thunar-fondo.sh && thunar -q && rm -rf /tmp/thunar-fondo
```

**Check** (in Xfce Wayland): `xfconf-query -c xfce4-desktop -m` in an xterm; Thunar **on the Legion's
screen**, right click on an image → "Establecer como fondo de pantalla" ("Set as wallpaper"): `monitoreDP-1/…` and
the wallpaper of that screen changes; Thunar **on the external monitor**: `monitorDP-1/…` and that one's changes.
Never `monitorUnknown`. `xbps-query -p pkgver Thunar` → `Thunar-4.20.10_2`. **Verified on 2026-10-09 on both screens** (`monitoreDP-1` and `monitorDP-1`; without `monitorUnknown`). Unlike
the dialog, **dragging Thunar's window** to another screen is enough: it sets the wallpaper on the
one it is on at that moment. `void-update` watches it **by testing the patch** against Void's code (since
2026-10-09; before it assumed "fixed if Void's plugin links `libxfce4windowing`"), the same as
`xfdesktop`; `build-thunar.sh` also tests it before building (before, a `grep`).

## Troubleshooting

**The scripts do not stay on the Legion** (the user's decision, 2026-10-05: final product; see
step M of the list). To diagnose or undo, they are used from Common: with `Common` mounted on the
Legion, `sudo sh "<disk>/Backups Linux/fish/void/legion/<script>"` (the Steam ones, in `fish/void/steam/`);
with `Common` on the IdeaPad, copy it from there first: `scp "<disk>/Backups Linux/fish/void/legion/<script>" lego:`
and then `sudo sh ~/<script>` on the Legion (and delete it when done). **With this repository** they are
used from the clone on the Legion (point B of the list): `sudo sh "$B/legion/<script>"` (the common ones,
in `"$B/common/…"`); a script copied alone elsewhere does not find `lib/` (set `VOID_LEGION_REPO=<repo>`
then, `docs/i18n.md`).

Symptom → what it is → what to do. Everything here already happened on this Legion. The detail is in the step
cited, and what applies the same to the IdeaPad, in its recipe's *Troubleshooting*.

### `ssh lego` does not resolve or SSH does not get in

1. **With the dock:** avahi renamed itself to `Legion-Go-Gen-3.local` (it announced over both networks). It is
   prevented by `avahi-wifi-only.sh` (steps 2–3). Meanwhile, by IP:
   `ssh -o HostName=<IP> -o HostKeyAlias=legion-go-gen-2.local lego`.
2. **It does not even answer `ping` until the Legion transmits:** Wi-Fi power saving
   (`iw dev wlp193s0 get power_save` → `on`). Prevented by `wifi-no-powersave.sh` (steps 2–3) and the
   Steam setting ("Habilitar administración de energía para Wi-Fi" / "Enable Wi-Fi Power Management" disabled, step 14).
3. **The Wi-Fi shows as `wlan0` and "unmanaged":** udev skipped the announcement at boot. On the spot,
   `sudo udevadm trigger --action=add --subsystem-match=net`. Prevented by `udev-net` (steps 2–3).
4. **After reinstalling:** the host key changed → on the IdeaPad, `ssh-keygen -R Legion-Go-Gen-2.local`.

### The screen stays off after a mode switch

From another machine: `ssh -t lego sudo sv start lightdm` and `cat /run/switch-mode.log`. It happened with the
version of `restart-lightdm` launched with `setsid` (it died with the session). The current one runs under
runit (`sv once mode-switch`): check `ls -l /var/service/mode-switch` (step 14, "Race with
elogind").

### After a mode switch the screen flickers and the panels look different

It is the race with elogind: it deleted `/run/user/1000` with the new session's `wayland-0` and everything fell back
to X11. On the spot, reboot. Check: `ls /run/user/1000 | grep -c wayland-0` → 2. Permanent
fix: `install-passwordless-switch.sh` (step 14).

### The Legion's screen stays black (no wallpaper) when coming from Game Mode

It is `xfdesktop`'s wallpaper. On the spot, `xfdesktop --reload` or switch workspace. `wallpaper-watcher`
does it by itself: see `~/.local/state/wallpaper-watcher.log` (step 15).

### The external monitor stays black at boot

Seen once. **Without touching the cable**, from the IdeaPad: `ssh lego` and, there,
`sudo sh "$B/legion/diag-monitor.sh"` (leaves `~/diag-monitor.log`; originally the script was copied first
with `scp "<disk>/Backups Linux/fish/void/legion/diag-monitor.sh" lego:` and run as `sudo sh ~/diag-monitor.sh`).
See *Pending*.

### Steam takes ~1 min to enter Game Mode

It is installing the other client: the desktop Steam was opened without `-steamdeck` (for example,
with `steam` from an xterm). Always open it from the menu or with its launcher (step 14, "Why
Steam took…").

### Steam does the full verification on start (`Verifying all executable checksums`)

It closed dirty once. It cleans itself on the next close: nothing to do. If it happens
always, check the three pieces of the clean shutdown: `ls -l /usr/local/bin/xfce4-session
/etc/runit/shutdown.d/05-close-steam.sh` and `steamos-session-select` (step 14).

### Steam sees two controllers, or a `Generic X-Box pad` / Xbox Elite

1. `Failed to hide device` warnings in `/var/log/inputplumber/current`: `acl-progs` or the
   `inputplumber-udevadm` wrapper are missing. Repeat `sudo bash "$B/legion/install-inputplumber.sh"` (step 14).
2. If an Xbox Elite shows up, the own profile is missing (`/etc/inputplumber/devices.d/50-legion_go_2.yaml`).
3. Afterwards, close Steam completely and open it again.

### The gyroscope moves nothing

1. On the desktop, **the thumb has to rest on the right trackpad** (like on the Deck).
2. `inputplumber device 0 capabilities | tr ',' '\n' | grep -iE 'gyro|accel'` has to give
   `Gamepad:Gyro` and `Gamepad:Accelerometer`. Otherwise, the profile carries `blocked: true` again in the
   `imu` sources: repeat the installer.
3. `sh "$B/legion/diag-gyro.sh"` (without root; or copied with `scp`): what reaches Steam when turning (hundreds to ~1500).

Steam's "Probar entradas del dispositivo" ("Test Device Inputs") **does not show the gyroscope**: it is no use for this.

### On the desktop, the trackpad or the right joystick do not move the pointer (but they select text)

`extest` is missing in the running Steam. Check `grep '^N:' /proc/bus/input/devices | grep extest`.
If it does not show: make sure Steam was started with the launcher or the autostart (both carry the `LD_PRELOAD`).
If a Steam update broke it, rebuild (step 14, "Controller on the desktop").
`void-update` warns if the library lacks something.

### The trackpad clicks by itself

The click activator went back to "Pulsación suave" ("Soft Press"). Change it to "Pulsación doble" ("Double Press"), or copy the
backed-up layout (step 14, "Controller on the desktop").

### After reinstalling or restarting InputPlumber, the session does not respond to the keyboard or the mouse

It is labwc (`libseat … Device not taken`). Reboot over SSH (`sudo reboot`, step 14).

### In Game Mode there is no "Rendimiento" (Performance) (TDP, GPU clock), or nothing changes

1. `sudo sv status steamos-manager` → `run`. If it crashes: `tracefs` (its `run` mounts it), and
   `sudo sh "$B/common/steam/steamos-manager/diag-steamos-manager.sh"` launches it in the foreground.
2. `dkms status` → `installed` for the running kernel. If the kernel is from another series, the modules
   do not exist: boot 6.18 (step 14, TDP).
3. `SetManualGpuClock … Invalid argument` / `Error setting manual GPU clock` in
   `/var/log/steamos-manager/current` **with "Reloj de GPU manual" ("Manual GPU Clock") disabled** (hundreds per session;
   harmless, the GPU stays at `auto`): it is the steamos-manager **without the** `set_clocks` **patch** (step
   14, steamos-manager). `sha256sum /usr/lib/steamos-manager` → `cc464424…1586c`; otherwise, repeat
   `install-steamos-manager.sh` (installs the `-2` tarball). **Do not** remove `[gpu_performance]`. If they show up **with the manual
   clock enabled**, or "Reloj de GPU manual" does not appear in Steam: `cat
   /sys/module/amdgpu/parameters/ppfeaturemask` → `0xfff7ffff` (otherwise, `sudo sh "$B/legion/gpu-overdrive.sh"` and
   reboot) and `grep -c '^\[gpu_performance\]' /usr/share/steamos-manager/devices/legion-go-series.toml`
   → `1` (otherwise, repeat `install-steamos-manager.sh`).

### `void-update` ends with AVISO (WARNING)

Each line says what to do (what each one checks: IdeaPad recipe, step 6, `void-update`). To
see it again without updating or `sudo`: **`void-update --summary`** (summary) (2026-10-08; since 2026-10-14 it fits half a terminal: one short line per check, the detail only under the warnings; `-v` for the detail of all). The Legion's ones:

- **TDP** that does not build for the new kernel (the error, in `/var/lib/dkms/lenovo-wmi-tdp/*/build/make.log`;
  the hidden GRUB boots that kernel without fine TDP: for the previous one, `grub-hidden.sh --remove`, step 8),
  kernel not held or new series recommended by Void: step 14, TDP, "Updates". gamescope's `cap_sys_nice`:
  `sudo setcap cap_sys_nice=eip /usr/bin/gamescope` (`void-update` puts it back by itself).
- **Patched gamescope or `xdg-desktop-portal-wlr`.** Already **before confirming** the update,
  `void-update` warns if the list replaces them ("Void reemplazará … parcheado (a → b)" / "Void will replace … patched (a → b)"): to keep them,
  answer `n` and `sudo xbps-pkgdb -m hold <package>` (without Void's fixes). In the summary, an
  AVISO (WARNING) if the installed one is already Void's (**without the patch**), if Void has **the same** version and revision
  as ours (xbps does not install it, but it is a newer Void build: rebuild to have its
  changes with the patch) or a **newer** one (the next update replaces it). Rebuild: gamescope →
  `bash "$B/common/steam/gamescope-patch/build-gamescope.sh"`, install and `setcap`
  (step 14, "Screen sharing in Game Mode"); wlroots portal → `bash "$B/legion/portal-wlr-patch/build-portal-wlr.sh"`, install and restart the portal (step 14,
  "Portals", point 4). If `~/src/void-packages` already exists, delete it first: the scripts do not update it.
  **Since 2026-10-09 each line also says the result of testing the patch** against Void's code
  (also `xfdesktop` and `Thunar`, step 15): "el parche sigue haciendo falta" ("the patch is still needed") (rebuild when due),
  "Void ya lo trae: se puede volver al de Void con …" ("Void already has it: you can go back to Void's with …") (NOTA (NOTE), with the exact command), "el parche no se puede
  usar tal cual" ("the patch cannot be used as is") (AVISO (WARNING): upstream rewrote that part, review the patch by hand) or "sin comprobar" ("not checked") (no
  network). Before confirming, the same. If the test is not installed: `bash "$B/common/patch-test/install-patch-test.sh"` (without root; IdeaPad recipe, step 6).
- **InputPlumber or gamescope's portal** missing some library (`ldd`): install it or bring another version
  and repeat `install-inputplumber.sh` / `install-portal-gamescope.sh` (step 14).
- **`steamos-manager`**: missing some library → rebuild (`build-steamos-manager.sh`, step 14,
  steamos-manager; its build dependencies are kept on purpose) and install; "NO es el de
  referencia" ("is NOT the reference one") → repeat `install-steamos-manager.sh`; "sin sha256 de referencia" ("no reference sha256") → repeat
  `install-steamos-manager.sh` (since 2026-10-08 it writes `/usr/local/share/steamos-manager-void/sha256`);
  "para recompilarlo falta" ("to rebuild it, missing") → the command it gives. The line starts with the **installed package** (file
  `package` of that folder, written by the installer; `paquete` on an older installation); it is not an AVISO by itself: "paquete desconocido" ("unknown package") =
  installed before 2026-10-08 (repeat the installer to register it); "el oficial, SIN el parche de
  set_clocks" ("the official one, WITHOUT the set_clocks patch") = `…-void` (valid option, to go back; with it the `Error setting manual GPU
  clock` come back, *Troubleshooting* point 3).
- **`extest`**: missing some library → rebuild (step 14, "Controller on the desktop"); "para recompilarlo
  falta" → whatever it says (`~/.cargo`, target `i686`, `~/src/extest`, `gcc-multilib`).

### Screen sharing on the desktop: nothing shows up, it asks twice or Vesktop does not respond

1. **When pressing share, the chooser does not show up:** `cat ~/.config/xdg-desktop-portal-wlr/config` (it must
   point to `screen-share`) and `tail ~/.cache/screen-share.log`. If the log has
   nothing new, Vesktop did not reach the portal. First, is there a chooser open? (`pgrep -af
   'screen-share$'`; the portal does not attend another request meanwhile): it should be seen in front because of
   the labwc rule (`grep -c screen-share ~/.config/xfce4/labwc/rc.xml` → 1). If there is none:
   **quit Vesktop from the tray and open it** (canceling in the chooser leaves it unable to share).
   Repeat `screen-share/install.sh`.
2. **It asks two (or three) times:** the portal does not have the variable: `tr '\0' '\n' <
   /proc/$(pgrep -n -f '^/usr/libexec/xdg-desktop-portal-wlr')/environ | grep XDPW` must give
   `XDPW_PERSIST_MODE=permanent` (the user's D-Bus service that `install.sh` sets). With windows,
   also, the patched portal: `xbps-query -p pkgver,repository xdg-desktop-portal-wlr` → `0.8.4_2` and
   `hostdir/binpkgs`. If everything is there and it goes on: reboot (the first time it was needed). To see what happens:
   the portal with `-l DEBUG` (step 14, "Portals", point 4): if the repeated request arrives without
   `restore data available`, it is a new stream for the portal.
3. **You choose a window and the Vesktop window does not appear** (or the previous stream continues): that
   window is not giving an image (it happened with Steam and with Thunar on another workspace): go see it for a moment
   and come back.
4. **The chooser shows up by itself when entering the desktop:** it is Steam; the rule `"steam":
   "pantalla"` must resolve it (in the log, `steam: regla 'pantalla'`). If it says another program, adjust `REGLAS`.

Detail in step 14, "Desktop portals and screen sharing".

### Screen sharing in Game Mode: black, or gamescope crashes and goes back to the desktop

1. **Black or no stream:** check that gamescope's portal is there: `grep "portal de gamescope"
   ~/.local/state/steam-game-mode.log` and `cat ~/.local/state/portal-gamescope.log` ("started"). If it
   crashed on entering, leave and come back to Game Mode (the main portal only looks for it on start). And
   Vesktop's launch options with `--env=XDG_SESSION_TYPE=wayland` (step 14).
2. **gamescope crashes** (back to Xfce; `Segmentation fault` in `steam-game-mode.log`, after `out of
   buffers`): is the patched gamescope still there? `xbps-query -p pkgver,repository gamescope` →
   `3.16.30_2` and `hostdir/binpkgs` (`void-update` warns). Otherwise, rebuild (`build-gamescope.sh`,
   install and `setcap`). If with the patch it crashes again: `diag-gamescope-pipewire.sh` (with `gdb` and
   `gamescope-dbg`) and look at the trace.
3. **Only Steam's menu is heard:** audio source "Todo el sistema" ("Entire system") in the stream's configuration
   window.

### Remote Play in Game Mode: the guest only sees the waiting screen

In `~/.local/share/Steam/logs/streaming_log.txt`: `Failed to create PipeWire main loop` → missing
`pipewire-32bit`; `Could not connect receiving stream` → missing `libspa-videoconvert-32bit`; `Capture
method set to Desktop Placeholder` continuously (not only with Steam's menu open) → one of
the two. Fine: `Desktop PipeWire NV12 DMABUF + VAAPI H264`. Step 14, "Remote Play in Game Mode".

### The screen's brightness changes when coming back from hibernation or suspend

See `/run/brightness-on-wake.log` and that `/etc/elogind/system-sleep/brightness` exists (step 14,
"Hibernation and brightness on wake").

### Steam's on-screen keyboard comes out huge or with a border

The `type="utility"` exception is missing in `~/.config/xfce4/labwc/rc.xml` (step 15).

### After closing Steam's on-screen keyboard, the trackpad and the sticks do not move the pointer

Seen on the desktop on 2026-10-09 (15:35 and 15:37, shortly after starting Steam); **intermittent**: in
two tests that day it did not reproduce. Cause seen in `~/.local/share/Steam/logs/controller_ui.txt`:
when opening the keyboard Steam records `Set OSK active 1` and switches the controller to the keyboard's action set
(`basicui_neptune.vdf`, where trackpad and sticks handle the keyboard); when closing it, it **did not record**
`Set OSK active 0` (it went back to the desktop layout, `413080`, 6 min later). `extest`,
InputPlumber and labwc, fine (the external mouse works; the `extest fake device` was still there). Why Steam
does not notice the close: **not found out**. Try recovering it by opening and closing the
keyboard again (RT+X). If it repeats, capture (read-only, event-driven, no idle cost):

```bash
cp "$B/legion/diag-steam-keyboard.sh" /tmp/ && bash /tmp/diag-steam-keyboard.sh
bash /tmp/diag-steam-keyboard.sh --stop       # results in /tmp/diag-steam-keyboard/
grep -E 'OSK active|OnFocusWindowChanged' /tmp/diag-steam-keyboard/controller_ui.txt
```

### Bluetooth headphones "connect" and drop (`br-connection-create-socket`)

They only keep the last pairing properly: pair them again here (steps 5–12).

### Steam's FPS limit gives half (30 → 15)

Without VRR, the screen modes that gamescope fabricates (everything that is not 144 Hz) lose one of every
two refreshes. Enable **"Habilitar VRR"** ("Enable VRR") in Rendimiento (Performance), or use limits that divide 144 (36, 48,
72). See step 14, "SteamOS settings".

### A game looks bad or runs worse since the SteamOS settings

The first suspect is gamescope's Vulkan layer (`ENABLE_GAMESCOPE_WSI=1`, Game
Mode). For that game, in its Steam launch options: `DISABLE_GAMESCOPE_WSI=1 %command%`
(it disables it only there). If it is the whole system: `sudo bash "$B/legion/like-steamos.sh" --remove` and
reboot (step 14, "SteamOS settings").

### The fallback kernel or the Windows on the XS1000 is needed

With the hidden GRUB there is no menu. The Windows on the XS1000 is chosen in the firmware's boot menu.
The fallback kernel: `sudo sh "$B/legion/grub-hidden.sh" --remove` (or, if it does not boot, from a live).
See step 8.

### The microSD games show as not installed

`findmnt /mnt/microsd`: if it is not mounted, is the card in? Mount it: `sudo mount
/mnt/microsd`, and close and open Steam. Check that Steam has it with that path: `grep '"path"'
~/.local/share/Steam/config/libraryfolders.vdf`; in `logs/content_log.txt`, `Mounted library
folder "/mnt/microsd"`. If it came out in another path, repeat `microsd-at-boot.sh` with Steam closed
(step 14, "microSD").

### In Xfce Wayland, choosing a wallpaper does nothing

The dialog writes to `monitorUnknown` and `xfdesktop` reads `monitor<connector>` (`eDP-1`, `DP-1`): step 15,
*Desktop wallpaper on Wayland*. Fix: the patched xfdesktop (or Void's, if `void-update` says it already has it). On the spot,
without root: `xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor<connector>/workspace0/last-image -n -t
string -s <image>` (without `-n -t string` if the key already exists).

### In Xfce Wayland, Thunar's "Establecer como fondo de pantalla" ("Set as wallpaper") does nothing

Thunar writes to `monitorUnknown` (step 15, *Wallpaper from Thunar on Wayland*). Fix: the patched
Thunar and `thunar -q`. If it stays the same: `xbps-query -p pkgver Thunar` (did an update replace it?
`void-update --summary`) and that no old Thunar is left open (`pgrep -a thunar`).

### `Common` does not mount (`wrong fs type…`, `volume is dirty`)

It was left dirty. The same as on the IdeaPad (its *Troubleshooting*): read it with
`udisksctl mount -b /dev/sda4 -o ro`; fix with the disk unmounted: `sudo ntfsfix -d /dev/sda4`,
and `chkdsk D: /f` in its Windows. Unmount it before rebooting, hibernating or booting that Windows.

### Known noise in the logs (harmless)

Reviewed on 2026-10-08; everything **is left as is** on purpose (decided with the user). Message → cause →
why it is not touched.

- **`SetWifiBackend … Wi-Fi backend not found in config`** (`/var/log/steamos-manager/current`, every time
  Steam starts) → steamos-manager looks for `wifi.backend=` in
  `/etc/NetworkManager/conf.d/99-valve-wifi-backend.conf`, which does not exist here, and Steam asks it for iwd
  (`Set wifi force wpa supplicant: 0`). **Do not create that file to silence it:** steamos-manager would see
  that it does not match what Steam asks, it would try to switch to iwd (here there is no iwd: it runs with
  `wpa_supplicant`) and after rebooting the Wi-Fi would not work. The error is what protects the network. The
  warnings from `org.freedesktop.systemd1`, the same: there is no systemd here.
- **`task … panicked with message "all branches are disabled and there is no else branch"`**
  (steamos-manager, when powering off or rebooting) → it falls in the same second as InputPlumber's `SIGTERM`:
  steamos-manager loses its connection with it when shutting down. It only happens at shutdown; if InputPlumber
  restarted with the session open, runit brings steamos-manager up by itself.
- **`Can't query initial InputPlumber devices: … ServiceUnknown`** (steamos-manager, on start) →
  it starts before InputPlumber is on D-Bus; the controller works anyway (`deck-uhid`). Waiting for it
  event-driven in the `run` would be one more own piece to remove a warning.
- **SteamOS pieces that are not here** (Steam's logs): `steamos-select-branch: not found`,
  `timedatectl: not found` (`console-linux.txt`), `telemetry`, `atomupd proxy`,
  `steamos-mandatory-update` / `jupiter-initial-firmware-update` (127), `invalid screen reader locale:
  auto` (`steamui_steamos.txt`), and `xfce4-notifyd` "cannot open display" when entering Game Mode
  (Steam uses its own notifications). Empty substitutes would be own pieces with nothing gained.
  **`invalid profile: balanced`** and `SteamOSManager: daemon not present` show **only on the desktop**:
  the steamos-manager user process is only started by the Game Mode launcher, on purpose (on
  the desktop Steam does not touch profile or TDP).
- **`ld.so: object '…/libextest.so' from LD_PRELOAD cannot be preloaded (wrong ELF class: ELFCLASS32)`**
  (`~/.xsession-errors`) → `extest`'s library is 32-bit and the 64-bit processes also try to load it
  (step 14, "Controller on the desktop"). It costs nothing.
- **`[libseat] … Could not close device: Unknown object '/org/freedesktop/login1/session/cN'`** and
  `Failed to close device` (labwc in `~/.xsession-errors.old`, and gamescope, when closing the session) → the
  elogind session no longer exists when the compositor releases its devices; the kernel frees them when
  the process exits. Do not confuse with `Device not taken` when restarting InputPlumber (above).
- **`[MANGOHUD] … Unknown option 'nis_steam_sharpness'`** (`steam-game-mode.log`, once per entry
  into Game Mode) → Void's `mangoapp` 0.8.4 does not know that option (it does know `fsr_steam_sharpness`). The only
  thing lost is that the overlay shows NIS sharpness. It fixes itself when Void updates MangoHud.
- **Steam's adaptive brightness** (`== …: brightness N (amdgpu_bl0)` in `steam-game-mode.log`: about 170 in
  the first minute and then ~5/min; in `console_log.txt`, `steamos-priv-write failed
  …/brightness` and `failed to make file writeable`) → Steam first tries SteamOS's helper
  (`/usr/bin/steamos-polkit-helpers/steamos-priv-write`, which does not exist here) and `chmod`, and then `echo N |
  sudo -n tee`, which Game Mode's `sudo` turns into elogind's `SetBrightness` (step 14). It costs very
  little.
- **`xfce4-pulseaudio-plugin-WARNING … pa_context_connect() failed: Access denied`** (once or twice when
  the desktop session starts) → race with `pipewire-pulse`, which is not ready yet; the plugin
  retries every 5 s and connects. The same on the IdeaPad.
- **WirePlumber: `optional component 'support.logind' … failed to load`** and `skipping component
  'monitor.bluez.seat-monitoring'` (every session) → `wireplumber-elogind` is missing; the component is optional
  and Bluetooth works. **Do not install `wireplumber-elogind`:** it would make WirePlumber release
  Bluetooth when the seat is not active, and with lightdm's session switches (Game Mode ↔
  desktop) it could cut the headphones. The same on the IdeaPad.

## Verification

```bash
uname -r                                   # 6.18.x
sudo sv status sshd avahi-daemon bluetoothd   # all three in "run"
rfkill                                     # bluetooth unblocked
setxkbmap -query                           # us / intl (in the X11 session; on Wayland Xwayland says it: ~/.config/xfce4/labwc/environment rules)
xrandr --listactivemonitors                # X11: eDP and, with the monitor, DisplayPort-0; Wayland (through Xwayland): eDP-1 / DP-1
pgrep -af new-windows                  # the watcher, only in the X11 session (on Wayland it exits right away: labwc does it)
ssh ideapad hostname                       # ideapad-100
iw dev wlp193s0 get power_save             # Power save: off
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey   # s "ignore" (power-button)
pgrep -af power-button                     # one, with --mode game or --mode desktop; log ~/.local/state/power-button.log
sudo sv status decky                       # run (Decky Loader)
xbps-query -p pkgver hidapi                # hidapi-0.14.0_1 (Decky's Colores plugin, step 14)
cat ~/.local/state/wallpaper-watcher.log     # in Xfce Wayland: "watching 2 screens" and, after a change, "xfdesktop --reload"
xbps-query -p pkgver xfdesktop             # xfdesktop-4.20.2_2 (patched, step 15: wallpaper on Wayland) or Void's if void-update says it already has it
ls ~/.local/bin/patch-still-needed ~/.local/share/void-update/patches   # patch test: Thunar gamescope steamos-manager xdg-desktop-portal-wlr xfdesktop
void-update --version; ls ~/.config/autostart/void-update-tray.desktop; pgrep -af void-update-tray   # void-update 1.0.0 · the icon running
void-update --list | tail -3                 # the pending updates (rootless), or "System is up to date" ("El sistema está al día")
xbps-query -p pkgver Thunar                # Thunar-4.20.10_2 (patched, step 15: wallpaper from Thunar on Wayland)
grep -E "mode:|cursor:" ~/.local/state/steam-game-mode.log | tail -2   # direct screen (DRM) / volantes_cursors
sudo sv status inputplumber steamos-manager udev-net   # all three in "run"
ls /sys/bus/hid/devices/ | grep 28DE       # 0003:28DE:12FB… (InputPlumber's Valve controller)
grep -c 'Failed to hide' /var/log/inputplumber/current   # does not grow when restarting the service (18, all from 2026-10-04, before the fix)
dkms status                                # lenovo-wmi-tdp/6.18.55 …: installed
ls /sys/class/firmware-attributes/lenovo-wmi-other-0/attributes   # ppt_pl1_spl ppt_pl2_sppt ppt_pl3_fppt
cat /sys/module/amdgpu/parameters/ppfeaturemask   # 0xfff7ffff (overdrive, step 14)
grep -c '^\[gpu_performance\]' /usr/share/steamos-manager/devices/legion-go-series.toml; cat /sys/class/drm/card*/device/power_dpm_force_performance_level   # 1 · auto (manual only with the manual clock enabled in Steam)
sha256sum /usr/lib/steamos-manager         # cc464424414289025056eaa2ee38976aa36b6d3dc662340ebd427e4600d1586c (with the set_clocks patch)
sha256sum -c /usr/local/share/steamos-manager-void/sha256   # /usr/lib/steamos-manager: OK · /usr/bin/steamosctl: OK (the installer's reference)
cat /usr/local/share/steamos-manager-void/paquete           # steamos-manager-v26.4.1-void-2 (written by the installer; void-update --summary shows it)
xbps-query -m | grep -c '^speech-dispatcher-[0-9]'   # 1 (marked manual: steamos-manager's libspeechd; without the [0-9] it would also count speech-dispatcher-devel)
xbps-query -m | grep -cE '^(glib-devel|eudev-libudev-devel|speech-dispatcher-devel|clang|pkg-config)-[0-9]'   # 5 (steamos-manager's build dependencies, kept on purpose)
bluetoothctl show | grep Alias             # Alias: Legion-Go-Gen-2 (step 5–12)
for d in /mnt/home /mnt/steamos-home; do test -e $d && echo "!! $d sigue"; done   # nothing (the live's folders, deleted; step 0) ("sigue" = "still there")
cat /var/log/udev-net/current              # empty or "… not processed by udev: repeating the announcement" if it had to act
ls -l /usr/local/bin/xfce4-session /etc/runit/shutdown.d/05-close-steam.sh   # clean shutdown of Steam
grep -c -e 'sv once' -e 'steam -shutdown' /usr/local/bin/switch-mode-root   # 4 (no race; closes Steam)
ls -l /var/service/mode-switch; ls /etc/sv/mode-switch   # → /etc/sv/mode-switch · down run
ls /run/user/1000 | grep -c wayland-0       # 2 in Xfce Wayland (if missing: race with elogind, step 14)
grep -c 'type="utility"' ~/.config/xfce4/labwc/rc.xml   # 1 (Steam's keyboard, step 15)
grep -c 'identifier="screen-share"' ~/.config/xfce4/labwc/rc.xml   # 1 (chooser always on top, step 15)
grep -c xwaylandPersistence ~/.config/xfce4/labwc/rc.xml   # 1 (Xwayland always alive, step 15)
grep -c '<raiseOnFocus>no' ~/.config/xfce4/labwc/rc.xml; xfconf-query -c xfwm4 -p /general/raise_on_focus   # 1 and false (raise on click, step 15)
grep chooser_cmd ~/.config/xdg-desktop-portal-wlr/config; command -v grim fuzzel   # screen-share chooser (step 14, Portals)
grep -c XDPW_PERSIST_MODE ~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service   # 2: comment + Exec (no second question)
grep '^RULES' ~/.local/bin/screen-share   # {"steam": "screen"}
xbps-query -p pkgver,repository xdg-desktop-portal-wlr   # 0.8.4_2 … hostdir/binpkgs (window patch; step 14)
xbps-query -p pkgver,repository gamescope   # 3.16.30_2 … hostdir/binpkgs (with the patch; step 14)
ls /usr/local/lib/xdg-desktop-portal-gamescope*   # gamescope's portal and its wrapper (step 14)
grep Exec /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.gamescope.service   # …-gamescope-void (the wrapper)
getcap /usr/bin/gamescope                  # cap_sys_nice=eip
for p in pipewire-32bit libspa-videoconvert-32bit mesa-vaapi-32bit mesa-vaapi; do xbps-query -p pkgver $p; done   # the four versions: Remote Play in Game Mode (step 14)
grep "Capture method set" ~/.local/share/Steam/logs/streaming_log.txt | grep -v Placeholder | tail -1   # after a stream: Desktop PipeWire NV12 DMABUF + VAAPI H264 (Placeholder = Steam's menu or end)
ls ~/.config/wireplumber/wireplumber.conf.d/; wpctl settings | grep -A5 'Id: node.restore-default-targets' | grep Value   # 51-audio-priority.conf · Value: false [Saved: false] (point K.12)
ls ~/.config/autostart/steam-background.desktop && pgrep -af 'steam.*-silent'   # Steam in the background
grep -E "Shutdown|Verifying" ~/.local/share/Steam/logs/bootstrap_log.txt | tail -3   # "file sizes only"
grep '^N:' /proc/bus/input/devices | grep extest   # extest fake device (with Steam on the desktop)
inputplumber device 0 capabilities | tr ',' '\n' | grep -iE 'gyro|accel'   # Gamepad:Gyro and Gamepad:Accelerometer
sh "$B/legion/diag-gyro.sh"   # turning the console: rotation from hundreds to ~1500 (to Steam)
cat /run/switch-mode.log                  # after a mode switch: how long it waited for elogind
ls -l /etc/elogind/system-sleep/brightness     # brightness hook; after sleeping: cat /run/brightness-on-wake.log
xbps-query -H                              # linux-6.18_1 and linux-headers-6.18_1 (held)
findmnt /mnt/microsd                       # /dev/mmcblk0p1 ext4 rw,noatime (microSD, mounted at boot)
sysctl kernel.split_lock_mitigate net.core.default_qdisc   # 0 / fq_codel (SteamOS settings)
cat /sys/kernel/mm/transparent_hugepage/enabled   # [always]
ps -eLo cls,rtprio,comm | grep data-loop   # RR 20 (real-time audio, rtkit)
test -e /var/service/rtkit && echo "!! /var/service/rtkit existe"; pgrep -x rtkit-daemon | xargs -r -I{} ps -o ppid= -p {} | xargs -r ps -o args= -p   # only "runit" (D-Bus started it), never "runsv rtkit" ("existe" = "exists")
grep -o preempt=full /proc/cmdline; ulimit -l   # preempt=full · 8192
grep -c ENABLE_GAMESCOPE_WSI /usr/local/bin/steam-game-mode   # 1
grep -a 'mode: direct screen' ~/.local/state/steam-game-mode.log | tail -1   # …; refresh rates 48,144
DISPLAY=:0 xprop -root GAMESCOPE_VRR_ENABLED   # = 1 in Game Mode with "Habilitar VRR" ("Enable VRR") (exact FPS limit)
```

> **In this repository:** `install/verify.sh` runs the commands of this block that need no root and
> prints each one with its expected value next to it; the `sudo` ones are listed for the user to run.

And an `void-update`: its final summary must say "✓ Todo en orden" ("✓ All in order").

Verified on 2026-10-03: kernel 6.18.55, avahi announcing `Legion-Go-Gen-2.local`, `ssh lego` and
`ssh ideapad` by name, keyboard `us`/`intl`, session with Orchis, Papirus-Dark teal, Volantes,
JetBrainsMono NFM Blocks, fastfetch with the Legion's real data (screenshot reviewed) and the
per-monitor window shortcuts. **On 2026-10-04**, after rebooting: Wi-Fi as `wlp193s0` with
`Power save: off`, InputPlumber without warnings when hiding and a single controller in Steam, overdrive active and
the two `steamos-manager` processes.

### Verified (what was in *Pending*)

- **Game Mode: Windows game verified** (2026-10-04): **Borderlands 3** (appid 397540) with
  **Proton 9.0-2RC** (Steam chose it: `compat_log.txt` → `Mapping AppID 397540 to tool
  "proton-9.0-2RC"`) and **without launch options** (without the `PROTON_USE_WINED3D=1` that
  the IdeaPad needs: here the GPU works for DXVK), with the body's gyroscope working.
  **Xfce Wayland:** both screens, fine since 2026-10-04 (`wallpaper-watcher`); the
  "Modo Juego" (Game Mode) launcher from the desktop, verified by the user on 2026-10-04.
- **InputPlumber** (step 14): the buttons work in Game Mode (2026-10-04); the gyroscope
  in a game was missing (the sensor's raw values do not match its declared scale: check that
  the rotation goes at the right speed) → **body's gyroscope solved on the desktop on
  2026-10-04** (unblocking + ×100 scale, see step 14); correct axes and **it works in
  games** (Borderlands 3, 2026-10-04) (`diag-gyro.sh` to see what Steam receives). **Detached controllers: they work** (verified by the user on
  2026-10-04; the Legion still sees them as `17ef:61eb` "Legion Controller" and InputPlumber the same).
- **Suspend** (`s2idle`) **verified on 2026-10-04** from Game Mode (power button
  to wake): `/sys/power/suspend_stats` → `success=1`, `fail=0`, `last_hw_sleep` ≈ 6 s
  (real hardware sleep); on wake, Wi-Fi connected with `Power save: off`, whole controller and
  InputPlumber fine. **Long suspend** on 2026-10-04: several hours, **plugged in and charging**,
  without incidents according to the user (the statistics of `/sys/power/suspend_stats` are lost on
  reboot: no record was left).
- **Hibernation: verified on 2026-10-04** (see "Hibernation", step 14). Nothing pending.
- **Battery drain in suspend, unplugged: measured on 2026-10-05.** Suspended from Game
  Mode at 22:14 with 54 %, woken at 22:44 with 53 % (`BAT0/capacity`), unplugged
  (`status: Discharging`). `/sys/power/suspend_stats`: `success` 1, `fail` 0, **`last_hw_sleep`
  1794764923 µs = 29.9 min of real hardware sleep** (`s2idle`; without half wakeups).
  **≈ 2 % per hour ≈ 1.5 W** with the 78.3 Wh battery (`energy_full` 78310000; factory 74 Wh):
  suspended it lasts about two days. `capacity` goes in integers (1 % = between almost 0 and almost 2 %): for an
  exact figure, compare `energy_now` (µWh) before and after.
- **953 GB microSD (ext4)**: from the SteamOS days (Steam library?). Not mounted or
  touched; decide what to do with it. → **Solved on 2026-10-05:** it was SteamOS's Steam library;
  always mounted at boot on `/mnt/microsd` (step 14, "microSD"), verified.
- **GPU always on auto** (step 14, steamos-manager): verified on 2026-10-08 after rebooting
  (00:48): level `auto`, factory `ppfeaturemask` (`0xfff7bfff`), no new `manual GPU clock` in
  `/var/log/steamos-manager/current` after Game Mode (183, the last at 00:42, before the change),
  and TDP and Performance profiles working in Steam (checked by the user). **Undone the
  same day:** the manual clock and the overdrive were brought back (step 14, steamos-manager).

## Pending

**To test:** nothing (2026-10-08). The manual GPU clock brought back and the `set_clocks` patch
were verified that day (step 14, steamos-manager, and *Verified*, above).
The Game Mode items (game sound, Vesktop shortcut, gamescope
patch with settings changes and Borderlands 3) were verified and decided (step 14, "Screen
sharing in Game Mode").

**Decided** (studied and left as is on purpose)

- **InputPlumber's consumption: LEFT AS IS** (the user's decision, 2026-10-08). ~3.2–3.5 % of one core
  and ~7100–7200 wakeups/s, fixed in Game Mode, on the desktop and moving the controller; mostly
  from reading the body's IMUs by opening and closing their sysfs files ~389 times/s and from the virtual
  Valve controller (`/dev/uhid`). Lowering the IMUs' frequency to 100 over D-Bus would save more or less
  half at the cost of gyroscope samples (and without knowing if the sensor accepts it, nor persisting): not
  worth it. Detail and measurements in step 14, InputPlumber. The ~10 % average since boot
  is still unexplained: if wanted, repeat `diag-inputplumber-cpu.sh` when higher usage is noticed.
- **steamos-manager's build dependencies: KEPT** (the user's decision, 2026-10-08:
  "no me es prioritario borrar dependencias de compilación si se requieren para el mantenimiento tras
  actualizaciones" — "deleting build dependencies is not a priority for me if they are needed for maintenance after
  updates"). `glib-devel`, `eudev-libudev-devel`, `speech-dispatcher-devel`, `clang` and
  `pkg-config` (34 packages with their dependencies, ≈ 470 MB; `void-update` updates them too) are
  used by `build-steamos-manager.sh`; gamescope and the wlroots portal are not (`xbps-src` brings its own in
  its environment), nor `extest` (Rust and `gcc-multilib`). How to remove them if one day wanted: step 14,
  steamos-manager, "How it is built".
- **Noise in the logs: LEFT AS IS** (2026-10-08): one line per warning, with the cause, in
  Troubleshooting, *Known noise in the logs (harmless)*.
- **Gyroscope of each detached controller: LEFT AS IS, on purpose** (the user's decision,
  2026-10-05, after the tests below: it would require patching and building InputPlumber). Today, detached, the rotation comes only from the tablet (step 14,
  InputPlumber). What was known before testing it: the **gyroscope of each controller**, which without `hid_lenovo_go` (Valve's patch) is not
  activated (its udev rule sets `imu_bypass_enable`, `os_mode` and the touchpad vibration).
  **They do have a gyroscope** (checked in InputPlumber v0.81's source, 2026-10-05): the report
  of the Go 2's controller (`src/drivers/lego/hid_report.rs`, `XInputDataReport`, 60 bytes) carries
  accelerometer and gyroscope **of each controller** (`left_accel_*`/`left_gyro_*`, bytes 35–46;
  `right_*`, 48–59), and `hid-lenovo-go` has `left_handle/` and `right_handle/imu_bypass_enable`.
  **InputPlumber discards them** without `hid-lenovo-go` (`src/drivers/lego/mod.rs`:
  `DEFAULT_EVENT_FILTER` filters the six: center, left and right); with it, it lets through only the
  "center" (the average of the two controllers). Its own comment says that turning the IMU on in the
  kernel driver "is broken for now" (it talks about the Go 1). That is: the hardware is there, but not even
  with Valve's kernel is it clear it would work.
  **Diagnosis of 2026-10-05** (`sudo sh "$B/legion/diag-controller-gyros.sh"`, in `legion/`; it only
  reads the controller's three `hidraw` interfaces and keeps saying what to do: still → turn the left one →
  the right one → the tablet; output saved in `logs/legion-diagnostics-2026-10-04/diag-giroscopio-mandos-2026-10-05.log`).
  Through interface 2 arrives the XInput report (`04 3c 74…`; `read` gives 64 bytes, the report is the first
  60), ~175 per second:
  - **The full IMU of each controller is OFF:** bytes 35–59 (3-axis accelerometer and gyroscope
    of each controller) are at zero and do not change when turning. The power-on command that
    `hid-lenovo-go` sends (`imu_bypass_enable`) is needed.
  - **But each controller does send a low-resolution rotation** that InputPlumber does not use
    (`left_gyro_lq_x/y` = bytes 30–31, `right_gyro_lq_x/y` = 32–33; `u8`, center `0x80`): when turning the
    left one 30 and 31 changed (up to ±255), when turning the right one 32 and 33; with the tablet, nothing.
    They are 2 axes per controller and 8-bit.
  - Everything else that changed came from touching the sticks or the touchpad: byte 14 (left stick), 16–17 (right
    stick), 27–29 (touchpad) and interface 1 (touchpad messages, 20 bytes).
  **Paths:** (a) send the IMU power-on command through `hidraw`, like `hid-lenovo-go` (the protocol has to be
  taken from its source; it writes to the controller); (b) use the low-resolution bytes, which
  requires changing InputPlumber's code. Neither done.
  **Power-on, tested on 2026-10-05** (`sudo sh "$B/legion/test-controller-imu.sh" [--keep]`, in
  `legion/`; output in `logs/legion-diagnostics-2026-10-04/probar-imu-mando-2026-10-05.log`). The command
  comes from `drivers/hid/hid-lenovo-go.c`, **which is already in the official kernel** (git.kernel.org; Valve's
  kernel is not needed to read it): 64-byte output report `0x05` through interface 2
  (the one of endpoint `0x83`, here `hidraw1`), `05 00 03 <setting> <controller>` to read and `05 00 04 <setting>
  <controller> <value>` to change; setting `05` = IMU on, `03` = IMU bypass; controller `03` = left,
  `04` = right; value `01` = yes, `02` = no; the controller answers `04 00 …` with the value.
  - **From the factory:** both controllers with "IMU on: yes" and "bypass: no".
  - "IMU on" alone changes nothing (bytes 48–59 at zero). **With "bypass: yes" the full IMU of the
    right one shows in the report** (when turning it, variations from 400 to 6600 in bytes 48–59) and the
    controller starts sending about 125 reports per second instead of ~42.
  - The script set it back to "bypass: no" (checked by reading the setting).
  **Having Steam listen to the right controller instead of the tablet: tested on 2026-10-05, it does NOT work like this**
  (`right-controller-gyro.sh`, in `legion/`; `--undo`). The idea, without rebuilding: "bypass:
  yes" on the right one and, over D-Bus, the writable property `FilteredEvents` of `CompositeDevice0`
  (let through `Gyroscope:Right`/`Accelerometer:Right` from the controller and discard the `:Center` ones of the
  tablet's `iio` sources). The right one would work attached and detached: a single source. What happened:
  - **InputPlumber 0.81 does not apply the whole filter:** in the log, `Failed to set filtered events:
    failed to send command to device`. `set_filtered_events` (`src/input/composite_device/mod.rs`)
    sends the filter to **all** the sources one by one and stops at the first that does not answer
    (here it always fails; with 9 sources, among them the blocked `evdev` ones); those that come before in the
    loop do receive it. Result: the tablet was discarded and **the controller was not unblocked: Steam
    was left without a gyroscope**. It was repeated as is with `busctl` from SSH: same error.
  - **Detaching or attaching the controllers reconnects the controller over USB** with another identifier (`17ef:61eb` →
    `61ed`, and one more interface: endpoint `0x83` moved to `hidraw2`): InputPlumber redoes its sources
    and the controller's filter goes back to the factory one. Any fix would have to be reapplied on every
    reconnection.
  - **Fix on the spot:** the tablet's gyroscope, allowed again through `busctl` (it went in
    because it comes before in the loop); its accelerometer stayed discarded until rebooting (the
    gyroscope as mouse does not use it). **Rebooting leaves InputPlumber as from the factory.**
  **Conclusion:** without touching InputPlumber it cannot be done. Its code would have to change (so that without
  `hid-lenovo-go` it lets the right controller's gyroscope through, and the tablet's `iio` sources
  do not arrive, or choose it through the profile) and be built (Rust is already on the Legion), plus a service that
  sets "bypass: yes" when the controller connects. Not done.

**Wallpaper on Wayland (2026-10-09): xfdesktop and Thunar patched, installed** (step 15) and verified that
day on the Legion's screen: the dialog and "Establecer como fondo de pantalla" ("Set as wallpaper") write `monitoreDP-1` and
the wallpaper changes; `void-update --summary` → 14 × OK. On the external monitor, too (`monitorDP-1`, each
screen with its wallpaper). Remaining limit: the dialog takes the screen when it opens (close it and open it on the
other one); Thunar follows its window. **Done.**

**Before, to do:** nothing (2026-10-08). **Done that day** by the user: registering the name of the package of
the already installed steamos-manager, without reinstalling (`echo steamos-manager-v26.4.1-void-2 | sudo tee
/usr/local/share/steamos-manager-void/paquete`; the installer records it by itself since that day): `void-update
--resumen` gives 12 × OK with `steamos-manager, paquete steamos-manager-v26.4.1-void-2`; `sudo xbps-pkgdb -m manual
speech-dispatcher` (checked: `xbps-query -m` lists `speech-dispatcher-0.12.1_1`) and the empty
folders of the live `/mnt/home` and `/mnt/steamos-home` no longer exist (in `/mnt` only `microsd` remains; the
`rmdir` that time said "No existe" ("Does not exist"): they had already been deleted, `/mnt` modified at 22:33).
`strace` (3.3 MB; installed by the InputPlumber measurement, step 14): removed (checked over SSH on
2026-10-08: `xbps-query strace` does not find it). The Flatpak portals,
the previous item, are installed and verified (step 14, "Discord (Vesktop)", *Desktop portals and
screen sharing*).

**Watch** (nothing to do unless it happens; what to do, in *Troubleshooting*)

- **Black monitor at boot with it connected** (seen once, 2026-10-04): gamescope chose `DP-1`
  at 1920×1080@60 without errors, but no image came out (and the fans sped up) until
  disconnecting and connecting the cable; with the same mode, then it did. After a while it stopped happening with no
  known change. If it comes back: without touching the cable, from the IdeaPad `ssh lego` and `sudo sh "$B/legion/diag-monitor.sh"` (originally copied first with `scp`)
  (in `legion/`; leaves `~/diag-monitor.log` with connectors, GPU, processes and `dmesg`).
- **`udev-net`** (steps 2–3): **it already acted twice** — `/var/log/udev-net/current`: `2026-10-05_02:36:46
  wlan0 sin procesar por udev: se repite el aviso` ("wlan0 not processed by udev: repeating the announcement") (20:36:46 local time on 2026-10-04) and
  `2026-10-08_03:47:11` (21:47:11 local time on 2026-10-07; the log goes in UTC): the Wi-Fi fell again
  into udev's gap in those boots and came out as `wlp193s0` without it being noticed. Keep
  looking from time to time. On the IdeaPad also installed (2026-10-04).
- **`rtkit` in a loop (found on 2026-10-07; solved and verified after rebooting on 2026-10-08):** in this boot D-Bus started
  `rtkit-daemon` before runit (its parent is init, not `runsv rtkit`); runit's exits with code 1
  because the D-Bus name is already taken and runit relaunches it every second (`sudo sv status rtkit` →
  `down: 1s, normally up, want up`, five times in a row). Real-time audio works (the
  D-Bus one provides it). On the IdeaPad runit's won the race, but it could happen just the same. **Done (2026-10-08, approved
  by the user):** `like-steamos.sh` no longer links `rtkit` in runit (and if it finds the link, it stops it and
  removes it) and on both machines it is removed with `sudo sh /tmp/quitar-rtkit-runit.sh` (`sv -w 5 down rtkit` and deletes
  `/var/service/rtkit`; it does not kill D-Bus's `rtkit-daemon`). Now only D-Bus starts it on demand.
  **Verified after rebooting on 2026-10-08** (boots at 00:11 and 00:48; on the IdeaPad, at
  00:14 and 00:41), with the lines of *Verification*: no `/var/service/rtkit`, a single
  `rtkit-daemon` with parent `runit` (D-Bus started it; never `runsv rtkit`) and the four `data-loop`
  of PipeWire and WirePlumber in RR 20. If it came back, it is detected by
  `common/agent/audit-void.sh`.
- **gamescope patch**: if `Segmentation fault` shows up again in `~/.local/state/steam-game-mode.log`
  when streaming, repeat the diagnosis (`legion/diag-gamescope-pipewire.sh`, step 14); and after
  a Void update, `void-update` warns if it has to be rebuilt.
- **`extest`**: if a Steam update breaks it, rebuild (step 14); Rust and `gcc-multilib` are
  kept for that (see *Cleanup*).
  `void-update` warns if `extest`, InputPlumber or `steamos-manager` lack a library.

**Cleanup** (2026-10-05, the user's decision: everything except what may be needed later)

- **Done:** deleted the stray `.bak` (`~/.config/autostart/steam-background.desktop.bak`,
  `~/.local/share/applications/steam.desktop.bak`, `~/.local/bin/window-snap.bak`,
  `~/.local/bin/window-focus.bak`, `~/.config/xfce4/labwc/rc.xml.bak`, `~/.Xresources.bak`) and the
  diagnostic outputs of `~` (`diag-edp-bien.txt`, `diag-edp-negra.txt`, `dmesg-arranque.txt`,
  `diag-steamos-manager.log`), **copied first** to `logs/legion-diagnostics-2026-10-04/`
  (identical, checked with `md5sum`). `~/xfce-wayland/labwc/rc.xml` brought up to date from Common
  (equal to the installed one). `~/.bashrc.bak` is made by the recipe (step 5–12): it stays.
- **Also done** (root, by the user, 2026-10-05): the rest of Plymouth, `sudo rm -r /etc/plymouth`
  (step 8); checked that it no longer exists.
- **Kept on purpose**, in case they are needed: **Rust** (`~/.rustup`, `~/.cargo`, ~770 MB),
  **`~/src/extest`** (78 MB) and **`gcc-multilib`**, to rebuild `extest` if a Steam update
  breaks it (step 14, "Controller on the desktop"); **`drm_info`** and **`wlr-randr`** (step 15)
  and the `diag-*.sh` scripts in `~`, to diagnose screens and the gyroscope.
  → **Changed the same day** (second cleanup, below): the diagnosing things, only in Common.
- **Second cleanup, "final product"** (the user's decision, 2026-10-05: the scripts and all the
  diagnostics, only in Common). First it was checked that **the 63 pieces** of `~` (the `*.sh`,
  `inputplumber-udevadm`, `inputplumber-x86_64.tar.gz` and the folders `steam/`, `tdp/`,
  `xfce-wayland/`) had an **identical** copy in Common (`cmp`, file by file: `legion/`,
  `legion/tdp/`, `legion/steam/installed-packages.txt`, `steam/`, `xfce-wayland/`) and that **nothing of what
  runs uses them** (no reference from `/etc`, `/usr/local`, the services, `~/.config`,
  `~/.local`). The 8 logs (`pasos-1-a-3.log`, `escritorio-1-root.log`, `escritorio-2-root.log`,
  `grub-root.log`, `como-steamos.log`, `giro-mando-derecho.log`, `probar-imu-mando.log`,
  `diag-giroscopio-mandos.log`) were archived in **`fish/void/logs/legion/`** (`md5sum`
  identical) and the 7 `.bak` of `/etc` (`fstab`, `rc.conf`, `avahi-daemon.conf`, `default/grub`,
  `grub.d/10_linux`, `lightdm.conf`, `lightdm-gtk-greeter.conf`: the configuration before each
  change, partly from the factory) in **`logs/legion/etc-bak/`**. Deleted from `~`: the 29 files and
  the 3 folders. **Also done (root, by the user; checked on 2026-10-06):** deleting those `.bak`
  of `/etc` (none is left) and the diagnostic tools (they are reinstalled if needed, step 15):

  ```bash
  sudo rm -f /etc/fstab.bak /etc/rc.conf.bak /etc/avahi/avahi-daemon.conf.bak /etc/default/grub.bak \
      /etc/grub.d/10_linux.bak /etc/lightdm/lightdm.conf.bak /etc/lightdm/lightdm-gtk-greeter.conf.bak
  sudo xbps-remove drm_info wlr-randr
  ```

  Kept, on purpose: `~/src/extest`, `~/.rustup`, `~/.cargo` and `gcc-multilib` (to build `extest`),
  `~/.bashrc.bak` (from the recipe), `/etc/modules-load.d/dm-raid.conf.desactivado` (step 8: it is the
  fix, not a leftover), `~/Projects` (empty, the user's) and the services' logs in
  `/var/log/` and `~/.local/state/`. To diagnose or undo: *Troubleshooting* (scripts from Common).
  **Stray launch option in Borderlands 3:** `VRR_CAPABLE = 1` (from the tests; without
  `%command%`, Steam passes it to the game as arguments): deleted by the user (checked on
  2026-10-06: no game has launch options).

**Optional** (it is not cleanup; it can be done or not)

- **A/B test of the gyroscope's ×100** (step 14, InputPlumber, point 4): with the risk of locking up the
  session when reinstalling InputPlumber.

## History

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
