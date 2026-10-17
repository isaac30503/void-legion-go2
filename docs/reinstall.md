# Reinstall

The whole system from an empty disk, in the order it has to be done. The documentation is organized by layers
(platform → base system → hardware → sessions → desktop → Game Mode → apps → maintenance); **this page is the order of
execution**, which follows the layers except where a piece needs one from a higher layer (noted on each stage). Each
stage links to the page that explains it, and ends with its check.

`install/install.sh` runs these same stages (`--list`, `--from N`, `--only N`, `--dry-run`): the scripted ones
automatically, the manual ones shown and waited for, stopping at every reboot. **The blocks are bash:** the terminal
opens fish, so type `bash` first. **Every block assumes `B` set as in stage 2** (`B="$REPO/build"`).

## 1. Install Void — [installation](1-platform/2-installation.md)

From the live ISO with `sudo void-installer` (the table and the two traps on that page). Then let the IdeaPad in over
SSH and remove the live's empty `/mnt` folders.

## 2. The repository

```bash
sudo xbps-install -S git github-cli age
gh auth login                                    # to read the private repository (local.env.age, Claude's context)
REPO=~/src/void-legion-go2
gh repo clone isaac30503/void-legion-go2 "$REPO"
bash "$REPO/install/fetch-assets.sh"             # Release binaries, sha256 checked
bash "$REPO/install/secrets.sh" open             # local.env from its encrypted copy (the passphrase)
bash "$REPO/install/render.sh"                   # build/
B="$REPO/build"
```

Without the private repository (another owner): `cp "$REPO/local.env.example" "$REPO/local.env"`, fill it in
([sanitization](sanitization.md)), then `render.sh`.

## 3. System — [system](2-base-system/1-system.md)

```bash
sudo bash "$B/legion/steps-1-to-3.sh"      # ends with "DONE OK"
sudo reboot
```

Check: `uname -r` 6.18.x; `pgrep -a avahi-daemon`.

## 4. Network — [network and SSH](2-base-system/2-network.md)

```bash
sudo sh "$B/legion/avahi-wifi-only.sh"
sudo sh "$B/legion/wifi-no-powersave.sh"
sudo sh "$B/legion/udev-net.sh"
```

## 5. SSH both ways — [network and SSH](2-base-system/2-network.md)

On the IdeaPad: `ssh-keygen -R legion-go-gen-2.local`. On the Legion, the key, `~/.ssh/config` and `ssh-find` (that
page's block), and the new `id_ed25519.pub` into the IdeaPad's `authorized_keys`. Check: `ssh ideapad hostname`.

## 6–8. Desktop — [Xfce](5-desktop/1-xfce.md), [look and feel](5-desktop/2-look-and-feel.md)

```bash
sudo bash "$B/legion/desktop-1-root.sh"      # packages, Bluetooth
# the user part: the block of the Xfce page
sudo bash "$B/legion/desktop-2-root.sh"      # the login screen
```

## 9. Xfce's configuration, with the session closed — [Xfce](5-desktop/1-xfce.md)

From the login screen's console (Ctrl+Alt+F2) or SSH: that page's block 3. Then log back in.

## 10. Claude Code — [Claude Code](8-maintenance/3-claude-code.md)

That page's block, and log in on the Legion itself.

## 11. Boot — [boot](1-platform/3-boot.md)

**After the login screen** (stage 8: the GRUB theme uses its copy of the font), with the XS1000 connected:

```bash
sudo bash "$B/legion/grub-root.sh"
sudo sh "$B/legion/grub-hidden.sh"
sudo xbps-pkgdb -m hold linux linux-headers
sudo sh "$B/common/boot/install-plymouth.sh"     # Void B, and Steam B while Steam loads
udisksctl unmount -b /dev/sda4
sudo reboot
```

## 12–14. Steam, Game Mode and the sessions — [Steam](6-game-mode/1-steam.md), [Game Mode](6-game-mode/2-game-mode.md), [login and modes](4-sessions/1-login-and-modes.md)

```bash
sudo sh "$B/common/steam/install-steam.sh"
```

Log out and back in; the desktop launcher with `-steamdeck` and `extest` ([Steam](6-game-mode/1-steam.md)); open Steam
**from the menu**, let it update, log in, close it. Then — the session pieces need Game Mode installed, and Xfce on
Wayland must exist before the reboot (it is where "Switch to Desktop" goes):

```bash
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen
sudo sh "$B/common/power-button/install-power-button.sh"
sudo sh "$B/common/steam/test-direct-session.sh"
sudo sh "$B/common/steam/install-passwordless-switch.sh"
sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"
sudo reboot                                   # straight into Game Mode
```

## 15. Hardware and SteamOS parity — [controllers](3-hardware-support/1-controllers.md), [power](3-hardware-support/2-power.md), [steamos-manager](6-game-mode/3-steamos-manager.md), [system](2-base-system/1-system.md), [systemd-compat](2-base-system/4-systemd-compat.md)

```bash
sudo bash "$B/legion/install-inputplumber.sh"
sudo bash "$B/legion/tdp/install-tdp.sh"
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"
sudo xbps-pkgdb -m manual speech-dispatcher
sudo sh "$B/legion/gpu-overdrive.sh"
sudo sh "$B/legion/brightness-on-wake.sh"
sudo bash "$B/legion/like-steamos.sh"         # after Steam: it needs the multilib repository (gamescope-32bit)
sudo sh "$B/common/systemd-compat/install-systemd-compat.sh"   # after InputPlumber: systemctl for Decky plugins
sudo reboot
```

## 16. microSD — [storage](2-base-system/3-storage.md)

With Steam closed: `sudo sh "$B/legion/microsd-at-boot.sh"`; then, in Steam, add `/mnt/microsd` as a library.

## 17. By hand, in Steam and on the desktop

1. Steam's settings: developer mode → Wi-Fi power management off, keyboard, VRR ([Steam](6-game-mode/1-steam.md)).
2. xterm as a game, with the "Web Browser" controller template ([Steam](6-game-mode/1-steam.md#xterm-as-a-game)), and its art ([library art](6-game-mode/6-library-art.md)).
3. Decky and its plugins, with `hidapi` ([Decky](6-game-mode/5-decky.md)); then `void-update --systemd` and, once reviewed, `--ack` ([systemd-compat](2-base-system/4-systemd-compat.md)).
4. The controller on the desktop: Steam in the background and the desktop layout ([controller on the desktop](6-game-mode/8-controller-on-desktop.md)).
5. Firefox: "Title Bar" unchecked; as a game with `firefox-steam` ([Firefox](7-apps/3-firefox.md)).
6. Bluetooth: name and pairings ([audio and Bluetooth](3-hardware-support/3-audio-bluetooth.md)).
7. Vesktop, the portals and screen sharing, on the desktop and in Game Mode ([Vesktop](7-apps/2-vesktop.md),
   [screen sharing](7-apps/1-screen-sharing.md)).
8. The audio devices' order ([audio and Bluetooth](3-hardware-support/3-audio-bluetooth.md)).

## 18. Check

The **Check** of each page, `void-update` (its summary must end with "✓ Todo en orden" / "All in order"), and
`void-update --tray --enable` (the panel icon; [void-update](8-maintenance/1-void-update.md)).

## 19. Clean up

The installers leave their logs in `~` (`~/<script>.log`): archive them in the private repository (check them for
private values first) and delete them:

```bash
P="$REPO-private"; D="$P/archive/logs-$(date +%F)"
mkdir -p "$D" && cp ~/*.log "$D/" && git -C "$P" add -A && git -C "$P" commit -qm "logs of the reinstall" && git -C "$P" push -q
rm -f -- ~/*.log
```

What stays on purpose: `~/src/extest`, `~/.rustup`, `~/.cargo` and `gcc-multilib` (to rebuild `extest`),
steamos-manager's build dependencies, and `~/.bashrc.bak`.
