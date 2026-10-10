# Void Linux (Xfce) on the Lenovo IdeaPad 100 — configuration recipe (steps 1–15)

> **About this file (this repository).** English version of the IdeaPad's recipe, `void-ideapad-100.md`
> (external disk, `Backups Linux/`), **only what the Legion's recipe uses**: the introduction, the full list,
> steps 1 to 15 and *Troubleshooting*. Not included: step 16 (`ideapad-al-dia.sh`, the IdeaPad's own
> hardware), the *Comprobación final* (final check) and *Pendientes* (pending); they are in the original.
> **This is the IdeaPad's recipe and the IdeaPad still runs the original pieces**, so the names of scripts,
> commands, services and paths are kept **as they are on the IdeaPad** (in Spanish: `instalar-modo-juego.sh`,
> `cambiar-modo-root`, `fish/void/…`); `<disco>` = `<disk>` = `/run/media/isaac/Common`. To apply a step on
> the Legion with this repository, use the Legion's recipe (`docs/void-legion-go2.md`), which gives the
> commands with the repository's names; the equivalence old → new is [`../glossary.md`](../glossary.md).
> Labels of menus and windows are quoted in Spanish (as they appear) with the English one in parentheses.
> Private values are written `@NAME@` ([`../sanitization.md`](../sanitization.md)).

> Written on 2026-09-30. It replaces `fedora-atomic-ideapad-100.md` (Fedora COSMIC Atomic),
> which stays on the disk as a reference: much of what it explains is still valid
> (hardware, Windows on the XS1000, boot rules). This machine is still the
> **debugging station** of the home network. When below **"the console's recipe"** is cited (its
> §13, §15…), it is the Legion's **with SteamOS**, `Handheld/new/steamos-nativo-legion-go2.md` (reference);
> today's Legion, with Void, is `void-legion-go2.md`.

**Founding rule:** Void is a **normal, not atomic** distribution: `/usr` and `/etc` are
writable and are updated package by package with `xbps`. There is no image that replaces anything
nor layers that force a reboot, so **here software is installed with `xbps`**, the
system's, and not with Homebrew. It is the opposite of the Legion with SteamOS and of the previous Fedora, and that is why
their `install-pkg`, `update-system` and `config.fish` are not reused (the Legion with Void uses the ones from here).

Two differences that change how it is administered:

- **The init is runit, not systemd.** A service is enabled by linking it:
  `sudo ln -s /etc/sv/<service> /var/service/`. It is queried with `sudo sv status <service>`
  (without root it fails with "access denied") and restarted with `sudo sv restart <service>`.
- **Rolling release:** there are no system versions, only packages up to date or not.

Desktop: **Xfce**, chosen out of pragmatism. Since 2026-10-03 the normal desktop is **Xfce on
Wayland (labwc, step 15)**; Xfce on X11 (xfwm4, steps 9–13) stays as a backup, and both
share the same Xfce configuration. Besides, Game Mode like SteamOS (step 14).

## Starting point

Official ISO **xfce, glibc, x86_64** (the 2025 one, with kernel 6.12.11), installed clean on
2026-09-30 with `void-installer`:

| Setting | Value |
|---|---|
| Hostname | `ideapad-100` |
| User | `isaac`, full name "@USER_FULL_NAME@", in `wheel` (with sudo); the installer also adds `audio`, `video`, `kvm`, `floppy`, `cdrom`, `optical`, `users`, `xbuilder` |
| Internal disk (`sda`, mechanical WD) | `sda1` EFI 500M · `sda2` swap 16G · `sda3` `/` btrfs |
| Language / zone / keyboard | `es_MX.UTF-8` · `America/Mexico_City` · `KEYMAP=es` (now `la-latin1`: step 2) |
| Mirror | `https://mirrors.summithq.com/voidlinux/current` (in `/etc/xbps.d/00-repository-main.conf`) |
| Network during the installation | the installer's (cable or Wi-Fi); on the installed system it is configured again (step 1) |

In `void-installer` (as root in the ISO's session: `sudo void-installer`):
- *Keyboard*: **`la-latin1`** (that way step 2 only has to set the X one).
- *Source*: **Local** (copies the ISO's system, with Xfce and lightdm; *Network* installs only
  `base-system`, without a desktop).
- *Hostname* `ideapad-100`, *Locale* `es_MX.UTF-8`, *Timezone* `America/Mexico_City`, *User*
  as in the table (and root's password).
- *Bootloader*: on **`/dev/sda`** (GRUB in the EFI partition).
- *Partition*/*Filesystems*: `sda1` 500M **vfat** on `/boot/efi`, `sda2` 16G **swap**,
  `sda3` the rest **btrfs** on `/` (no subvolumes; `/home` is a folder).
- If it asks for the mirror and summithq does not show up, it does not matter: it is set in step 1.

`/home` **is not a separate mount point**: it is a folder inside the btrfs of `/`. It matters
for fastfetch (step 12).

Services that the ISO leaves active: `NetworkManager`, `lightdm`, `dbus`, `polkitd`,
`chronyd`, `udevd`, the `agetty` ones and **`sshd`**, which on Void does come enabled by default (on
Fedora it does not).

## Reinstall: the order, at a glance

With the external disk connected and `Common` mounted (`<disco>` is `/run/media/isaac/Common`).
**The order matters:** first the base system, then everything that is installed, and at the end the
Xfce configuration, which depends on what is installed.

| Step | What | How |
|---|---|---|
| 1 | Update xbps and then everything (**reboot**) | `xbps-install -Syu xbps` → `xbps-install -Syu` |
| 2 | Latin American keyboard (session, login screen and console) | `00-keyboard.conf` + `KEYMAP=la-latin1` |
| 3 | SSH + mDNS + the Legion's key | `openssh avahi nss-mdns` + `ln -s` in `/var/service` |
| 4 | Access from the other machines, own key and **Wi-Fi with iwd** | `Host ideapad`; `ssh-keygen`; `iwd` + `wifi.backend=iwd`; `wifi-reparar` (installs `wifi-vigilante`); `udev-red` |
| 5 | fish and the jump from bash | `fish-shell` + `~/.bashrc.d/` |
| 6 | fish functions | `install-pkg`, `remove-pkg`, `update-system` (xbps), prompt, greeting, `disk-ops`, `ssh-setup` |
| 7 | Claude Code and its context | official installer + log in + `CLAUDE.md` + its memory |
| 8 | Boot: Windows on the XS1000, without messages and GRUB theme (**without Plymouth since 2026-10-05**) | `instalar-arranque-void.sh`; `arranque-silencioso.sh` (before, `instalar-plymouth.sh` applied it, no longer used); `instalar-tema.sh` (after step 10) |
| 9 | Desktop software and themes | packages, Bluetooth, fonts, Papirus (teal folders), Orchis, Volantes |
| 10 | Login screen the same as the session | copies to the system + `lightdm-gtk-greeter.conf` + its `gtk.css` |
| 11 | xterm as the default terminal | `.Xresources` + icon + `helpers.rc` + `.xprofile` |
| 12 | fastfetch | `gen-config.py` |
| 13 | Xfce configuration (**with the session closed**) | restore xfconf, panel and `gtk.css` |
| 14 | Steam and its Game Mode like SteamOS (optional) | `instalar-steam.sh` → `instalar-modo-juego.sh --sin-pantalla-de-carga` → `probar-sesion-directa.sh` → `instalar-cambio-sin-contrasena.sh` (+ `xterm-steam`, `instalar-decky.sh`, `steam.desktop` with `-steamdeck`) → `como-steamos.sh` (from `fish/void/legion/`; or all of 2026-10-05 with `ideapad-como-legion.sh`) |
| 15 | Xfce on Wayland (labwc), **the normal desktop**: **before the reboot of 14** (otherwise, "Cambiar a escritorio" ("Switch to Desktop") would go to a session without labwc) | `instalar-cambio-sin-contrasena.sh` (`escritorio` = Wayland) → `instalar-xfce-wayland.sh` (brings `fondo-vigilante` and the exception for Steam's keyboard) |
| 16 | Bringing this hardware up to date (2026-10-09): microcode, hardware video, zswap, BFQ + `noatime`, `compress=zstd:1` (**reboot**) | `ideapad-al-dia.sh --todo` |
| — | Final check | see at the end |

### Full list, in order (also what is done by hand)

The same as the table, from start to finish, with what is not a command. In each step, **its blocks of
commands in the order in which they appear**, except what is said here. **The blocks are bash:** the
terminal opens fish, so first type `bash` (in fish, `X="…"` gives an error). `Common` is mounted from
the graphical session (Thunar or `udisksctl mount -b /dev/sdb4`): over SSH it is not possible.

1. **Installation:** `sudo void-installer` in the ISO, with the table of *Starting point* (keyboard
   `la-latin1`, *Source* **Local**).
2. **Step 1:** network from the panel's icon (or cable), mirror, `xbps` and then everything, **reboot**;
   delete the `.new-*` of `/etc`.
3. **Step 2:** the `cp` of `00-keyboard.conf`. The `sed` of the `KEYMAP` only if `grep KEYMAP /etc/rc.conf`
   does not already say `la-latin1`.
4. **Step 3:** SSH, avahi and the Legion's key.
5. **Step 4:** on the Legion, `ssh-keygen -R ideapad-100.local`. Here, own key and
   `ssh-config-ideapad`; add `~/.ssh/id_ed25519.pub` to the `authorized_keys` of `isaac` on the Legion and,
   if used, `ssh-copy-id deck`. Then the Wi-Fi with iwd (**with the cable plugged in**: the Wi-Fi drops),
   `wifi-reparar` (installs `wifi-vigilante`) and `udev-red.sh`. `rtl8723be.conf` takes effect after the next
   reboot.
6. **Steps 5 and 6:** fish with the jump from bash; functions (also `ntfs-3g`, `disk-ops` and `ssh-setup`).
7. **Step 7:** Claude Code, `CLAUDE.md`, its memory and the `mantenedor-void` agent; log in with
   `claude` on the machine itself.
8. **Step 8:** `instalar-arranque-void.sh` and `arranque-silencioso.sh`. **Not** `instalar-plymouth.sh`
   (without Plymouth since 2026-10-05). The GRUB theme goes in point 10.
9. **Step 9:** packages; Bluetooth (service, `bluetooth-al-arrancar.sh`, `bluetoothctl system-alias
   ideapad-100`); fonts; `papirus-folders`; Orchis **from the copy** (`orchis-themes.tar.gz`, not the
   `git clone`); Volantes. Headphones and the Xbox controller: pair them whenever wanted (step 9,
   *Pairing*).
10. **Step 10:** copies to the system, `lightdm-gtk-greeter.conf` and `lightdm`'s `gtk.css`. Then the
    GRUB theme (`instalar-tema.sh`, step 8): its painted entries must match the menu.
    Unmount `Common` and **reboot**.
11. **Step 11:** xterm and default terminal; **Firefox → Ajustes → General → Hacer predeterminado** (Settings → General → Make Default).
12. **Step 12:** fastfetch.
13. **Step 13, with the session closed:** at the login screen, Ctrl+Alt+F2, restore Xfce and the
    window scripts, and go back with Ctrl+Alt+F7 to log in ("Xfce Session").
14. **Steps 14 and 15:** the block of *Installation order* of step 14, whole and in that order (Steam,
    its launcher with `-steamdeck`, Game Mode, autologin, **Xfce Wayland before rebooting**,
    SteamOS settings). Then, already in Xfce Wayland, the **patched xfdesktop** (step 15, *Desktop
    wallpaper on Wayland*: `instalar-xfdesktop-fondo.sh`, unless `compilar-xfdesktop.sh` says that Void already brings it) and
    the **patched Thunar** (step 15, *Wallpaper from Thunar on Wayland*: `instalar-thunar-fondo.sh` and
    `thunar -q`).
    Then, by hand:
    - in Game Mode, *Configuración → Teclado* (*Settings → Keyboard*) → **Español (Latinoamérica)** (Spanish (Latin America));
    - in Firefox, **check** that "Barra de título" ("Title Bar") is **unchecked** (☰ → Más herramientas →
      Personalizar barra de herramientas… / More tools → Customize toolbar…; labwc gives it only the border, step 15). With a new profile
      it already comes like that (it is Firefox 157's default); it only has to be unchecked if it shows up checked;
    - xterm as a game (`xterm-steam`, step 14). **Not Decky** (removed from the IdeaPad on 2026-10-09;
      the Legion keeps it);
    - in each Windows game (Proton): launch options `PROTON_USE_WINED3D=1 %command%` (the
      HD 5500 is no good for DXVK).
    Optional, not done here: xterm art (`arte-xterm/generar.py`) and `firefox-steam`.
15. **Step 16** (after 14, with `Common` mounted): `sudo bash "<disco>/Backups
    Linux/fish/void/ideapad-al-dia.sh" --todo`; unmount `Common` and **reboot** (the new
    microcode is loaded at boot). It leaves `/etc/fstab` with `defaults,noatime,compress=zstd:1` on `/` (the
    ISO sets `defaults`), the zswap block in `/etc/rc.local` and the BFQ rule (internal disks only) in
    `/etc/udev/rules.d/`. No steps by hand.
16. **Final check** and an `update-system`: its summary must end in "✓ Todo en orden" ("✓ All in order").
    **Unmount `Common`** before rebooting or powering off.

## Procedure (in this order)

### 1. Update the system (before installing anything)

**First, network.** In the Xfce session, network icon of the panel → `@WIFI_SSID@` → password
(still with wpa_supplicant, the default backend; step 4 switches it to iwd and reuses this
same profile). Or with a cable. Check: `ping -c 3 voidlinux.org`.

**Mirror** (if it is not this one already; `xbps-query -L` says which one is used):

```bash
echo 'repository=https://mirrors.summithq.com/voidlinux/current' | sudo tee /etc/xbps.d/00-repository-main.conf
xbps-query -L      # summithq must come out
```

```bash
sudo xbps-install -Syu xbps     # first xbps, alone
sudo xbps-install -Syu          # then everything
sudo reboot
```

**With an old ISO, xbps installs nothing until it updates itself.** Any
`xbps-install` fails with `The 'xbps' package must be updated, please run xbps-install -u xbps`
and **installs none of the requested packages**. If that goes in a line with more commands,
the following ones fail afterwards (an `ln -s` to a service that does not exist, for example).

**It takes long.** On 2026-09-30 it was **454 packages and about 1.4 GB**, about 45 minutes of download.
It is not the mirror's fault: measured from this machine, summithq gave ~1.8 MB/s in a single
download and was the fastest of those tried (`repo-fastly` ~1.4 MB/s, `repo-default` did not
answer). The average drops because xbps downloads the packages one by one. To see the
progress from another machine: `du -sh /var/cache/xbps`, and the total with
`xbps-install -un | awk '{s+=$6} END {print s/1048576" MiB"}'`.

**When it finishes, `sshd` cuts all connections** (`kex_exchange_identification: Connection
reset by peer`) if the update brought a new OpenSSH: the `sshd` still running
is the old one and no longer finds its pieces. `sudo sv restart sshd`, or this step's reboot.

After the reboot the new kernel boots (6.18.54 on 2026-09-30). The ISO's can be
deleted: `vkpurge list` and `sudo vkpurge rm <version>`. The other 6.12 that the
update installed is left as a backup.

**The `.new-*` files of `/etc` are not applied.** When a configuration file has
local changes, xbps leaves yours and puts the package's template next to it. After the first
update four showed up, and **in all of them the good one is the current one**:
`default/libc-locales.new-*` (without the enabled locales), `rc.conf.new-*` (without `KEYMAP`),
`issue.new-*` (the same) and **`passwd.new-*`, which has neither `isaac` nor the service
users: putting it in place of the good one would leave the machine without a user.** They can be deleted:
`sudo rm /etc/*.new-* /etc/default/*.new-*`.

### 2. Latin American keyboard (`latam`)

The physical keyboard is **Latin American Spanish**. The graphical session was in **`us`** (nobody
set it: neither Xfce, empty `keyboard-layout` channel, nor Xorg, without `/etc/X11/xorg.conf.d/`) and the
console in `es` (Spain). Set for the whole system (session, login screen and console):

```bash
sudo mkdir -p /etc/X11/xorg.conf.d
sudo cp "<disco>/Backups Linux/fish/void/xfce/00-keyboard.conf" /etc/X11/xorg.conf.d/
sudo cp /etc/rc.conf /etc/rc.conf.bak
sudo sed -i 's/^KEYMAP=es$/KEYMAP=la-latin1/' /etc/rc.conf
```

`00-keyboard.conf` is an `InputClass` with `Option "XkbLayout" "latam"`. It is applied when X
starts (reboot); for the current session `setxkbmap latam` is enough. Check with
`setxkbmap -query`. **Verified on 2026-10-02** after rebooting, in the session and at the login
screen.

In a reinstall, already choose `la-latin1` as the keyboard in `void-installer`; the X file
has to be put the same way. **The Super+Shift+number shortcuts (step 13) depend on this
layout.**

### 3. Incoming SSH and mDNS

```bash
sudo xbps-install -Sy openssh avahi nss-mdns
sudo ln -sf /etc/sv/dbus /var/service/
sudo ln -sf /etc/sv/sshd /var/service/
sudo ln -sf /etc/sv/avahi-daemon /var/service/
sudo sv status sshd avahi-daemon        # both in "run"
```

`openssh` and `sshd` already come; the line is just in case. **What is missing is avahi:** without it,
the name `ideapad-100.local` does not exist on the network. At boot, avahi announces
`ideapad-100.local` (it shows in `pgrep -a avahi-daemon`).

Void **brings no firewall**: there is nothing to open.

The Legion's key, without `ssh-copy-id` (it does not ask for a password over SSH nor is it needed). **Since
2026-10-03 it is `isaac@Legion-Go-Gen-2`** (the Legion with Void; its recipe, step 4):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBVbW7/3r9bCbqJSvpYy0pwclkm3nbOKAf1X8UaD7dk isaac@Legion-Go-Gen-2' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Before (until 2026-10-03, the Legion with SteamOS) it was `deck@Legion-Go-Gen-2`
(`…AAAAILuySBDCFVX5oOuUdQ6HUsz+LDBdNHH36G3C+skXcif6`): **do not put it**, its private key went away with SteamOS
and it was removed from here that day. Check: `cut -d' ' -f3 ~/.ssh/authorized_keys` → only
`isaac@Legion-Go-Gen-2`.

Void does not use SELinux: here Fedora's `restorecon` is not needed.

### 4. Access from the other machines

In the `~/.ssh/config` of the machine that connects:

```
Host ideapad
    HostName ideapad-100.local
    User isaac
    IdentityFile ~/.ssh/id_ed25519
```

And delete the previous host key, or ssh refuses to connect after a reinstall:
`ssh-keygen -R ideapad-100.local` (and `-R fedora-ideapad-100.local`, the Fedora's name).

With Void, NetworkManager uses the **real MAC** (`@IDEAPAD_WIFI_MAC@`), not a random one as on
Fedora. The IP should change less, but the access still goes by name.

#### Own key and access back to the Legion

The access is **in both directions**, as with Fedora: the machine with problems may be
precisely the one one would use to diagnose.

```bash
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 -C "isaac@ideapad-100"
cp "<disco>/Backups Linux/fish/void/ssh-config-ideapad" ~/.ssh/config
chmod 600 ~/.ssh/config
```

**`fish/void/ssh-config-ideapad`** (exact copy of the `~/.ssh/config` of here, 2026-10-06): `lego` →
`isaac@Legion-Go-Gen-2.local` (the Legion with Void, since 2026-10-03), `msi` → `isaac@192.168.0.115`
and `deck` → `deck@steamdeck.local` (the Steam Deck, since 2026-10-05; on the Deck: `passwd` and `sudo
systemctl enable --now sshd`, and here `ssh-copy-id deck`). Then, on the Legion, add the public key of
here to `~/.ssh/authorized_keys` of **`isaac`**.

Before (until 2026-10-03) it was `fedora-atomic/ssh-config-ejemplo`, which **is no longer valid**: `lego` →
`deck@Legion-Go-Gen-2.local` (SteamOS). What it said then: `lego` → `deck@Legion-Go-Gen-2.local` and `msi` →
`isaac@192.168.0.115` (the MSI's `sshd` is still disabled). Afterwards, **on the Legion**,
add the public key (`~/.ssh/id_ed25519.pub` of here) to `~/.ssh/authorized_keys` of `deck`
(`700` the folder, `600` the file) and **remove the one of the previous installation**
(`isaac@fedora-ideapad-100`): its private key was lost when reinstalling.

**Done on 2026-10-01:** key `isaac@ideapad-100`, authorized on the Legion (the Fedora one
removed; copy in `deck`'s `~/.ssh/authorized_keys.bak`). **Since 2026-10-03** (Legion with Void)
it is in the Legion's `~isaac/.ssh/authorized_keys`; and since 2026-10-05 also on the Steam Deck. `ssh lego` gets in without
a password. The Legion's host key was registered by itself on the first access
(`StrictHostKeyChecking=accept-new`).

#### Wi-Fi: NetworkManager with iwd (not wpa_supplicant), or SSH stutters

**Since 2026-10-02 NetworkManager's Wi-Fi backend is iwd**, as on the Legion **with SteamOS**
(the Legion with Void, since 2026-10-03, goes with wpa_supplicant: its recipe, steps 2–3). This is how
it was switched (with the Ethernet connected: the Wi-Fi drops). Both files are backed up in
`fish/void/red/`:

```bash
sudo xbps-install -Sy iwd
sudo mkdir -p /etc/iwd
sudo cp "<disco>/Backups Linux/fish/void/red/iwd-main.conf" /etc/iwd/main.conf
sudo cp "<disco>/Backups Linux/fish/void/red/wifi-backend.conf" /etc/NetworkManager/conf.d/
sudo cp "<disco>/Backups Linux/fish/void/red/rtl8723be.conf" /etc/modprobe.d/   # applied on reboot
sudo nmcli c modify @WIFI_SSID@ 802-11-wireless.bssid ""   # if it came pinned (see below)
sudo sv down NetworkManager; sudo pkill -x wpa_supplicant
sudo ln -s /etc/sv/iwd /var/service/
sleep 5; sudo sv up NetworkManager
iwctl station wlp3s0 connect @WIFI_SSID@                   # once: asks for the password
```

| File | Content | Why |
|---|---|---|
| `/etc/NetworkManager/conf.d/wifi-backend.conf` | `[device]` `wifi.backend=iwd` | NetworkManager talks to iwd; the IP and the DNS are still set by NetworkManager |
| `/etc/iwd/main.conf` | `[DriverQuirks]` `DefaultInterface=*` | without this iwd deletes `wlp3s0` and creates `wlan0` |
| | `[Scan]` `DisableMacAddressRandomization=true` | scan with the real MAC. **It is not essential** (see below); it is left because it costs nothing |
| `/etc/modprobe.d/rtl8723be.conf` | `options rtl8723be fwlps=0 ips=0` | **essential**: it turns off the chip firmware's power saving; with it the reception gets stuck or hangs (see *Stalls and hangs*). Applied on reboot; check with `cat /sys/module/rtl8723be/parameters/fwlps` → `N` |

**Correction (2026-10-02, afternoon):** at first it was believed that the random MAC left iwd
without seeing networks with this chip. **It was false:** without the setting, and disconnected (which is when iwd
uses the random MAC), iwd saw 15–18 networks in three scans in a row. What really happens is
that **iwd, every now and then, stops seeing any network** (it happened on the first attempt and on a
boot) **and it is fixed by restarting it**; the script that added the setting also restarted
iwd, and the fix was attributed to the setting. There is a published case like this with the RTL8723BE
(empty scans until iwd is restarted). The mitigation is **`wifi-vigilante`** (below).
`DisableMacAddressRandomization` is not in Void's manual (`man iwd.config`), but it exists
in the iwd 3.12 binary. wpa_supplicant is still installed (required by
`base-system` and NetworkManager) but no longer starts: D-Bus launched it at
NetworkManager's request. iwd uses ~5.6 MB of memory; wpa_supplicant, 11.5 MB.

**The one-time connection with `iwctl`** saves the password in `/var/lib/iwd/` (root); from
there iwd connects by itself and NetworkManager adopts the connection with its `@WIFI_SSID@` profile (the
usual one, there was no need to create another). **Without that step it failed:** `nmcli c up @WIFI_SSID@` gave
"falló la activación: No se ha dado ninguna razón" ("activation failed: No reason given") without touching the card (in
NetworkManager's code that is phase 1: it does not find a compatible network in its list). With iwd already
knowing the network and NetworkManager started after iwd, it works: `nmcli c down`/`up`
takes 3 s. **Verified on 2026-10-02 with a reboot without cable:** it connects by itself, with IP, DNS and
internet access, and wpa_supplicant does not run. (On NixOS there is an open bug of a race when
starting both, `nixpkgs#551427`; here with runit it did not show up.)

Things that change:
- **The Wi-Fi is no longer controlled with `nmcli … bssid`.** Real state of the connection (node,
  signal): `iwctl station wlp3s0 show` (without root). `nmcli dev wifi list` shows real BSSID and channel
  only of the node in use; the others come out with made-up BSSIDs (`00:01:02:…`) and channel 2,
  because iwd passes NetworkManager networks, not access points. It is cosmetic.
- **iwd switches node by itself:** when the signal drops below −70 dBm (forced below −80) or
  **when the mesh asks it to** (802.11v), with a scan directed at the channels that the
  mesh indicates, not at all 13.
- iwd with NetworkManager is "experimental" according to NetworkManager's manual. SteamOS uses it
  by default.

**`wifi-reparar` and `wifi-vigilante`: install them now, in this step.** `wifi-reparar` goes in
`~/.local/bin` (backed up in `fish/void/red/`) and **it is the one that installs and enables the service
`wifi-vigilante`** (it carries it inside), so it has to be run once:

```bash
mkdir -p ~/.local/bin
cp "<disco>/Backups Linux/fish/void/red/wifi-reparar" ~/.local/bin/ && chmod +x ~/.local/bin/wifi-reparar
~/.local/bin/wifi-reparar          # asks for sudo by itself; must end in "Todo bien" ("All fine")
ls /var/service | grep wifi-vigilante   # wifi-vigilante
```

(With the full path: `~/.local/bin` is not yet in fish's `PATH` until step 6.)

**`udev-red`** (2026-10-04, found on the Legion; **installed here on 2026-10-04**): Void can
lose the udev event of a network interface at boot (gap between the stage-1 udev and the
`udevd` service of stage 2): the interface stays as `wlan0`, without the usual name, and
NetworkManager leaves it **"unmanaged"** ("link is not initialized by udev"). Neither iwd nor
`wifi-vigilante` fix it. The `udev-red` service repeats it to udev on every boot (detail
in the Legion's recipe, steps 2–3):

```bash
sudo sh "<disco>/Backups Linux/fish/void/legion/udev-red.sh"   # --quitar undoes it
ls /var/service | grep udev-red          # udev-red
cat /var/log/udev-red/current            # empty unless it had to act
```

By hand, if it happens without it: `sudo udevadm trigger --action=add --subsystem-match=net`.
**If something breaks: `wifi-reparar`** again. It asks for `sudo` by itself, checks 20 things and fixes
what it finds:

| Detects | Fixes |
|---|---|
| `main.conf` or `wifi-backend.conf` changed or deleted (e.g. by an update) | rewrites them (leaves `.bak`) |
| iwd not installed, service not enabled or stopped (also runit's "want down") | installs / enables / restarts |
| wpa_supplicant running, BSSID pinned, rfkill by software | stops it / unpins it / unblocks it |
| iwd does not see the network, or NetworkManager out of sync with iwd | **ordered restart**: NetworkManager down, iwd, and NetworkManager once iwd already has the card |
| iwd forgot the password | copies it from NetworkManager's profile to `/var/lib/iwd/` (without showing it) |
| `wifi-vigilante` not installed, disabled or of another version | (re)installs it from its internal copy and enables it |
| `/etc/modprobe.d/rtl8723be.conf` missing | puts it back and warns that it applies on reboot |
| iwd **cannot connect** with any of the above | **automatic plan B**: wpa_supplicant with the BSSID pinned to the **strongest node at that moment**. If iwd connects but the network goes badly (stall), it retries ~30 s, does an ordered restart and **stays on iwd** |

At the end it checks IP, router, DNS and that there are no continuous scans. `--diagnostico` (diagnosis) only looks
(without `sudo`); `--plan-b` forces plan B; running it again without options goes back to iwd;
`--forzar` (force) restarts in order even if everything is fine. Log of each run:
`~/.local/state/wifi-reparar.log`. **Tested on 2026-10-02** by breaking it on purpose: iwd
stopped, password deleted from iwd, and plan B with the return to iwd; all three times it stayed connected.
And on a real boot without Wi-Fi (iwd not seeing networks) it fixed it when run by hand.

**`wifi-vigilante` ("Wi-Fi watcher"): the automatic fix of the intermittent failure.** runit service
(`/etc/sv/wifi-vigilante/run`) that **`wifi-reparar` installs** (it carries the script inside; if it gets
lost or changes, `wifi-reparar` puts it back). It starts with the system and leaves a 25 s margin before
acting. **Since 2026-10-03 it is event-driven:** it sleeps until something happens, with three sources of
events in a pipe (`/run/wifi-vigilante.avisos`): the kernel (`iw event`: connected,
disconnected, scans), NetworkManager (`nmcli monitor`) and `rfkill event`; the deadlines (30 s,
2 min, 30 min) are kept by `read -t`, a timer (since 2026-10-09, four sources and what it
queries every 10 s changed: see *Version of 2026-10-09*, below). **The only thing it polls is the ping to the router
every 10 s while connected**, because the hung card produces no event (option
chosen by the user; the alternative was to remove it and trust `fwlps=0 ips=0`). Every query to
NetworkManager or iwd carries a **5 s deadline** (`timeout 5`): a frozen one does not make
`nmcli`/`iwctl` fail, it leaves them waiting, and without a deadline the desync was not detected. The previous
version (it checked everything every 10 s) stays in `~/.local/bin/wifi-reparar.antes-vigilante-por-aviso`.
- **"Connected" but the router does not answer ~30 s in a row** (3 failed pings; hung card)
  → ordered restart (NetworkManager down, iwd —which resets the card—, NetworkManager up).
- **Disconnected 30 s** → ordered restart, **at most 3 in a row** (2 min apart);
  then it notes *"puede que no haya redes (fuera de casa)"* ("there may be no networks (away from home)") and only retries **every 30 min**.
  It goes back to zero on connecting. **If there is another internet connection** (Ethernet, phone over USB)
  it does nothing: it is not needed and restarting NetworkManager would cut it.
- iwd connected and NetworkManager not, 30 s → restarts NetworkManager.
- Brake: 2 min between restarts, 10 min after three in a row without recovering. It does nothing in
  plan B, with the **Wi-Fi radio off** (`nmcli radio wifi off`: the way to leave it off
  on purpose; just disconnecting will make it reconnect), with rfkill, nor while
  `wifi-reparar` runs (they share the lock `/run/wifi-reparar.lock`).
- Log: `/var/log/wifi-vigilante.log` (readable without root). It also notes the
  connection and disconnection events it receives. On start it writes `arranca (por aviso)` ("starts (event-driven)").

**Version of 2026-10-09: "optimizar sin pérdidas" ("optimize without losses")** (the user's request; it is in the `wifi-reparar` of
that day, backed up in `fish/void/red/`). The one of 2026-10-03 already waited event-driven, but **on each
10 s round it queried everything again** (2 `pgrep`, 2 `nmcli`, `iwctl`, `rfkill`, `ip`, `awk`, `sed`,
`date`…) and its ordered restart waited with `sleep 1` in a loop plus a `sleep 3`. Now:
- **The state is read again only when an event arrives** (or when the deadline of something that is already going
  wrong expires: disconnected, connecting…). The scan events of `iw event` are ignored (they do not change the
  state). There is a **fourth source**: `dbus-monitor` of the `NameOwnerChanged` of iwd and NetworkManager,
  to find out that one is running again. Before, that was checked every 10 s with `pgrep`.
- **Connected and in order, every 10 s it only does this:** the ping to the router and asking iwd
  and NetworkManager their state **over D-Bus** (`dbus-send` with `--reply-timeout=5000`: the same 5 s deadline as
  the `timeout 5` of before). **Why not only the ping:** a **hung** iwd or NetworkManager do not
  warn either (it is the branch that `probar-vigilante-desync.sh` tests with `kill -STOP`). With only the ping, a
  frozen NetworkManager with the network working would not be seen until the DHCP expired (hours). The
  two queries cost ~2 ms of processor each, against ~19 ms of `nmcli`.
- **The rest, without processes:** the router and "is there another connection?" are read from `/proc/net/route`, rfkill from
  `/sys/class/rfkill`, the time from `$EPOCHSECONDS` and the log with `printf '%(…)T'`.
- **Ordered restart, event-driven:** before restarting iwd it starts listening with `dbus-monitor` (its
  first line indicates that it is already subscribed) to the `InterfacesAdded` of `/net/connman/iwd/…`.
  NetworkManager starts **as soon as iwd publishes `net.connman.iwd.Station`**. The safety cap is
  20 s. The log says `iwd tiene la estación (aviso de D-Bus a los N s)` ("iwd has the station (D-Bus event after N s)") or, if the cap kicks in,
  `iwd no avisó de la estación en 20 s: arranco NetworkManager igual` ("iwd did not announce the station in 20 s: starting NetworkManager anyway").
- **Fix along the way:** when stopping it (`sv restart`/`down`), the previous version left **orphans**:
  `iw event`, `nmcli monitor` and `rfkill event` (it only killed its direct children, not the grandchildren).
  Checked on 2026-10-09 with a copy without root. Now it closes them all.
- **Branches: the same** (connected without answer 30 s; disconnected 30 s with 3 attempts and then every
  30 min; iwd connected and NetworkManager not, 30 s; brake of 2 and 10 min; nothing in plan B, with the radio
  off, with rfkill, with another connection nor while `wifi-reparar` runs).
- **Measured on 2026-10-09** (copies without root, with a simulated `sv`, both at the same time for 120 s,
  connected): the previous one launched **228 processes (1.9/s)** and used **1.28 %** of one core; the new one,
  **36 (0.3/s: 2 `dbus-send` and 1 `ping` every 10 s)** and **0.13 %**. The real watcher (the old one) gave
  1.27 %. It is installed by running `wifi-reparar` (it sees "otra versión" ("another version") and rewrites it: the previous `run`
  stays as `run.bak`); then, the three `probar-vigilante*.sh`, one at a time.
- **Installed and verified on 2026-10-09.** `wifi-reparar` (11:13:34) detected "wifi-vigilante … de otra
  versión" ("… of another version"), rewrote `/etc/sv/wifi-vigilante/run` and the log said `11:13:35 arranca (por aviso)`.
  The orphans that the previous one had left when stopped were removed once with
  `sudo pkill -P 1 -f '^(iw event|nmcli monitor|rfkill event)$'`; afterwards there is **a single set** of
  listening processes (`iw event`, `nmcli monitor`, `rfkill event`, `dbus-monitor` of
  `NameOwnerChanged`), all children of the `run`. **The installed one, measured** (60 s, CPU from `/proc/<pid>/stat`
  with children): **0.13 % of one core** (before 1.27 %), ~0.3 processes/s. Tests: table below.

**Tested on 2026-10-09 (new version)**, with the same three scripts:

| Script | Failure caused | What the watcher did |
|---|---|---|
| `probar-vigilante-desconexion.sh` | disconnection 11:13:52 | event instantly; ordered restart after 30 s (11:14:30); `iwd tiene la estación (aviso de D-Bus a los 2 s)` 11:14:32; connected 11:14:33; working 11:14:34 |
| `probar-vigilante.sh` | fake router MAC 11:14:36 | after 31 s (11:15:06) "conectado pero el router no responde ~30 s (tarjeta colgada): reinicio ordenado" ("connected but the router does not answer ~30 s (card hung): ordered restart"); station through D-Bus event after 1 s (11:15:07); working 11:15:13 |
| `probar-vigilante-desync.sh` | NetworkManager frozen 11:17:50 | after 39 s (11:18:28) "iwd conectado y NetworkManager no: reinicio NetworkManager" ("iwd connected and NetworkManager not: restarting NetworkManager"); connected 11:18:30 |

**Trap when testing:** run the scripts **one at a time and wait for the network to come back**. Run
back to back, `probar-vigilante-desync.sh` was launched in the same second as the restart of the previous
test and canceled itself ("NetworkManager no corre" ("NetworkManager is not running")); repeated alone, it worked. Likewise, a `ping`
launched right in the second of the restart fails: it is normal.

**Tested on 2026-10-03, already event-driven**, with three scripts that cause the failure, wait for it to
act and always undo it (`fish/void/red/wifi-monitor/`; **one at a time**, each one when the
network has come back):
- `probar-vigilante-desconexion.sh` (`iwctl station wlp3s0 disconnect`): event in the same
  second (04:22:08), restart at exactly 30 s (04:22:37), connected at 04:22:40.
- `probar-vigilante.sh` (fake MAC for the router): restart after 30 s (04:24:16 → 04:24:46).
- `probar-vigilante-desync.sh` (`kill -STOP` to NetworkManager, which it always unfreezes at the end):
  restart of NetworkManager after ~40 s counting from the start margin, connected 5 s
  later. With the first event-driven version it failed (no deadline in `nmcli`): hence the `timeout 5`.

**Tested on 2026-10-02, the desync branch:** with iwd connected NetworkManager was **frozen**
(`sudo kill -STOP $(pgrep -x NetworkManager)`, simulates a hung
NetworkManager; stopped with `sv down` does not work, because the watcher takes it as stopped on purpose).
The network was not cut (iwd keeps the connection and the IP). At 14:26:00, less than 2 min
later, the log said *"iwd conectado y NetworkManager no: reinicio NetworkManager"*;
there was a new NetworkManager, `wlp3s0` connected and iwd connected, without intervention.
**The branch of the real failure (iwd not seeing networks) is still untested**: it cannot be caused at
will (removing the MAC setting does not reproduce it). If a boot comes out without Wi-Fi, wait
a minute and look at the log before touching anything.

**Tested the "connected without answer" branch (2026-10-02, 16:28):** `probar-vigilante.sh` (in
`fish/void/red/wifi-monitor/`) puts a fake MAC for the router in the neighbor table, waits and
always undoes it. The watcher acted after 33 s and 16 s later the Wi-Fi worked.

**Stalls and hangs of the RTL8723BE: solved with `fwlps=0 ips=0` (2026-10-02).** The
passive monitor (below) first captured, without the options (16:11–16:40):
- **37 stalls ≥ 2 s** (533 s stalled in total; 935 pings without answer out of ~3600), many with
  music through the Bluetooth headphones: without disconnecting (iwd and NetworkManager "connected"),
  good signal, no card events; data kept arriving but the pings did not come back.
- **A hang of 2 min 20 s** (16:17:51–16:20:09) still "connected"; then iwd reconnected and
  **the *4-way handshake* failed on both nodes**: the card's reception was hung.
  It came back when iwd was restarted (`wifi-reparar`, 16:21). During one of the stalls, `wifi-reparar`
  (the version of then) saw the DNS fail and **went to plan B needlessly**; corrected: with
  iwd connected it retries and stays on iwd (plan B is only for when iwd does not connect).
- With **wpa_supplicant (plan B) it was also slow**: it does not depend on the backend. It is the chip.

**With `options rtl8723be fwlps=0 ips=0` and a reboot (16:43–17:13, video through the headphones
93 % of the time, twice the download): 0 stalls, 4 pings without answer out of 3594, median
5.2 ms, p95 43 ms, p99 55 ms, maximum 152 ms; the watcher did not have to act.** Before:
median 16 ms, p95 5.5 s, maximum 18.8 s. A single 30-min test and on a single node
(`…9e:12`): watch for a few days. Logs in `fish/void/red/wifi-monitor/registro-*`.
**Careful:** `fwlps=0 ips=0` was tried on 2026-10-01 against the *continuous scanning* and was removed because
it did not fix it; for the stalls it is exactly what is needed.

**Passive monitor:** `~/Work/wifi-monitor/monitor.sh [minutes]` (backed up in
`fish/void/red/wifi-monitor/`; when reinstalling, only if it is going to be used:
`mkdir -p ~/Work/wifi-monitor && cp "<disco>/Backups Linux/fish/void/red/wifi-monitor/"*.sh ~/Work/wifi-monitor/`): ping to the router every 0.5 s (`-O` marks the ones that do not come back),
card events (`iw event -f`) and every 2 s bytes, node, signal, speed, state of
iwd/NetworkManager and Bluetooth audio. `analizar.sh` lists each stall ≥ 2 s with what was happening
around it. It touches nothing.

**Manual way back** (to wpa_supplicant with the BSSID pinned): `wifi-reparar --plan-b`, or
`volver-wpa.sh` from `fish/void/red/pruebas-iwd-2026-10-02/`, with `sudo`.

##### History: the problem and the previous fix (BSSID pinned)

**Symptom (2026-09-30):** slow SSH, in bursts; ping from the ideapad to the router from 100 to 300 ms
in a sawtooth (80 → 180 → 290 ms, repeated), with peaks of up to 886 ms, while the
Legion gave 6 ms to the same router. **With Fedora it did not happen**, only with Void.

**Cause:** wpa_supplicant (NetworkManager starts it over D-Bus) **scanned without stopping**:
a scan of `@WIFI_SSID@` on the 13 channels every ~4 s, of 3.7 s each, with almost no gap.
While the radio is on another channel it receives nothing, and the peaks matched the
scans exactly. The network is a **Tenda mesh** (router `@MESH_ROUTER_MAC@`) with two
2.4 GHz points: `…9e:12` and `…9e:72` (the channels are chosen by the mesh and change: on 2026-10-02 they were
7 and 4). **The mesh sends 802.11v orders** ("switch access point") and announces 802.11k
(neighbor list): iwd's log of 2026-10-02 shows it (`BSS transition received
from AP`). With wpa_supplicant, those orders are most likely behind the continuous scanning
(not confirmed: Void has no system log).

**Fix of then:** pin the BSSID (`sudo nmcli c modify @WIFI_SSID@
802-11-wireless.bssid @MESH_NODE_A_BSSID@`). It worked because **NetworkManager turns off wpa_supplicant's
background scanning when the BSSID is pinned** (NetworkManager's code,
`nm_supplicant_config_add_bgscan`; unpinned, with several points seen, it uses
`bgscan simple:30:-65:300`, which does not explain a scan every 4 s). The price: no roaming, and
**no Wi-Fi if that node is turned off** or if the router changes (the BSSID stops existing).

**Comparison in the same period (2026-10-02, C → A → C, 2 min each, ping to the router):**

| | iwd (1st) | wpa + BSSID pinned | iwd (2nd) |
|---|---|---|---|
| Node, signal | `…9e:12`, −46 dBm | `…9e:72`, −26 dBm | `…9e:12`, −34 dBm |
| Scans | 0 | 0 | 0 |
| Median / p95 / p99 | 2.9 / 78 / 349 ms | 1.8 / 19 / 124 ms | 2.9 / 22 / 144 ms |
| Pings > 100 ms | 24 | 7 | 10 |

The two iwd ones differ from each other more than iwd against wpa_supplicant: **the isolated peaks are
from the environment** (at least 8 neighbor networks on 2.4 GHz), not from the backend, and they come out with both. The
pinned BSSID went somewhat better partly because of the signal: the mesh sent iwd to the farthest node.
iwd was chosen for the roaming and for not depending on a BSSID. Results and scripts:
`fish/void/red/pruebas-iwd-2026-10-02/`.

**What must not be repeated:**
- **Attributing a fix to a setting when the same step restarts the service.** That is how the
  random MAC was blamed: iwd was fixed by the restart. Test the setting separately.
- **Removing `fwlps=0 ips=0`** thinking that "the power saving was not the cause": it was not
  of the **continuous scanning** nor of the environment's latency peaks (tested on 2026-10-01 with
  `power_save off`, the driver's options and `wifi.powersave = 2`, and on 2026-10-02 with
  `power_save off`), but **it was of the stalls and hangs** of the reception. They are two different
  problems: measure each one with its symptom.
- **iwd without NetworkManager also works** (tested: `EnableNetworkConfiguration=true` in
  iwd and `unmanaged-devices=interface-name:wlp3s0` in NetworkManager; see
  `probar-iwd-solo.sh`). It was discarded because the Wi-Fi disappears from the applet and from `nmcli`.

**How it is diagnosed** (it works for any odd latency over Wi-Fi): `iw event -t`, which
works without root, at the same time as `ping -D`, and compare the timestamps:

```bash
(timeout 40 iw event -t &) ; ping -D -c 190 -i 0.2 192.168.0.1
```

To compare two configurations, **measure them in the same period** (like `comparar-ab.sh`):
two measurements of the same configuration minutes apart can vary a lot.
Debug logs (Void does not keep the system's): stop the services and launch
`/usr/libexec/iwd -d` and `NetworkManager --debug --log-level=DEBUG --log-domains=ALL` by hand,
like `probar-nm-iwd-registro.sh`.

**`nmcli c modify` over SSH fails** ("Not authorized"): polkit only allows it from the graphical
session, or with `sudo` on the machine itself.

**Send the remote scripts with `ssh ideapad bash -s <<'FIN'`**, as on the other
machines: if one day the login shell ends up being fish, the bash syntax blows up.

### 5. fish and the jump from bash

```bash
sudo xbps-install -Sy fish-shell
```

**The login shell stays `/bin/bash`, without `chsh`**, as on the other machines. If
ever the fish binary and its line in `/etc/shells` were lost separately, a
login pointing to fish would leave the account unable to log in (it happened on the Legion). On Void the
risk is smaller, because `/etc` is not rebuilt and xbps registers fish in `/etc/shells` when
installing it, but the machines of the network all go the same way. **On 2026-09-30 fish was set with
`chsh` by mistake and it was undone the same day;** if `getent passwd isaac` does not say `/bin/bash`,
correct it with `chsh -s /bin/bash` (asks for the user's password, without sudo).

Void **does not bring `~/.bashrc.d/`**, so it is created and a block that goes
through it is added to `.bashrc`. Both files are backed up:

```bash
V="<disco>/Backups Linux/fish/void"
mkdir -p ~/.bashrc.d
cp "$V/99-exec-fish.sh" ~/.bashrc.d/
cp ~/.bashrc ~/.bashrc.bak
cat "$V/bashrc-bloque.sh" >> ~/.bashrc
```

Void's `.bashrc` already brings `[[ $- != *i* ]] && return` at the beginning, and the fragment carries
besides its own guard, `BASH_EXEC_FISH` against loops and the `test -x` as a net. Void's
`.bash_profile` loads `.bashrc`, so it also works for logins.

**Verified on 2026-09-30:** interactive bash lands in fish 4.9.3; non-interactive bash
(`scp`, commands over SSH) stays in bash.

### 6. fish functions

```bash
sudo xbps-install -Sy fzf
B="<disco>/Backups Linux/fish"
mkdir -p ~/.config/fish/functions
cp "$B/arch/brew/"{fish_prompt,fish_greeting}.fish ~/.config/fish/functions/
cp "$B/void/"{install-pkg,remove-pkg,update-system,audio-ctrl,audio-priority}.fish ~/.config/fish/functions/
fish -c 'fish_add_path -U ~/.local/bin'
```

| Function | Origin | Note |
|---|---|---|
| `fish_prompt`, `fish_greeting` | `arch/brew/` | ported as they are; the greeting calls `fastfetch` |
| `install-pkg`, `remove-pkg`, `update-system` | **`void/`** | **rewritten for xbps**, see below |
| `disk-ops` | `arch/brew/` | `lsblk` + `fzf` + `udisksctl`, ported as it is; "Reparar NTFS" ("Repair NTFS") asks for `ntfs-3g` |
| `ssh-setup` + `ssh-survey.sh` | `herramientas/` | ported as they are, see below |
| `audio-ctrl`, `audio-priority` | **`void/`** | **adapted** from the SteamOS ones (`arch/brew/`), 2026-10-05: see below |

**`audio-ctrl` and `audio-priority` for Void (2026-10-05)**, adapted from those of the Legion with SteamOS
(`arch/brew/`), in `fish/void/`, installed on both machines:
- **`audio-ctrl`**: choose Salida or Entrada (Output or Input) and the device (with `fzf`; if there is only one, directly), change
  the card's profile if it is internal or "off", and the volume with a bar (← → in steps of 5, ↓ to
  type the number, Enter confirms, `q`/Ctrl+C leaves the volume as it was). It uses `pactl`; on Void there are not
  SteamOS's `alsa_loopback_device.*` wrappers (pactl sees the `alsa_output.*` directly): only
  the comment changed.
- **`audio-priority`**: choose Salida or Entrada (Output or Input) and mark with Tab, from **lowest to highest** priority, the order
  of the devices (the connected ones and those saved before even if they are not there). It writes
  `~/.config/wireplumber/wireplumber.conf.d/51-audio-priority.conf` (`priority.session`/`priority.driver`
  5000, 6000…), sets `node.restore-default-targets false` (`wpctl settings -s`) and restarts WirePlumber.
  **Changes for Void:** `pw-dump` is read with `python3` (there is no `jq`) and, without systemd, WirePlumber is
  restarted with `pkill` + `pidwait` + `setsid -f wireplumber` (PipeWire starts it at login, through
  `/etc/pipewire/pipewire.conf.d/10-wireplumber.conf`). **Trap (seen on the Legion on 2026-10-05, the
  first time it hung):** PipeWire runs with `SIGINT` and `SIGTERM` blocked (`SigBlk 0x4002` in
  `/proc/<pid>/status`) and the WirePlumber it launches inherits them: the `SIGTERM` stays pending (`ShdPnd
  0x4000`) and never goes out, so `pidwait` waited forever. Fix: `SIGTERM`, `timeout 3 pidwait`
  and, if it is still alive, `SIGKILL`. The one the function launches (`setsid`) no longer has anything blocked. If
  an old version hangs again: `pkill -KILL -x wireplumber` from another terminal. **Run it in a terminal of the session**, not over
  SSH (the new WirePlumber would lack the session bus). WirePlumber 0.5.18 on both.
- Detection tested on the Legion (2026-10-05): HDMI outputs of the monitor (MAG 276CF), speakers
  (`pci-0000_c2_00.6`), USB microphone UGREEN CM581 and Bluetooth headphones METHOD 360 ANC; inputs: the
  internal microphone, the UGREEN and the headphones.

> **Do not copy `install-pkg`, `remove-pkg` nor `update-system` from `arch/brew/` or
> `fedora-atomic/`, nor their `config.fish`.** They are for Homebrew, which is not here. The `config.fish` also sets brew's PATH and
> corrects `/var/home`, which does not exist on Void. Here there is no `config.fish`: the only setting is
> `~/.local/bin` in the PATH, as a universal variable (`fish_add_path -U`).

**`install-pkg` for xbps:** same shortcuts as the brew one (`tab`, `alt-p`, `alt-j/k`,
`alt-d/u`, `alt-i`), plus **`alt-f`** to see the package's files. It lists the ~14 800
packages of the repository with their description, marks the installed ones with **✓**, and searches by
name and description. It installs with `sudo xbps-install -S`, which syncs first and downloads the
latest version even if the list comes from the last sync. Underneath it turns
`xbps-query -Rs ''` (`[*] pkgver  description`) into `name<TAB>name ✓ description`; the
name comes out by removing the version from the `pkgver` (what goes after the last `-`). fzf shows and
searches only what goes after the tab (`--with-nth 2`), with the name **padded to 28 columns**
(it covers 99 % of the repository; the longest has 41), and `{1}` stays as the clean name
for the previews. **Do not show the tab:** fzf draws it up to the next multiple of
8 columns and the list comes out misaligned (short and long names fall in different columns).
`remove-pkg` uses the same format.

**`disk-ops` and `ssh-setup`** (copied on 2026-10-01, without changes):

```bash
sudo xbps-install -Sy ntfs-3g     # ntfsfix, for disk-ops's "Reparar NTFS" ("Repair NTFS")
cp "$B/arch/brew/disk-ops.fish"        ~/.config/fish/functions/
cp "$B/../herramientas/ssh-setup.fish" ~/.config/fish/functions/
cp "$B/../herramientas/ssh-survey.sh"  ~/.config/fish/ && chmod +x ~/.config/fish/ssh-survey.sh
```

Usage and traps of `ssh-setup`: `Backups Linux/herramientas/LEEME-ssh-setup.md` (in this repository,
[`../ssh-setup.md`](../ssh-setup.md)). It runs
**here** and acts on **another** machine, so it is not affected by this one being Void: the commands
it suggests (`systemctl`, `ufw`, `firewall-cmd`) are for the other side. Without arguments
it points to `lego` (`ssh_setup_default_host` is not needed). What it needs here already comes with
Void (`ssh-copy-id`, `ssh-keyscan`, `timeout`, `setsid`, `shred`, `ip`, `ping`).
**Verified on 2026-10-01:** `ssh-setup --diagnostico` found the Legion, diagnosed the
port and produced the full x-ray, without touching anything.

**Where they come from and what was changed.** The three were copied back then from Omarchy's
scripts (`omarchy-pkg-install`, `omarchy-pkg-remove`, `omarchy-update`, for pacman) and were
moved to Homebrew. When taking them to xbps, what does not fit on Void, or on this machine, was
corrected:

| Omarchy | Here | Why |
|---|---|---|
| Installs and removes with `--noconfirm` | **Without `-y`**: xbps shows the list (dependencies and size) and asks to confirm | See what it drags in or what it takes away before it happens |
| Lists only names | Name + description, ✓ on what is installed | Search by what it does, not only by the name |
| Remove: `pacman -Rns` over `pacman -Qqe` | `xbps-remove -R` over `xbps-query -m` | Equivalents in xbps |
| Remove: any package | **Protected with 🔒**: `base-system`, `linux*`, `grub*`, `xbps`, `lightdm*`, `xfce4`, `xorg-minimal` | Void's installer marks them "installed by hand" and they show up in the list |
| Update: one `pacman -Syu` | **xbps first, alone**, and then the rest | With an old xbps it updates nothing else (step 1) |
| Removes all orphans | **All except the kernels** (`linuxX.Y`) | The kernel of the previous series becomes an orphan and is the backup one |
| Snapshot with Snapper first | **There is none**, see Pending | It is not set up here |
| Restarts services | **Only `sshd`**, if OpenSSH changed | runit restarts nothing on update, and the old `sshd` cuts the connections |
| Offers to reboot | **Only warns** if there is a new kernel or a new glibc | When to reboot is decided by the user |

**`remove-pkg`:** lists only what is installed by hand (without dependencies), with description.
Shortcuts: `alt-i` information, `alt-f` files, **`alt-x` which packages depend on this one**.
If protected ones are selected, it sets them aside with a warning and goes on with the rest. If another
package depends on any of the chosen ones, xbps refuses and says so.

**`update-system`**, in order:
1. Syncs, shows the packages with their total download size and asks to confirm **once**.
   The rest goes without asking. **Before confirming** (2026-10-08), if the list replaces a
   package **built here** (installed from a local repository, without `http`: the pkgdb with
   `xbps-query --regex -p repository -s .`; on the Legion, gamescope and `xdg-desktop-portal-wlr` from
   `hostdir/binpkgs`; any other one built like that shows up by itself), it warns in yellow: "Void reemplazará
   `<paquete>` parcheado (`<instalada>` → `<nueva>`)" ("Void will replace the patched `<package>` (`<installed>` → `<new>`)"), with the script that rebuilds it (gamescope →
   `compilar-gamescope.sh` + `setcap`; `xdg-desktop-portal-wlr` → `compilar-portal-wlr.sh` + restart the
   portal; if it is not known, it says so) and how to keep it (answer `n` and `sudo xbps-pkgdb -m hold
   <package>`, without Void's fixes). If `~/src/void-packages` already exists, it warns to delete it first:
   the scripts do not update it and would build the old template. **Since 2026-10-09 it first tests the
   patch against the new code** (*Testing own patches*, below): if that code already brings it, it says so
   in green ("YA TRAE el parche (probado): se puede actualizar sin perder nada" — "ALREADY BRINGS the patch (tested): it can be updated without losing anything"); if it applies neither forwards
   nor in reverse, "revisar el parche antes de recompilar" ("review the patch before rebuilding"); without network, "sin comprobar" ("unchecked").
2. Updates **xbps first** if there is a new version, and then everything else.
3. Restarts `sshd` if a new OpenSSH came in. Open sessions are not cut.
4. Removes the orphans **except the kernels**. For the backup one it shows how to remove it by hand.
5. Cleans from the cache the packages that no longer match anything (`xbps-remove -O`).
6. Removes the kernels that belong to no package, like the ISO's (`vkpurge rm all`).
7. **Warns** about the `.new-*` in `/etc`, without applying them (step 1).
8. Flatpak and LazyVim, only if they are installed.
9. Warns if a reboot is advisable.
10. If everything ended fine, writes the date in `~/.local/state/update-system.last` (used by
    fastfetch's "Actualizado" ("Updated") line, step 12).
11. **Summary at the end** (2026-10-04, the user's request: "para no caer en no leerlo" — "so as not to end up not reading it"): one
    line per check, **OK** (green), **REPARADO** (REPAIRED, cyan) or **AVISO** (WARNING, yellow), and at the end
    "✓ Todo en orden" ("✓ All in order") or "⚠ N aviso(s)" ("⚠ N warning(s)"). Each check shows up only if the piece exists on the
    machine:
    - **The Legion's TDP** (`lenovo-wmi-tdp`, DKMS): built for the newest kernel; if not and
      it is 6.18.x, it **repairs** it (`sudo dkms autoinstall -k <version>`); if it is another series, it warns (the
      DKMS package only builds for 6.18). And that the `linux` metapackage is **held**.
    - **gamescope** (if Game Mode is there): with `cap_sys_nice`; if it lost it when updating, it
      **puts it back** (`setcap cap_sys_nice=eip`, like `instalar-modo-juego.sh`).
    - **Packages built here, one line each** (2026-10-07; extended on 2026-10-08):
      **gamescope with the PipeWire patch** (only where the gamescope portal is, that is, the Legion:
      `/usr/local/share/xdg-desktop-portal/gamescope-portals`), **`xdg-desktop-portal-wlr` with the windows
      patch** (only where the screen-share chooser is, the Legion:
      `~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service`) and any other
      package from a local repository. WARNING if the installed one is already Void's (`http` repository: an update
      replaced it), with the script that rebuilds it. If it is still the local one, it compares it
      with the one of the remote repositories (only the `http` ones of `xbps-query -L`, with `xbps-query -i -R
      --repository=<url>… -p pkgver`, and `xbps-uhelper cmpver`): **OK** if the one here is newer (the
      normal thing: the scripts build with Void's revision + 1); **WARNING** if Void has **the same**
      version and revision (xbps does not install it, but it is a Void build newer than ours,
      e.g. rebuilt because of a new library: rebuild to have its changes with the patch); and
      **WARNING** if Void has a **newer** one (the next update replaces it without the patch).
      **`xfdesktop` with the fix of the wallpaper dialog on Wayland** (2026-10-09; only where there is Xfce
      Wayland, `~/.config/xfce4/labwc/rc.xml`; step 15, *Desktop wallpaper on Wayland*): the same
      rules. **`Thunar` with the fix of "Establecer como fondo de pantalla" ("Set as wallpaper") on Wayland** (2026-10-09;
      same place, step 15, *Wallpaper from Thunar on Wayland*): the same rules.
      **Patch test (2026-10-09; *Testing own patches*, below):** in each one of these lines,
      when Void's version differs from the installed one, or when what is installed is already Void's, it tests the
      patch against the code of Void's template and adds it to the line: "el parche sigue haciendo
      falta (probado en el código de Void X)" ("the patch is still needed (tested on Void's code X)") (with OK or WARNING according to the above); if Void already brings it, **OK
      with NOTE** "Void ya lo trae: se puede volver al de Void con `sudo xbps-install -Sf <paquete>`" ("Void already brings it: one can go back to Void's with …") (with
      `thunar -q`, `setcap` or restarting the portal according to the piece; `-f` installs the repository's even if the
      one here has a higher revision: tested with `-n`), or "la próxima actualización lo reemplaza sin perder
      nada" ("the next update replaces it without losing anything"); if the patch applies neither forwards nor in reverse, **WARNING** "revisar el parche" ("review the patch"); without network,
      "sin comprobar" ("unchecked") and the above. **Removed** the assumptions of before: "xfdesktop >= 4.20.3 already
      brings it" and "if Void's Thunar plugin links `libxfce4windowing`, it is fixed" (without network neither
      is used: it says "sin comprobar").
    - **InputPlumber** (official binary) and the **gamescope portal** (`/usr/local/lib/
      xdg-desktop-portal-gamescope`, Valve's binary): that `ldd` does not give `not found`; if something is missing, it says
      what to do (install the library or bring another version and repeat its installer). One line each.
    - **`steamos-manager`** (built on the Legion with a patch, outside xbps), in one line: `ldd`
      of `/usr/lib/steamos-manager` and `steamosctl` (if something is missing: rebuild with
      `compilar-steamos-manager.sh` and install), that they are **the reference binaries** (`sha256sum -c`
      of `/usr/local/share/steamos-manager-void/sha256`; if that file does not exist, WARNING) and that its
      **build dependencies** are still installed (`glib-devel eudev-libudev-devel
      speech-dispatcher-devel clang pkg-config git make` and `~/.cargo/bin/cargo`; if one is missing, the
      command to install it). The line also says **which package** it is (file `paquete` of that folder,
      e.g. `paquete steamos-manager-v26.4.1-void-2`), as a note and not as a WARNING: with `…-void` it adds
      "el oficial, SIN el parche de set_clocks" ("the official one, WITHOUT the set_clocks patch") (a valid option, to go back) and without the file,
      "paquete desconocido (repetir instalar-steamos-manager.sh para registrarlo)" ("unknown package (repeat … to record it)"). Both files are
      written by `instalar-steamos-manager.sh` on every installation (since 2026-10-08; recipe of the
      Legion, step 14, steamos-manager). **Since 2026-10-09** it looks at upstream's latest `vX.Y.Z`
      tag (`git ls-remote`, ~1 s) and, if it is different from the installed one, tests the patch against it
      (NOTE in the line: still needed / already brings it / review).
    - **`extest`** (`~/.local/lib/extest/libextest.so`, 32-bit), in one line: `ldd` (if something is missing,
      the command to rebuild it, Legion recipe, step 14, "Controller on the desktop") and that
      `~/.cargo/bin/cargo`, the `i686` target of `~/.rustup`, `~/src/extest` and `gcc-multilib` are still there.
    - **Limit:** it does not know whether there is a new **upstream** version of InputPlumber, `extest` or the
      gamescope portal (of `steamos-manager`, yes, since 2026-10-09); and `ldd` only sees missing libraries,
      not changes in Steam that break `extest`. **The patch test does not cover** the pieces that do not
      carry an own patch and are only built or brought because Void does not have them: InputPlumber (official
      binary), `extest`, the TDP modules through DKMS (code of kernel 6.18.55 unchanged) and the gamescope
      portal (Valve's binary).
    - **Recommended kernel series:** compares the one of the repository's `linux` metapackage
      (`xbps-query -R -p pkgver linux`) with that of the newest installed kernel: OK if they match;
      WARNING "Void ya recomienda la serie X; aquí sigue la Y" ("Void already recommends series X; here it is still Y") if Void changed (on the Legion, with
      `linux` held, it is the way to find out; changing is the user's decision).
    - The `.new-*` templates and whether a reboot is advisable, repeated.
    It only repairs what its own installer would do; it only downloads for the patch test (source
    code to a temporary directory, with a cache per version). Here (IdeaPad) there show up
    the kernel series, gamescope, `xfdesktop` (since 2026-10-09), `.new-*` and reboot (verified on
    2026-10-04: 4 × OK, before the `xfdesktop` line).
12. **`update-system --resumen`** (summary) (2026-10-08): only the summary of point 11, **without syncing, without
    `sudo` and without changing anything** (what "Void has" is what the last sync has; what it would repair
    — TDP, `cap_sys_nice` — it warns about with its command; the reboot, because of the newest kernel or because of a glibc
    installed after booting). **Check:** `update-system --resumen` → here, 4 × OK and
    "✓ Todo en orden" (2026-10-08). Since 2026-10-09, until installing the patched xfdesktop (step 15),
    4 × OK and 1 WARNING of `xfdesktop`; installed, 5 × OK (verified on 2026-10-09). With the
    Thunar line (2026-10-09): 5 × OK and 1 WARNING of `Thunar` until installing the patched one; then, 6 × OK (verified on 2026-10-09).
    With the patch test (2026-10-09): **6 × OK**, with "el parche sigue haciendo falta (probado…)" in
    `xfdesktop` and `Thunar`. **Time:** 3 s before; with the test, 22 s the first time (it downloads the code
    of each version), 3–4 s afterwards if the cache already has the version that Void publishes, and 7–11 s while the
    void-packages template is ahead of the local index (today Thunar: template 4.20.10_1, index
    not synced at 4.20.9_1: it clones the template on every pass until the next `xbps-install -S`).
    Without network (tested with `unshare -rn`): 3.8 s, what is in the cache and "sin comprobar" in the rest.

**Testing own patches** (*Prueba de parches propios*) (2026-10-09, the user's request: to know **without assumptions** whether each own
patch is still needed after an update). `fish/void/parche-sigue-haciendo-falta.sh`, installed
as `~/.local/bin/parche-sigue-haciendo-falta`, without root (in this repository:
`common/patch-test/patch-still-needed.sh`, with the states in English, see the glossary):
- `parche-sigue-haciendo-falta void <package> <patch>…`: brings the current template of void-packages
  (`git clone --depth 1 --filter=blob:none --sparse`, only `srcpkgs/<package>`), reads from it **only
  assignments** (`version`, `revision`, `distfiles`, `checksum`, `patch_args`, `_*`; if any carries `$(`
  or backquotes, it does not use it), downloads the **first** distfile to a new temporary directory,
  **checks its sha256** against the template's, unpacks it, applies the patches that Void's
  template already brings and tests ours in order: `git apply --check` (HACE_FALTA, and it applies it to
  test the next one on top), otherwise `--reverse --check` (YA_INCLUIDO), otherwise CONFLICTO. First with all
  the context and, if not, with 1 line (`-C1`, like GNU patch's "fuzz" that xbps-src uses; it says so:
  `contexto_reducido`). Overall result: HACE_FALTA, YA_INCLUIDO, **PARCIAL** (some included and others
  not: it says which) or CONFLICTO; without network or unable to check, **SIN_COMPROBAR** (it exits with 0).
- `parche-sigue-haciendo-falta git <url> <ref> <name> <patch>…`: the same with a tag or branch of
  upstream (steamos-manager).
- Cache: `~/.cache/update-system/parches/<name>-<version>-<hash of the patches>.txt` (it does not save
  SIN_COMPROBAR); `--version <v>` answers from the cache without network; `--sin-cache` ignores it.
- The patches it uses are in `~/.local/share/update-system/parches/<package>/`. Install or repeat
  (if a patch or the script changes), on both machines the same:

```bash
bash "<disco>/Backups Linux/fish/void/instalar-prueba-parches.sh"    # without root
```

- **The `compilar-*.sh`** (xfdesktop, Thunar, gamescope, `xdg-desktop-portal-wlr`, steamos-manager) run
  the same test before building: YA_INCLUIDO → they do not build; CONFLICTO, PARCIAL or SIN_COMPROBAR → they
  stop. It replaces the checks of before (`xfdesktop >= 4.20.3`; in Thunar, a one-line `grep`).
- **Tested on 2026-10-09** (real results): against Void's versions, HACE_FALTA on the five
  pieces (`xfdesktop` 4.20.2_1, `Thunar` 4.20.10_1, `gamescope` 3.16.30_1, `xdg-desktop-portal-wlr`
  0.8.4_1 with its 3 patches, `steamos-manager` v26.4.1); **YA_INCLUIDO** the `xfdesktop` patch against
  upstream's `xfce-4.20` branch (it brings `ed26b06a`; only with `contexto_reducido`, because a later commit
  changed the surrounding lines: with full context it gave CONFLICTO); **CONFLICTO** the
  Thunar patch against Thunar `master` (it moved to meson: there is no `configure.ac`). PARCIAL could not be
  caused with real code. The YA_INCLUIDO and CONFLICTO messages of `update-system` (summary and the warning
  before) were tested with a made-up cache in a separate directory.

It keeps `sudo` alive in the background so that a long download does not ask for the
password again halfway. It turns itself off when finished, or at most after 2 h if it is cut with
Ctrl+C.

**`fzf`'s previews run in bash** (`--with-shell 'bash -c'`), not in `$SHELL`:
that way they work the same with bash or fish as the login shell.

### 7. Claude Code

`curl` does not come in the Xfce ISO (nor `wget` nor `git`):

```bash
sudo xbps-install -Sy curl git ripgrep xdg-utils
curl -fsSL https://claude.ai/install.sh | bash      # without sudo: the installer refuses it
```

It is installed in `~/.local/bin/claude` (link to `~/.local/share/claude/versions/<version>`),
which is already in fish's PATH because of step 6. Afterwards, **`claude` in a terminal of the
machine itself** to log in. Without `xdg-utils` the browser does not open by itself: it shows
a link to open in Firefox and paste the code. Checkable with
`ls ~/.claude/.credentials.json`.

The project's context is in `~/Work/CLAUDE.md`, backed up as
`Backups Linux/CLAUDE-void-ideapad.md`: it describes this machine, the others of the network, the
installed tools and the rules that are expensive to learn. When reinstalling:

```bash
mkdir -p ~/Work && cp "<disco>/Backups Linux/CLAUDE-void-ideapad.md" ~/Work/CLAUDE.md
mkdir -p ~/.claude/projects/-home-isaac-Work/memory
cp "<disco>/Backups Linux/claude-memoria-ideapad/"*.md ~/.claude/projects/-home-isaac-Work/memory/
```

The second part is **Claude Code's memory** for `~/Work` (backed up in
`claude-memoria-ideapad/`): today, that it always answers in Spanish, that the recipe can be followed
without inferring anything and that the Legion already has Void (`MEMORY.md`, `responder-en-espanol.md`, `receta-explicita.md`
and `legion-live-usb.md`; all four, identical on the machine and on the disk on 2026-10-08). If Claude saves something
new there, copy the folder to the disk again.

**When changing something important on the machine, also update that file and its copy.**
The Fedora one (`CLAUDE-fedora-ideapad.md`) stays as a reference.

**Maintenance agent `mantenedor-void`** (2026-10-07; the same on both machines; `void-maintainer` in this
repository): a Claude Code subagent that audits the system (runit services that clash with D-Bus or relaunch in a loop,
packages, fidelity with Common, consumption), proposes safe fixes, prepares what needs root for
the user to run and maintains the recipe. It only reads until the user approves. Its definition is in
`claude-agentes/mantenedor-void.md` and its tool, in `fish/void/agente/auditar-void.sh` (read-only,
without root; it can be used by hand: see its header). It is installed together with the context:

```bash
mkdir -p ~/Work/.claude/agents && cp "<disco>/Backups Linux/claude-agentes/mantenedor-void.md" ~/Work/.claude/agents/
```

It is used from Claude Code in `~/Work` by asking for it by name ("usa el agente mantenedor-void para…" — "use the mantenedor-void agent to…").
If it is changed, copy the definition again to Common and to the other machine.


### 8. Boot: Windows on the XS1000, without messages and GRUB theme

**Order inside this step:** now, the Windows entry (right below) and *Boot and shutdown with
fewer messages* (`arranque-silencioso.sh`). **Without Plymouth since 2026-10-05:** do not run
`instalar-plymouth.sh` (its section stays as a reference). **The GRUB theme (`instalar-tema.sh`) goes
when step 10 is finished**, because it uses the copy of the font that that step makes; nothing of the above needs to be
repeated afterwards. Reboot at the end of step 10, with everything in place.

**One command**, which verifies everything before writing and can be repeated without harm:

```bash
sudo bash "<disco>/Backups Linux/herramientas/uefi-usb3/void/instalar-arranque-void.sh"
```

It leaves **one** entry, "Windows (disco externo Kingston XS1000)" ("Windows (external disk Kingston XS1000)"), which boots the Windows To
Go of the external SSD **on either of the two USB ports**:

1. `/boot/grub/custom.cfg`: the entry. `/etc/grub.d/41_custom` loads it, so it survives
   every `grub-mkconfig` (Void launches it when installing a kernel). It carries the UUID of the
   EFI partition **of this installation** (`@IDEAPAD_EFI_UUID@` on 2026-10-01; it changes when reinstalling,
   the installer puts it by itself).
2. `/boot/efi/EFI/tools/`: OpenCore's UEFI shell, the USB drivers and Void's `startup.nsh`.

It does not touch `grub.cfg`, `/etc/default/grub`, `EFI/void_grub` nor the firmware. The GRUB menu
**already shows for 5 s** on Void (`GRUB_TIMEOUT=5`): Fedora's `user.cfg` is not needed. **Here one wants
to see the menu** (the user's decision, 2026-10-04): the hidden GRUB (`grub-oculto.sh`) and the boot
without Plymouth were **only the Legion's**; the hidden GRUB still is (here the menu shows), but
**Plymouth was removed here too on 2026-10-05** (the user's request: no loading animations; step
14, "Igualada con la Legion" ("Matched with the Legion")). The kernel
hook that could write entries to the firmware is off
(`MODIFY_EFI_ENTRIES=0` in `/etc/default/efibootmgr-kernel-hook`): leave it like that.

**Pieces**, in `Backups Linux/herramientas/uefi-usb3/void/` (`custom.cfg`, `startup.nsh`,
`instalar-arranque-void.sh`, `SHA256SUMS`). The EFI binaries are those of the folder above,
common with Fedora and verified with its `SHA256SUMS`; the installer checks both. The
Fedora pieces were not touched. Test without root: `ROOT=/tmp/raiz ESP_UUID=<uuid> bash
instalar-arranque-void.sh` (there it runs the real `grub-script-check` of Void's GRUB).
(The IdeaPad's Windows entry, with its UEFI shell, is not in this repository: the Legion boots that
Windows with a plain `chainloader`, its recipe, step 8.)

#### What changes compared to Fedora, and why

**Void's GRUB (official 2.12) does not have `connectefi`:** it is a Fedora patch. Fedora's
`custom.cfg` would give "orden desconocida" ("unknown command") and GRUB would stop to wait for a key, and without
that command GRUB **never sees the USB disk**. That is why Void's entry looks for nothing: it always opens
the shell, and it is `startup.nsh` that resolves the two ports.

**The machine has two USB controllers:** xHCI (`00:14.0`, handle `198` in the shell) and
EHCI (`00:1d.0`). The USB 2.0 port goes through EHCI, which the firmware does handle; the 3.0, through
xHCI, which Insyde's driver (`F5`) does not know how to handle with this SSD. `startup.nsh`:

- **Stage 0 (USB 2.0, new):** `connect -r` with the firmware's drivers, `map -r`, and if
  `bootmgfw.efi` shows up, it launches it. It is the same that `connectefi pciroot` did in GRUB.
  `connect -r` goes **without redirecting** (the shell forbids redirecting that line) and then `cls`.
- **Stages 1–4 (USB 3.0):** identical to Fedora's, with two additions: the range of
  handles goes up to `3FF` (before `2FF`) and, **before disconnecting the 198, it leaves a log**
  in the EFI partition: `EFI/tools/diag-drivers.txt` (`drivers`) and
  `diag-198-antes.txt` / `diag-198-despues.txt` (`dh -d 198`) (before/after), in ASCII (`>a`). They are read
  from Linux without root.

**What happened when testing it (2026-10-01):** the first version, without the log, failed on the
USB 3.0 with "ningún driver tomó el controlador USB 3.0 (198)" ("no driver took the USB 3.0 controller (198)"). With the log added (and the
range extended) it booted, and the log showed that OpenCore's XhciDxe ended up in handle
**`202`** — **inside** the original range, so extending it was not what fixed it. The
cause of the first failure **is not known**: maybe the pause of the log (`drivers`, `dh`)
gives the firmware time after stage 0, or it was intermittent. **The log is left on
purpose:** it does not get in the way and, if it fails again, it says at which step. After the change, the
user tested **both ports and both booted**.

From the log of that boot: before, the 198 was handled by `F5` (UEFI Usb XHCI Driver) and
`F6`; afterwards, `202` (OpenCore's XhciDxe) and `203` (EDK2's UsbBus), with a new child at
`USB(0xB,0x0)`: the XS1000, the same place as on Fedora. The drivers loaded were
`202`/`203`/`204`.

**To test or use:** **unmount `Common` before rebooting** (`udisksctl unmount -b
/dev/sdb4`) — that disk was already lost once by booting its Windows with the volume mounted
—, choose the entry and, when done in Windows, **Shift + Apagar** (Shift + Shut down). On USB 2.0 there shows
`[0/4]` and "USB 2.0: arrancando Windows…" ("USB 2.0: booting Windows…"); on USB 3.0, `[0/4]`, "No está en el USB 2.0…" ("It is not on the USB 2.0…") and
`[1/4]`…`[4/4]`.

**The boot rules of Fedora's recipe are still valid**, and so is its manual
diagnosis (remove `-delay 0` from `custom.cfg`, Esc to stay in the shell, `drivers -b`,
`dh -d F5`, `devtree 198`) and its *Troubleshooting → La entrada de Windows no arranca* (The Windows entry does not boot). The
error messages of `startup.nsh` are the same.

**To revert:** `sudo rm /boot/grub/custom.cfg` and `sudo rm -r /boot/efi/EFI/tools`. The
entry disappears on the next boot; there is nothing else to undo.

#### Boot and shutdown with fewer messages

```bash
sudo sh "<disco>/Backups Linux/fish/void/arranque/arranque-silencioso.sh"            # applies
sudo sh "<disco>/Backups Linux/fish/void/arranque/arranque-silencioso.sh" --quitar   # undoes
sudo update-grub      # or the theme's installer, which runs it and also repaints the background
```

It does three things (scripts in `fish/void/arranque/`; each touched file leaves its `.bak`). It is always run
separately (until 2026-10-05 `instalar-plymouth.sh` also applied it, now unused).

1. **It silences runit's `=>` lines** (2026-10-02). They are printed by `msg()` (and the green "OK"
   `msg_ok()`) of `/etc/runit/functions`; `/etc/runit/1` and `/etc/runit/3` load **`/etc/rc.conf`
   before almost all of them**, so it is enough to redefine them there: block marked `# >>> arranque
   silencioso` with `msg() { :; }` and `msg_ok() { :; }`. `rc.conf` is a configuration file
   (it survives updates; `/etc/runit/functions` does not). **`msg_warn` and `msg_error`
   still come out**: problems are seen. "Welcome to Void!" stays (it is printed before reading
   `rc.conf`; with the logo it is not seen).
   **Besides, only in `/etc/runit/1` and `3`** (the block looks at `$0`), the normal output of what they
   run (btrfs, `fsck.fat`, seedrng, the 9 of sysctl…) goes to `/dev/null`
   (`exec 3>&1 1>/dev/null`); stderr stays on screen, and `msg_warn`/`msg_error` are redefined
   to write through descriptor 3 (the screen) and also on top of the logo
   (`plymouth display-message`). `emergency_shell` is redefined to remove the logo and give the
   output back to the screen before opening the emergency console.
   **`/etc/modules-load.d/dm-raid.conf` becomes `.desactivado` (disabled):** the installer left it (it belongs to no
   package), here there is no RAID or LVM, and it loaded `dm-raid`, `raid456`… with their list and the
   "mdadm: No arrays found" on screen.
2. **Kernel line:** `quiet loglevel=3 rd.udev.log_level=3 udev.log_level=3
   vt.global_cursor_default=0` (plus ` splash` if it was already there: it respects it). **The order matters:** before it was `loglevel=3 quiet` and the
   last one wins, so `quiet` (which lets errors through) overrode `loglevel=3`. udev silenced and no
   blinking cursor.
3. **It removes GRUB's "Loading Linux …", "Loading initial ramdisk …" (and "devicetree")**, which
   with the theme opened a black box on top of the menu: they are one `echo` line per message in
   `/etc/grub.d/10_linux` (configuration file of the grub package: the change survives). They
   are turned into a marked comment (`quitar-loading.py`; `--quitar` gives them back
   identical). Besides, the theme puts GRUB's console in full screen and without border, in case
   GRUB has to write something (an error).

**Trap that cost a duplicated menu: `update-grub` runs EVERYTHING executable in
`/etc/grub.d/`**, whatever its name. The first version left `10_linux.bak` executable next
to it and every entry came out twice (the copy, with the "Loading" of before). The script now leaves
the `.bak` without execute permission. Do not leave executable copies in `/etc/grub.d/`.

To see all the messages of a specific boot: `e` in GRUB's menu and remove `quiet`.
What was left written on the first console after booting:
`sudo sh -c 'fold -w $(stty -F /dev/tty1 size | cut -d" " -f2) /dev/vcs1'` (also with the
logo: what is written stays on console 1 even if Plymouth covers it).
**Verified on 2026-10-02:** less text when booting and shutting down, without the "Loading" box and
`/proc/cmdline` with the new options.

#### The Lenovo logo until the login screen (Plymouth, 2026-10-02) — REMOVED on 2026-10-05

**Since 2026-10-05 it is not there** (the user's request: no loading animations, like the Legion;
removed with `ideapad-como-legion.sh`, step 14, "Igualada con la Legion"). What is below stays as a
reference of how it was and of what was learned; in a reinstall, **do not run `instalar-plymouth.sh`**
(the silent boot is set with `arranque-silencioso.sh`).

When choosing the entry in GRUB one sees **only the Lenovo logo, with Void's symbol spinning
below**, until the login screen comes out: not a single line of text. It is Plymouth (22.02, from the
repo) with the theme **`bgrt-void`**: the package's `bgrt` (it paints the same image as the firmware
at power-on, the ACPI BGRT table, `/sys/firmware/acpi/bgrt/`) with the loading circle replaced
by Void's symbol (without the word, its two greens, 56 px, 36 frames: ~1 turn per
second, clockwise). Preview: `fish/void/arranque/plymouth-void/vista-previa.png`.
If something fails, runit's warnings and errors come out on top of the logo, and the emergency console
removes it. `Esc` during boot shows the text.

```bash
sudo sh "<disco>/Backups Linux/fish/void/arranque/instalar-plymouth.sh"            # installs
sudo sh "<disco>/Backups Linux/fish/void/arranque/instalar-plymouth.sh" --quitar   # undoes
```

1. `plymouth` + `plymouth-data`; generates the theme in `/usr/share/plymouth/themes/bgrt-void/` with
   `plymouth-void/generar.py` (needs `rsvg-convert` and Pillow) and sets it as default.
   The `bgrt` theme is the *two-step* plugin with the images of `spinner`, and while booting it
   repeats `throbber-0001.png`…: the generator makes those frames from the SVG of
   `void-artwork` (removing `letters` and `border`, like the GRUB theme's logo) rotated 10° each
   one, copies the rest of the images of `spinner` (password, keyboard) and writes
   `bgrt-void.plymouth` = `bgrt`'s with `ImageDir` pointing to its folder. That folder belongs to no
   package: Plymouth's updates do not touch it. To change size,
   speed or color: `TAM`/`FOTOGRAMAS` (size/frames) in `generar.py` and repeat the installer (it rebuilds the
   initramfs, which carries a copy of the theme).
2. ` splash` at the end of the kernel line (without it Plymouth does not start).
3. **It removes the text login of console 1** (`rm /etc/runit/runsvdir/default/agetty-tty1`;
   `--quitar` gives it back), which is where the logo is seen: that way nothing writes to or touches that console
   while Plymouth has it. Consoles 2–6 keep their login (Ctrl+Alt+F2…F6). **It is a
   precaution:** when it hung (below) `agetty-tty1` was active, but the proven cause was
   another one and it was not tested separately whether it also works with it.
   **The one that closes Plymouth is lightdm**, which knows how to do it by default (`plymouth --ping`,
   `--has-active-vt`, `quit --retain-splash`). As Plymouth is on console 1, lower than its
   `minimum-vt` (7), **it does not reuse it** ("Plymouth is running on VT 1, but this is less than
   the configured minimum VT, not replacing it"): it starts X on **console 7**, as always
   (`pgrep -a Xorg` → `vt7`), and removes Plymouth itself. With autologin into a Wayland
   session (Xfce Wayland or Game Mode, steps 14 and 15) it is the same: the same console 7, without Xorg.
4. Applies `arranque-silencioso.sh` (above) and rebuilds the initramfs (`dracut --force
   --regenerate-all`: the `45plymouth` module goes in by itself) and the menu with the theme.

**What cost a machine stuck on the logo: do not close Plymouth before lightdm.** The first
version put `plymouth quit --retain-splash` in `/etc/sv/lightdm/conf` (its `run` loads it):
Plymouth closed leaving console 1 with the image and without giving back control of the console,
and the switch to 7 never happened (`chvt 7` hung, Xorg in `vt_waitactive` forever, without
greeter): the screen, stuck on the logo. With lightdm closing it, the same switch to 7 works.
It was entered over SSH; `diag-vt.sh` (in the same folder, `sudo sh diag-vt.sh`) diagnosed it, and its
report is next to it (`diag-vt.txt`). The installer deletes that `conf` if it finds it.

**Panel scale (2026-10-03, because of the Legion):** the installer calculates the scale (panel height /
768, rounded; here 1), generates the frames at 56 × scale and puts `DeviceScale=1` in
`/etc/plymouth/plymouthd.conf`. Here the 36 frames come out identical to those of before (checked
byte by byte); on the Legion (scale 2) Plymouth stretched the 56 px ones and they came out blurry. When repeating the
installer here `DeviceScale=1` is added, which changes nothing (the automatic scale was already 1).
**Trap (2026-10-03): `DeviceScale` goes AFTER `Theme`.** The reader of
`plymouth-set-default-theme` (`read_theme_name_from_file`, an `awk` by sections) only looks at **the
first key** of `[Daemon]`; with `DeviceScale=1` in front it says that the theme is `spinner`, and **dracut
uses that same reading to choose which theme to put in the initramfs**. The installer puts it behind
`Theme=` and stops (without rebuilding the initramfs) if `plymouth-set-default-theme` does not return `bgrt-void`.

**At shutdown there is no logo** (black screen with whatever little is left): stage 3 loads `rc.conf` with
X still open (Plymouth would fight it for the screen) and `shutdown.d/70-pkill.sh` would kill it
halfway.

**If it stays on the logo:** over SSH, `sudo sh diag-vt.sh` (diagnosis) and
`sudo sh instalar-plymouth.sh --quitar && sudo reboot`. Ctrl+Alt+F2 does not work if the console
is blocked. For a specific boot: `e` in GRUB and delete `splash`.
**Verified on 2026-10-02:** from GRUB's menu to the login screen, only the Lenovo logo
with Void's symbol spinning.

#### GRUB menu theme: "void-xterm" (2026-10-02)

The boot menu with the terminal's style: background `#214130`, Super Game Bro palette of
`~/.Xresources`, font JetBrainsMono NFM Blocks, the **Void logo** (only the symbol,
recolored) with "Void Linux · ideapad-100" on the left, and the entries in a **frame with the
title "Arranque" ("Boot") on the border**, like fastfetch's boxes. The chosen entry carries a
box of the color of xterm's cursor (`#D4F060`). In the bottom right corner, the **countdown**:
an hourglass and the number of seconds.

```bash
sudo bash "<disco>/Backups Linux/fish/void/grub-tema/instalar-tema.sh"          # installs/regenerates
sudo bash /usr/local/share/grub-tema/instalar-tema.sh --quitar                  # back to the text one
```

**It goes after step 10**: it uses the copy of the font in `/usr/local/share/fonts/jetbrains-blocks/`.
The installer puts `python3-Pillow` and `python3-fonttools` (official; `python3-fonttools` is an
empty transitional package that installs `fonttools`, the one that stays), copies the scripts to
`/usr/local/share/grub-tema/`, adds to `/etc/default/grub` a block marked `# >>> tema
void-xterm` (with `.bak`), puts the kernel hooks, generates the theme in
`/boot/grub/themes/void-xterm/` and runs `update-grub`. At the end it lists **the painted entries**:
they must match those of the menu and in the same order (today: 6.18, 6.12, UEFI Firmware Settings,
Windows). It does not touch `custom.cfg` nor the firmware.

**Why it is made like this** (GRUB **only draws 1-bit fonts**: without antialiasing, jagged):
- **All the text is painted in `fondo.png`** (background), with antialiasing, **also the names of the
  entries**. GRUB's menu uses an empty font (`vacia.pf2`, generated) and only puts the
  box of the chosen one (`sel_*.png`, pieces outside the row, which fit with it).
- That is why **the background depends on the entries** and regenerates itself: the hooks
  `/etc/kernel.d/post-{install,remove}/60-grub-tema` redo it after Void's `50-grub` every
  time a kernel comes in or goes out. If `update-grub` is run by hand and the entries change,
  repeat the installer.
- **No submenu nor recovery modes** (`GRUB_DISABLE_SUBMENU=y`, `GRUB_DISABLE_RECOVERY=true`):
  the entries of a submenu would come out invisible. The kernels stay in the main menu: the
  **backup 6.12 is a direct entry**.
- **Safety check** (`construir.py`): it counts the entries in two different ways
  (following the braces `{ }` of `grub.cfg` and counting all the `menuentry` lines). If they do not
  match, or there is a submenu, **it disables the theme** (`theme.txt` → `theme.txt.desactivado`) and
  GRUB uses the text menu: never a background with names that do not correspond.
- **The countdown is the only thing GRUB writes**: a `__timeout__` label with
  `fa-hourglass-half` of the Nerd Font (`U+F252`) and `%d`, in 1 bit. It disappears when a key is pressed.
- **Fonts**: Void's GRUB does not bring `grub-mkfont` (it is built without FreeType). `ttf2pf2.py`
  replaces it: it draws each character with FreeType (Pillow) in 1 bit and writes the PF2 format.
  `leer_pf2.py` reads and draws it (it was validated against `/usr/share/grub/unicode.pf2`). There are 16 px
  (console `c` and editor `e`) and 20 px (the countdown, with the clock icons).
- `GRUB_GFXMODE=1366x768,auto`: since 2026-10-03 the installer takes it from the panel
  (`/sys/class/drm/card*-eDP-*/modes`) and `construir.py` scales the theme by height/768 and puts the
  machine's name, to work also on the Legion (1920×1200). **Here it comes out identical**
  (checked byte by byte; Legion recipe, step 8). The positions are designed for 1366×768.

**What was tried and does NOT work in this GRUB** (do not repeat):
- **Progress bars with images** (`highlight_style`): the bar's background is drawn,
  but the image fill does not appear. It was tried with numbers and phrases as images: the
  number stayed fixed at 5.
- **Color bar with a frame**: the frame came out fine, but the bar inside was seen as
  a ~2 px line at the bottom (neither making it taller nor without overlapping it with the frame). The bar
  alone, 4 px and without a frame, did work.
- **GRUB's bar only grows from the left**: it cannot be made to empty towards the
  left, not even with several overlapping bars.
- **The first entries reader skipped "UEFI Firmware Settings"** (it goes indented inside an
  `if`) and the background ended up with one name less: the third row booted something else. Hence the
  reader by braces and the safety check.

Scripts in `fish/void/grub-tema/` (`construir.py`, `ttf2pf2.py`, `leer_pf2.py`,
`instalar-tema.sh`). Preview without installing anything: `python3 construir.py carpeta "Entrada 1"
"Entrada 2" … --vista vista.png` (folder, "Entry 1", "Entry 2", --preview). **Verified on 2026-10-02** on the real boot: entries
sharp and in their place, stable box, the countdown goes down and disappears when a key is pressed,
and the first entry boots the 6.18.

### 9. Desktop software and themes

Everything that the Xfce configuration (step 13) and the login screen (step 10) take for
granted. **It goes before them:** if a theme, a font or a plugin does not exist when the
configuration is restored, Xfce falls back to the default.

```bash
sudo xbps-install -Sy xterm xrdb xprop xdotool librsvg-utils ImageMagick fastfetch \
  xfce4-docklike-plugin xfce4-clipman-plugin papirus-icon-theme papirus-folders \
  sassc gtk-engine-murrine xfce4-screensaver xfce4-screenshooter btop blueman \
  adwaita-fonts twemoji noto-fonts-ttf libspa-bluetooth
```

| Package | What for |
|---|---|
| `xterm`, `xrdb`, `xprop`, `xdotool` | the terminal (step 11); `xrdb` loads `.Xresources`; `xdotool` does several shortcuts (step 13) |
| `librsvg-utils`, `ImageMagick` | generate xterm's icon from Papirus (step 11) |
| `fastfetch` | the greeting (step 12) |
| `xfce4-docklike-plugin`, `xfce4-clipman-plugin` | dock and clipboard in the panel (they do not come with `xfce4`) |
| `papirus-icon-theme`, `papirus-folders` | icons and teal folders |
| `sassc`, `gtk-engine-murrine` | build Orchis / GTK2 apps |
| `xfce4-screensaver` | **without it `xflock4` locks nothing** (shortcut Super+Ctrl+L). Only in Xfce X11: on Wayland it does not start (step 15) |
| `xfce4-screenshooter`, `btop`, `blueman` | Print, Super+Ctrl+T, Super+Ctrl+B |
| `adwaita-fonts`, `twemoji`, `noto-fonts-ttf` | symbols and emoji that JetBrains does not have (see *Fonts*) |
| `libspa-bluetooth` | Bluetooth audio in PipeWire (see *Bluetooth*) |

`xfce4-pulseaudio-plugin` and `pavucontrol` already come with the ISO.

#### Bluetooth: blueman in the panel

`blueman` (above; it drags in `bluez`) puts its icon in the tray of the top panel, next to the
network one: its `blueman-applet` starts with the session (`/etc/xdg/autostart/blueman.desktop`).
**With that alone it does not work:** the service is missing and it comes blocked.

```bash
sudo ln -s /etc/sv/bluetoothd /var/service/
sudo sh "<disco>/Backups Linux/fish/void/bluetooth/bluetooth-al-arrancar.sh"   # unblocks, now and on every boot
sleep 3; bluetoothctl system-alias ideapad-100      # the name the others see (see below)
```

- **`bluetoothd` does not come enabled** on Void; without it the icon has nothing to show.
- **It came blocked by software** (rfkill: `hci0` and `ideapad_bluetooth`); not by hardware.
  **And it gets blocked again:** the block of `ideapad_bluetooth` is kept by the laptop's
  firmware (`persistent=1`; `hci0` inherits its state when it appears), and after a reboot on
  2026-10-02 it came back blocked (with `bluetoothd` running: the service does start). It is not known
  what blocked it (the firmware, blueman at shutdown or the Windows on the XS1000). That is why
  **`bluetooth-al-arrancar.sh`** ("bluetooth at boot") adds to **`/etc/rc.local`** a block marked `# >>> bluetooth
  al arrancar` with `rfkill unblock bluetooth` (it leaves `rc.local.bak`; `--quitar` removes it).
  `rc.local` is what Void's manual (`void-docs`, *rc files*) gives for boot commands
  before login: runit runs it in stage 2, before the services, and it is a configuration
  file (it survives updates). The manual's Bluetooth page asks for the same:
  `rfkill unblock bluetooth`. Turning it off from blueman still works; on reboot it comes back
  on. Check with `rfkill`: `desbloqueado` (unblocked) in both bluetooth lines.
  **Verified on 2026-10-02** with a reboot: both unblocked and the adapter on
  (`bluetoothctl show` → `Powered: yes`).
- **Audio: `libspa-bluetooth`** (in the list above). Without it the headphones pair and
  connect but PipeWire does not see them as an output: nothing sounds. After installing it with the session
  open the audio has to be restarted (or log out): `pkill -x wireplumber; pkill -x
  pipewire` and launch `pipewire` again (it starts `wireplumber` and `pipewire-pulse`). **The
  programs that already had audio (Firefox) lose the connection:** reload the tab or
  reopen them.
- **The `bluetooth` group is not needed:** bluez's D-Bus policy lets any user use it.
- **Hardware:** it is the Bluetooth part of the same chip as the Wi-Fi (`RTL8723B Bluetooth`, USB
  `0bda:b728`, `hci0`), with its firmware already in `linux-firmware` (`rtl_bt/rtl8723b_fw.bin`).
  **It shares the antenna with the Wi-Fi on 2.4 GHz:** on without being used it was not noticed (60 s: median
  3.1 ms, p95 9.4 ms, no ping > 30 ms). With audio, without the driver's options there were
  stalls of 3–19 s; **with `fwlps=0 ips=0` (step 4), 30 min of video through the headphones without a
  single stall** (p95 43 ms: what sharing the antenna costs).
- **Name: `ideapad-100`** (2026-10-02). From the factory it announced itself as "BlueZ 5.86" (bluez
  takes it from `systemd-hostnamed`, which Void does not have). The adapter's **alias** was changed, without
  sudo: `bluetoothctl system-alias ideapad-100` (bluez saves it in `/var/lib/bluetooth/` and
  it survives the reboot; `bluetoothctl show` → `Alias: ideapad-100`, even if `Name` still
  says "BlueZ 5.86"). In a reinstall, repeat that command. Alternative with sudo:
  `Name = ideapad-100` in `/etc/bluetooth/main.conf`.

**Pairing headphones:** headphones in pairing mode → Bluetooth icon →
*Dispositivos…* (*Devices…*) (or Super+Ctrl+B) → *Buscar* (*Search*) → right click → *Emparejar* (*Pair*) → *Conectar* (*Connect*) →
*Audio Sink*. They stay as trusted and reconnect by themselves when turned on; the profile must be
`a2dp-sink` (the call one sounds like a phone). If the sound stays on the speakers, choose them
in the volume icon. **Verified on 2026-10-02** with some Skullcandy Method 360 ANC
(`@HEADPHONES_BT_MAC@`): test sound and Firefox.

**Controller:** an **Xbox Wireless Controller** (`@XBOX_CONTROLLER_BT_MAC@`) is also paired, like
any other Bluetooth device (controller in pairing mode → *Buscar* → *Emparejar*). It
needs no special step.

#### Fonts

```bash
mkdir -p ~/.local/share/fonts
cp "<disco>/Backups Linux/fish/void/fonts/"*.ttf ~/.local/share/fonts/
cp -r "<disco>/Backups Linux/fish/void/xterm/jetbrains-blocks" ~/.local/share/fonts/
chmod +x ~/.local/share/fonts/jetbrains-blocks/regenerar.sh
fc-cache -f ~/.local/share/fonts
```

- **The whole JetBrainsMono Nerd Font family, the same as on the Legion** (2026-10-02): 6
  families × 16 styles = 96 files (`Nerd Font`, `Nerd Font Mono` and `Nerd Font Propo`, each
  one also in the `NL` version, without ligatures), backed up in `fish/void/fonts/` (233 MB; in this
  repository, the Release asset `jetbrains-mono-nerd-font-ttf.tar.gz`, unpacked into `common/fonts/` by
  `install/fetch-assets.sh`).
  Identical to the Legion's (SHA-256 of the set). The icons of fastfetch and of the prompt
  are glyphs of the `Mono`. (The Fedora backup, `fish/fedora-atomic/fonts/`, only has 4.)
- **JetBrainsMono NFM Blocks**: the patched copy that seals the rows of `█` in xterm
  (step 11). **It is also the font of the whole desktop** (step 13) and of the login
  screen (step 10). Its base fonts are identical (SHA-256) to the Legion's.

**No JetBrains variant has `⏺` (U+23FA) nor `⎿` (U+23BF)**, the symbols that Claude
Code puts in front of each answer and each result, **nor the emoji**: checked in the
four (normal, Mono, Propo and the patched one). Without another font that has them, xterm draws a
**crossed-out box**. On the Legion they are seen because fontconfig takes them from other fonts; here
the same ones are installed (in the package block above):

| Package | Draws | Equivalent on the Legion (Arch) to |
|---|---|---|
| `adwaita-fonts` | **⏺ and ⎿** (Adwaita Mono) and many symbols | `adwaita-fonts` |
| `twemoji` | emoji (✅ 📁…) | `ttf-twemoji-default` |
| `noto-fonts-ttf` | symbols and alphabets in general (🔒 comes from Noto Sans Symbols 2) | `noto-fonts` |

Check where each symbol comes from (the same as the terminal):
`fc-match "JetBrainsMono NFM Blocks:charset=23fa" family` → `Adwaita Mono` (the same with `23bf`).

- **The emoji come out in black and white in the terminal, as the user prefers.** Void's Twemoji
  is `TwitterColorEmoji-SVGinOT.ttf`: the color goes in SVG and it brings a black and white
  fallback version, which is the one FreeType (xterm) draws. Only programs that understand the
  SVG, like Firefox, would see them in color.
- **The Twemoji fontconfig rule that the Legion has is not set** (`75-twemoji.conf`, from the
  Arch package): it was tried and it only changed **which black and white design** comes out for
  some symbols (🔒 outlined, from Twemoji, instead of filled, from Noto), and it is one more file
  to evaluate in each font lookup. The user's decision: the cheapest.
- **`noto-fonts-cjk`** (Chinese, Japanese, Korean; several hundred MB) is on the Legion but
  **was not installed here**. It is not needed for these symbols.
- xterm windows already open do not take new fonts: open a new one.

#### Icons: Papirus-Dark with teal folders

**Icon theme: Papirus-Dark**, as on the Legion. It is chosen in *Configuración → Apariencia → Iconos*
(*Settings → Appearance → Icons*) (or step 13 leaves it set) (`xfce4-appearance-settings`; the full settings
manager is `xfce4-settings-manager`). Over SSH, the active one is seen with
`xfconf-query -c xsettings -p /Net/IconThemeName` (with the session's `DBUS_SESSION_BUS_ADDRESS`,
see step 13, *xfce4-terminal*).

```bash
sudo papirus-folders -C teal --theme Papirus-Dark
readlink /usr/share/icons/Papirus-Dark/48x48/places/folder.svg     # folder-teal.svg
```

**Teal folders** with `papirus-folders` (official on Void). It only changes the color of the
**folders**; the rest of the icons (the terminal's, for example) do not change. It works by
changing links inside `/usr/share/icons/Papirus*`, which are files of the package:
**when `papirus-icon-theme` is updated the folders may go back to the default color**, and
then `sudo papirus-folders -C teal --theme Papirus-Dark` has to be repeated. Checkable
with `readlink /usr/share/icons/Papirus-Dark/48x48/places/folder.svg` → `folder-teal.svg`.
It may be necessary to choose the theme again or restart the session for Thunar and the
desktop to reload.

**The application finder (`xfce4-appfinder`) stays resident** when it is closed, and keeps
the icons it loaded at start: after switching to Papirus it still showed the
Adwaita ones. It is fixed by killing it (`pkill -x xfce4-appfinder`) or logging out; the next
time it starts from scratch with the new theme. **Verified on 2026-10-02.**

#### GTK and window theme: Orchis, dark teal

**Orchis is not in Void's repositories** (there is no `orchis-theme` or similar). It is installed
from its official repository with its own `install.sh`, in `~/.themes` (without sudo):

**To reinstall as it is, restore the copy** (the six variants that `install.sh` left
on 2026-10-02, 0.6 MB, in `fish/void/xfce/orchis-themes.tar.gz`; relative paths, checked):

```bash
mkdir -p ~/.themes && tar xzf "<disco>/Backups Linux/fish/void/xfce/orchis-themes.tar.gz" -C ~/.themes/
ls ~/.themes      # Orchis-Teal-Dark, -Compact, -hdpi, -xhdpi, -Compact-hdpi, -Compact-xhdpi
```

This is how it was generated (and how it is updated, to a newer version):

```bash
sudo xbps-install -Sy sassc gtk-engine-murrine
git clone --depth 1 https://github.com/vinceliuice/Orchis-theme.git /tmp/Orchis-theme
cd /tmp/Orchis-theme && ./install.sh -t teal -c dark
cd ~ && rm -rf /tmp/Orchis-theme
```

After updating it, redo the copy: `tar czf "<disco>/Backups Linux/fish/void/xfce/orchis-themes.tar.gz" -C ~/.themes .`
(and the system's one for the login screen, step 10).

- `sassc` (official) generates the theme's CSS from its SCSS: it is not building a program, but
  it is a local build step. `gtk-engine-murrine` (official) is for GTK2 apps.
- `-t teal -c dark`: teal accent (matching the folders) and dark background. Other accents:
  `default` (blue), `purple`, `pink`, `red`, `orange`, `yellow`, `green`, `grey`, `all`;
  brightness `standard`, `light`, `dark`. Optional tweaks with `--tweaks` (`solid`, `compact`,
  `black`, `primary`, `macos`, `submenu`, `nord`, `dracula`).
- It installs `Orchis-Teal-Dark` and its variants `-Compact`, `-hdpi` and `-xhdpi`. **The user
  chose `Orchis-Teal-Dark-Compact`** in both places: *Configuración → Apariencia →
  Estilo* (*Settings → Appearance → Style*) (GTK) and *Configuración → Gestor de ventanas → Estilo* (*Settings → Window Manager → Style*) (xfwm4; Orchis brings a theme
  for it).
- **It is not updated with `update-system`:** it is not a package. To update it, repeat the
  `git clone` and the `install.sh`. Latest version when installing: 2026-07-07.
- **GTK4/libadwaita** (GNOME apps) ignore it unless installing with `-l`, which links it in
  `~/.config/gtk-4.0`. It was not done.

Over SSH: `xfconf-query -c xsettings -p /Net/ThemeName` and `-c xfwm4 -p /general/theme`.

#### Cursor: Volantes (dark)

**Volantes is not in Void's repositories**, and the project
(`github.com/varlesh/volantes-cursors`) does not publish built versions on GitHub: its
`build.sh` draws the SVGs with **Inkscape** and packages them with `xcursorgen`. **On
2026-10-02 Void's `inkscape` package was broken** (`broken, unresolvable shlib
libpoppler.so.164`: poppler was updated and Inkscape had not been rebuilt yet), so
xbps aborted without installing anything. **The already built version** that the project links was used,
downloaded by hand from xfce-look.org (pling): `volantes-cursors.tar.gz`, only the dark
variant, `volantes_cursors` (SHA-256 `c4da5080…b172`). **Backed up** in
`fish/void/xfce/volantes-cursors.tar.gz` (in this repository, a Release asset).

```bash
T="<disco>/Backups Linux/fish/void/xfce/volantes-cursors.tar.gz"
tar tzf "$T" | grep -E '^/|(^|/)\.\.(/|$)'    # nothing: relative paths
mkdir -p ~/.local/share/icons && tar xzf "$T" -C ~/.local/share/icons/
```

Before unpacking it was checked that there are no absolute paths nor links that go out of its
folder. 148 cursors remain (56 files + links), without broken links. It is chosen in
*Configuración → Ratón y panel táctil → Tema* (*Settings → Mouse and Touchpad → Theme*) ("Volantes Cursors"); over SSH,
`xfconf-query -c xsettings -p /Gtk/CursorThemeName` → `volantes_cursors`. Some apps already
open do not change cursor until they are restarted.

**If some day one wants to build it** (for example, the light variant `volantes_light_cursors`)
with Inkscape already fixed: `sudo xbps-install -Sy inkscape xcursorgen make`, clone the
repository, `make build && make install PREFIX=$HOME/.local` (its `make install` goes to `/usr`
with sudo if it is not given `PREFIX`), and then Inkscape can be removed (192 MB). While
Inkscape stays broken, the alternative that was considered and not done: a fake `inkscape` in the
`PATH` that passes to `rsvg-convert` the calls `inkscape -o OUT -w N -h N IN.svg` of
`build.sh` (it is not the project's documented process).

#### Panel plugins

**The dock-like bar ("Docklike Taskbar") is a separate plugin**, `xfce4-docklike-plugin`:
the `xfce4` metapackage does not bring it (it is installed above), and without it, it does not appear in the list to
add. It is added in *Panel → Preferencias del panel → Elementos → +* (*Panel → Panel Preferences → Items → +*) (after `xfce4-panel -r`),
**or the panel configuration of step 13 leaves it set**. It is in the top panel, in the
place of the window list (`tasklist`).

**Clipman** (clipboard history) is another separate plugin, like the dock (package
`xfce4-clipman-plugin`, above); and it is added from *Elementos → +* as "Clipman".

**Volume in the panel:** the `xfce4-pulseaudio-plugin` plugin **already comes with the Xfce ISO**,
but it is not in any panel: it is added from *Elementos → +* ("Complemento de audio
PulseAudio" — "PulseAudio Plugin"). It works with PipeWire without touching anything: Void brings it with its PulseAudio-compatible
server (`/etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf`; `pactl info` →
`PulseAudio (on PipeWire 1.6.8)`). The full mixer it opens, `pavucontrol`, also
comes installed.

### 10. Login screen (lightdm-gtk-greeter) with the same look

**With the autologin of step 14 it is almost never seen**: it only comes out when logging out (Super+Escape →
Cerrar sesión / Log Out) or if the autologin is removed (`instalar-cambio-sin-contrasena.sh --quitar`).
From it, log in only to "Xfce Session" (X11): the Wayland sessions get lost if one logs in from
the login screen (step 14, *What it cost* 2).

The greeter **runs as the user `lightdm`** and `~` is `700`: it sees nothing of what is installed in
the home folder (Orchis, Volantes, the patched font). It has to be copied to the system and
told in `/etc/lightdm/lightdm-gtk-greeter.conf` (backed up in
`fish/void/xfce/lightdm-gtk-greeter.conf`):

```bash
sudo cp -r ~/.themes/Orchis-Teal-Dark-Compact /usr/share/themes/
sudo cp -r ~/.local/share/icons/volantes_cursors /usr/share/icons/
sudo mkdir -p /usr/local/share/fonts/jetbrains-blocks
sudo cp ~/.local/share/fonts/jetbrains-blocks/*.ttf /usr/local/share/fonts/jetbrains-blocks/
sudo fc-cache -f /usr/local/share/fonts/jetbrains-blocks
sudo cp /etc/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf.bak
sudo cp "<disco>/Backups Linux/fish/void/xfce/lightdm-gtk-greeter.conf" /etc/lightdm/
```

```ini
[greeter]
indicators = ~host;~spacer;~clock;~spacer;~layout;~session;~a11y;~power
theme-name = Orchis-Teal-Dark-Compact
icon-theme-name = Papirus-Dark
cursor-theme-name = volantes_cursors
font-name = JetBrainsMono NFM Blocks Bold 10
xft-dpi = 96
xft-hintstyle = hintfull
xft-rgba = none
background = /usr/share/backgrounds/xfce/xfce-x.svg
```

- **The values are the session's:** `xfconf-query -c xsettings` gave `/Gtk/FontName` =
  `JetBrainsMono NFM Blocks Bold 10`, `/Xft/HintStyle` = `hintfull`, `/Xft/RGBA` = `none`,
  `/Xft/DPI` = 96 (`/Xft/Antialias` = -1, the default: it is not set). The
  `indicators` line is the one the file brought.
- **The background** was never chosen by hand, so it is xfdesktop 4.20's default:
  `xfce-x.svg` (it comes from the `xfdesktop` binary itself; the `xfce4-desktop` channel has the
  `last-image` that xfdesktop writes by itself, with that same path, and the icons off). If
  the desktop's background is changed, also change `background`.
- **Why each path:** the theme in `/usr/share/themes` and the cursor in `/usr/share/icons`
  because X cursors **are not searched for in `/usr/local`** (only `~/.local/share/icons`,
  `~/.icons`, `/usr/share/icons`, `/usr/share/pixmaps`); the font does go in
  `/usr/local/share/fonts`, which fontconfig searches by default and stays outside xbps.
  **They are copies:** when updating Orchis, Volantes or regenerating the patched font in the
  home folder, they have to be copied again.
- Check that the greeter sees the font without the home folder:
  `HOME=/nonexistent fc-match "JetBrainsMono NFM Blocks:bold"`.
- Graphical alternative: `lightdm-gtk-greeter-settings` (official, not installed); the copies to the
  system are needed anyway.

**Top bar of the greeter in black**, like the session's `panel-1` (which does not use the
theme's color: own black opaque background, `background-style` = 1, RGBA 0,0,0,1; Orchis paints
`#panel_window` transparent). It is done with GTK's user CSS **of the user
`lightdm`** (its home is `/var/lib/lightdm`; GTK loads `~/.config/gtk-3.0/gtk.css` on top
of the theme), backed up as `fish/void/xfce/lightdm-gtk.css`:

```bash
sudo -u lightdm mkdir -p /var/lib/lightdm/.config/gtk-3.0
sudo -u lightdm cp "<disco>/Backups Linux/fish/void/xfce/lightdm-gtk.css" /var/lib/lightdm/.config/gtk-3.0/gtk.css
```

Content: `#panel_window { background-color: #000000; }` and, so that the texts of the
bar (machine, clock, menus) use the panel clock's font, `#panel_window label` with
`JetBrainsMono NFM Blocks`, bold, 10 pt (without this, Orchis thins them with weight 500). They are
the same two rules that the user's `gtk.css` has for the unlock screen
(step 13). If the color or the font of the session's panel is changed, change it here too.

**Verified on 2026-10-02** by eye by the user: theme, icons, cursor, font, size,
background and top bar the same as the session's.

### 11. xterm, configured as on the console, and default terminal

Same xterm as on the Legion (its recipe, §13): Super Game Bro palette, the patched copy
of the font that seals the blocks and login shell (the size here is another one, 108x35). **Without everything that there was
because of Steam and gamescope:** neither the `xterm-steam-fix` wrapper (`LD_PRELOAD`, `LC_ALL=C`,
`DISPLAY=:0`, size according to the dock's DPI, forced antialiasing), nor the Steam
shortcut, nor the cursor. No Sixel either, the same as there.

```bash
X="<disco>/Backups Linux/fish/void/xterm"
mkdir -p ~/.local/bin ~/.local/share/icons ~/.config/xfce4
cp "$X/Xresources" ~/.Xresources
cp "$X/xterm-papirus.xpm" ~/.local/share/icons/
cp "$X/helpers.rc" ~/.config/xfce4/helpers.rc
cp "$X/xprofile" ~/.xprofile
cp "$X/xdg-terminal-exec" ~/.local/bin/ && chmod +x ~/.local/bin/xdg-terminal-exec
xrdb -nocpp -merge ~/.Xresources       # for this session; from the next one lightdm does it (in Xfce Wayland, labwc's autostart, step 15)
```

Packages and patched font: step 9.

**`xrdb` does not come with Void (it is installed in step 9) and without it nothing is loaded.** `/etc/lightdm/Xsession` already does
`xrdb -nocpp -merge ~/.Xresources` when logging in (the autostart that
Plasma needed is not needed), but if the program is not there, it skips it without saying anything and xterm comes out with its
default look. `xprop` and `xdotool` are only for measuring.

**Geometry: `108x35`** (868×634 px), chosen by the user on 2026-10-02; at first
it was `137x39` (1100×706), the Legion's. Xfce sets `Xft.dpi: 96`, and at 10 pt the cell measures
8×18 px with a 4 px border, as there: width = columns × 8 + 4, height = rows × 18 + 4.
Measured with `xdotool getwindowgeometry` → **868×634**; `xprop WM_NORMAL_HINTS` → increment
8×18, base 4×4. The usable area is 1366×741 (`_NET_WORKAREA`; the top panel takes 27 px and
the bottom one always hides).

**The patched copy of the font comes from the same base fonts:** the four
`JetBrainsMonoNerdFontMono-*.ttf` of the ideapad are identical (SHA-256) to the Legion's,
so the `JetBrainsMonoNFMBlocks-*.ttf` are copied as they are. If some day the
Nerd Font is updated, regenerate them with `regenerar.sh` of the same folder (it asks for `fonttools` in a
venv; see §13.14 of the console's recipe).

**Window icon: Papirus's, the same as the menu and the dock.** The one of the title
bar and Alt+Tab is set by `xterm` itself (in `WM_HINTS`), not by the `.desktop`, and **xfwm4, unlike
Plasma, does not replace it** with the `.desktop`'s (on the Legion
`StartupWMClass` was enough, §13.5). `xterm` takes it from `XTerm*iconHint`, **and only in XPM**. It is restored
from the backup (above). **This is how it was generated**, from the SVG that Papirus uses for `xterm-color`
(`utilities-x-terminal.svg`), and this is how it is redone if the icon theme changes:

```bash
rsvg-convert -w 48 -h 48 -o /tmp/xterm-papirus.png \
  /usr/share/icons/Papirus-Dark/48x48/apps/utilities-x-terminal.svg
magick /tmp/xterm-papirus.png ~/.local/share/icons/xterm-papirus.xpm
rm /tmp/xterm-papirus.png
```

and in `.Xresources`: `XTerm*iconHint: /home/isaac/.local/share/icons/xterm-papirus.xpm`.
`rsvg-convert` is the same engine with which Xfce draws Papirus; it is done in two steps because
it was not checked that Void's ImageMagick reads SVG directly. The XPM's transparency is
1-bit (somewhat harder edges). **It does not follow the theme:** if the icon theme is changed, it has
to be regenerated (and backed up again in `fish/void/xterm/`). **Verified on
2026-10-02** with `xprop WM_HINTS` (icon and mask loaded).

**Void's `.desktop` already works:** it brings `Icon=xterm-color_48x48` and `StartupWMClass=XTerm`,
which is precisely what on the Legion had to be added by hand. There is no own copy in
`~/.local/share/applications/`.

**Copy and paste:** the `.Xresources` carries an `XTerm*VT100.translations` line that makes
**Ctrl+Shift+C** or **Ctrl+Insert** copy the selection to the clipboard and **Ctrl+Shift+V**
paste from it; the selection with the mouse still goes to *PRIMARY* (middle click /
Shift+Insert). Without it, `xterm` does not copy with the keyboard and those keys reach the program
as sequences (`^[[2;5~`…), which fish may type as they are. It goes in a single line so
that it works loaded with and without `cpp` (here `-nocpp`, on the Legion with `cpp`). Details and the
Claude Code trap (which copies on its own and makes it look like `xterm` already knew how): §13.4
of the console's recipe. **Verified on 2026-09-30** by the user, over SSH.

**Shift+Insert pastes from the clipboard** (2026-10-03), not from the mouse selection as xterm brings
by default: with Ctrl+Insert copying to the clipboard and Shift+Insert pasting from PRIMARY, the pair
did not match. It goes in the same `translations` line (`Shift <Key>Insert: insert-selection(CLIPBOARD)`);
what is selected with the mouse is pasted with the **middle click**.

**Copying from Claude Code over SSH (OSC 52, 2026-10-03).** With Claude Code running on another
machine over SSH (e.g. from the Legion, `ssh ideapad` and `claude`), Claude Code cannot use the
local machine's clipboard: it sends it with the **OSC 52** sequence, which xterm **blocks by
default** (`disallowedWindowOps` of xterm 411: `GetChecksum,GetIconTitle,GetSelection,GetWinTitle,
SetSelection,SetXprop`). The `.Xresources` carries that list **without `SetSelection`**: programs
can *put* text on the clipboard, but not *read* it (`GetSelection` is still forbidden). Besides,
Claude Code captures the mouse: to select with xterm on top of it, **Shift + drag**, and
then Ctrl+Shift+C. It applies to new xterm windows.

**Backspace (added on 2026-10-01).** Without `XTerm*backarrowKey: false`, Backspace sends
`^H` and the terminal has `stty erase = ^?`. fish understands both and in its prompt it is not
noticed, but everything that reads **in line mode** — xbps's `[Y/n]`, `sudo`'s password,
bash's `read` (fish's not: it uses fish's editor) — does not recognize `^H` and **types** it (`a^H^H^H`) instead of deleting. Over SSH the same: the
remote session inherits the local terminal's `erase`. With the line, Backspace sends `^?` and
they match. **Measured** in a test xterm (`stty raw` + `od -c`, key with `xdotool`):
before `\b`, after `177` (`^?`). On the ideapad `xdotool` does not work for this (xterm ignores
synthetic keys); the user checked it by hand, locally and over SSH.

**Selecting more than what is seen: a limit of `xterm` (noted on 2026-10-01).** When
dragging with the left button, `xterm` **does not scroll by itself** when reaching the top
or bottom edge (it does not have that function; the manual does not mention it and there is no resource that
enables it), and **the wheel with the button pressed does not scroll** nor lets the selection continue. It
was tried adding `Button1 <Btn4Down>: scroll-back(5,line,m)` and `Button1 <Btn5Down>:
scroll-forw(5,line,m)` to the `translations` line, on the Legion and on the ideapad, and **nothing
changed**: it was removed. `xterm`'s own way is another one: left click at the start
(release), scroll with the wheel and **right click** at the end, which extends the selection
(`start-extend`). The user does not use it and **prefers to keep `xterm`** anyway. foot or
xfce4-terminal probably do drag against the edge, but it was not checked.

**Shell:** `XTerm*loginShell: true` starts a login bash → `.bash_profile` → `.bashrc`
→ `exec fish` (step 5).

#### Default terminal for everything

In Xfce there are three ways by which something opens a terminal, and each one is configured
separately:

| What | How it chooses the terminal | Setting |
|---|---|---|
| Ctrl+Alt+T, panel launcher, Thunar's "Abrir terminal aquí" ("Open Terminal Here"), menu programs with `Terminal=true` | `exo-open --launch TerminalEmulator` | `~/.config/xfce4/helpers.rc`: `TerminalEmulator=xterm` (the same as *Aplicaciones preferidas* / *Preferred Applications*) |
| GTK apps that launch a `.desktop` with `Terminal=true` | GLib first tries `xdg-terminal-exec` and then a fixed list where **xfce4-terminal goes before xterm** | `~/.local/bin/xdg-terminal-exec`, a three-line substitute (Void does not package the real one) |
| Scripts that read `$TERMINAL` | the variable | `~/.xprofile`: `TERMINAL=xterm` |

`~/.xprofile` also puts `~/.local/bin` in the `PATH` **of the graphical session**, which is
where GLib looks for it: fish's `PATH` does not count. `/etc/lightdm/Xsession` loads it, so
GLib's way starts to work **after logging out and logging back in**.

xfce4-terminal stays installed (the `xfce4` metapackage depends on it), but it is no longer used.

**Default browser: Firefox.** What opens links (`exo-open --launch WebBrowser`,
Super+Shift+B, the `http(s)` of any app) comes from `~/.config/mimeapps.list`, which
Firefox itself writes: open Firefox → *Ajustes* (*Settings*) → *General* → **Hacer predeterminado** (**Make Default**) (it creates
`~/.local/share/applications/userapp-Firefox-*.desktop` and associates it with `http`, `https` and
`text/html`). Check: `xdg-mime query default x-scheme-handler/https` → `userapp-Firefox-….desktop`.

**Verified on 2026-09-30:** `exo-open --launch TerminalEmulator` opens `/usr/bin/xterm`, and
`gio launch` of a `.desktop` with `Terminal=true` opens `xterm -e <command>`. By eye, the
user confirmed it fine; the concrete test of blocks without stripes was not noted separately.

### 12. fastfetch with Omarchy's style

Same style as on the console (step 15 of its recipe) and as on the previous Fedora (step
13 of its own): three framed sections, keys in a tree and one color per section.

It needs the Nerd Font and `fastfetch` (step 9); `fish_greeting` launches it (step 6).

```bash
mkdir -p ~/.config/fastfetch
cp "<disco>/Backups Linux/fish/void/fastfetch/gen-config.py" ~/.config/fastfetch/
python3 ~/.config/fastfetch/gen-config.py
```

As always: the generator is edited, not `config.jsonc`, because the icons go as
`\uXXXX` escapes that the editors do show.

**Differences with the Fedora version:**
- **Big Void logo**, the default one, following the decision that was made with the Fedora one.
- **Void logo, ``** (Nerd Fonts, distribution logos group), in the OS
  line. The packages one (`xbps: N`) carries a **box** (`\U000f03d7`, closed package), at the user's
  request. They came inherited from the console: Steam's (``) in the OS and **Arch**'s
  (``, the line was `pacman`) in the packages; corrected on 2026-10-02 (the glyphs were
  checked by drawing them with `magick` and in fastfetch's output).
- **Icons of the Software lines adapted to Void** (2026-10-02): the mirror one carries a
  **server** (`\U000f048b`) and the `glibc · runit` one, **gears** (`\U000f08d6`). They came from
  the console, where those lines were SteamOS's branch (branch icon, `\U000f062c`) and the
  build (a **traffic light**, `\U000f052b`), which made no sense here.
- **Software:** `Void Linux (rolling)`, the mirror (from `xbps-query -L`), `glibc <version> ·
  runit`, and the packages in a single line `xbps: N`, because here there is neither Homebrew nor
  Flatpak.
- **Disk:** `folders="/"`. With `/home` the line does not come out, because on Void it is not a
  mount point.
- **"Instalado"** ("Installed") with `stat -c %W /home` (btrfs keeps the creation date).
- **"Actualizado"** ("Updated") is the date of the **last `update-system` that ended fine**: it writes it
  itself in `~/.local/state/update-system.last` (added on 2026-10-02; xbps keeps no history).
  If that file does not exist, it uses the date of `/var/db/xbps/pkgdb-0.38.plist`, which **changes with
  any installation**. It shows only `hace N días (dd-mm-aaaa)` ("N days ago (dd-mm-yyyy)"), with no more text (the user's
  preference). Before it always used the pkgdb and said "hace 0 días" ("0 days ago") after installing any
  thing.
- **"Pendiente"** ("Pending") counts what `xbps-install -un` would give against the repodata of the last sync
  (syncing requires root, so the greeting does not do it).
- Colors: `bright_cyan`, `bright_white` and `bright_yellow`, with `\e[32m` frames, as on the
  console (and with sense here: the ideapad's xterm has the same Super Game Bro palette).
- **Reviewed against the system on 2026-10-02** (that nothing was a copy of Omarchy or of the
  console): `showPeCoreCount` was removed from the CPU (P/E cores of modern Intel; the i3-5005U does not
  have them); the init system of the `glibc · runit` line is read from `/proc/1/comm` instead of
  being written by hand; the **palette** paints the **16 colors** of the xterm (30–37 and 90–97) instead
  of the 11 copied from the console. Everything else comes from real data (machine, GPU, screen,
  btrfs disk on `/`, mirror from `xbps-query -L`, glibc from `ldd`, xbps, fish, xterm, the font
  `JetBrainsMono NFM Blocks (10pt)`), checked by running fastfetch inside an xterm.

**Verified on 2026-09-30:** over SSH, all the rows except DE, WM, terminal and font, which
only exist inside the session; and by eye in the terminal, with icons and font fine.
(In this repository, `common/fastfetch/gen-config.py` writes its labels in the system's language: in
Spanish, the same as here.)

### 13. Xfce configuration (restore with the session closed)

**The whole Xfce configuration is backed up and is restored at once:** the xfconf
channels (`~/.config/xfce4/xfconf/xfce-perchannel-xml/`), the panel folder
(`~/.config/xfce4/panel/`: launchers and Docklike) and the GTK CSS (panel corners). That way
exactly the same themes, fonts, panels, shortcuts, focus, placement, power and
notifications remain, without repeating each click. It requires steps 9 to 12 done.

**With the graphical session closed**, because `xfconfd` rewrites those files on exit and
would overwrite what was copied: at the login screen, **Ctrl+Alt+F2**, log in on the console, and:

```bash
pkill -x xfconfd                                   # in case one was left
udisksctl mount -b /dev/sdb4                       # if Common is not mounted
X="<disco>/Backups Linux/fish/void/xfce"
mkdir -p ~/.config/xfce4/xfconf ~/.config/gtk-3.0
cp -r "$X/xfce-perchannel-xml" ~/.config/xfce4/xfconf/
cp -r "$X/panel" ~/.config/xfce4/
cp "$X/gtk.css" ~/.config/gtk-3.0/gtk.css
mkdir -p ~/.local/bin ~/.config/autostart && cp "$X/ventana-foco" "$X/ventana-acoplar" "$X/ventanas-nuevas" ~/.local/bin/ && chmod +x ~/.local/bin/ventana{-foco,-acoplar,s-nuevas}   # Super(+Shift)+arrows, new windows
cp "$X/ventanas-nuevas.desktop" ~/.config/autostart/
```

and go back to the login screen (**Ctrl+Alt+F7**) to log in. **To redo the backup**
after changing something of Xfce, copy those three things to the disk from the session (reading them does not require
closing it), without the `.bak`.
(The IdeaPad's Xfce configuration, `fish/void/xfce/`, is not in this repository; the Legion's, which is
this one with its own things, is `legion/xfce/`.)

What it contains, and why it is like that:

#### Desktop fonts and themes

| Setting | Value | Where it is chosen |
|---|---|---|
| GTK theme (`xsettings /Net/ThemeName`) | `Orchis-Teal-Dark-Compact` | Apariencia → Estilo (Appearance → Style) |
| Icons (`/Net/IconThemeName`) | `Papirus-Dark` | Apariencia → Iconos (Appearance → Icons) |
| Font (`/Gtk/FontName` and `/Gtk/MonospaceFontName`) | `JetBrainsMono NFM Blocks Bold 10` | Apariencia → Fuentes (Appearance → Fonts) |
| Antialiasing (`/Xft/*`) | `hintfull`, without subpixel (`rgba none`), 96 DPI | Apariencia → Fuentes |
| Cursor (`/Gtk/CursorThemeName`, size) | `volantes_cursors`, size 0 (the default) | Ratón y panel táctil → Tema (Mouse and Touchpad → Theme) |
| Window theme (`xfwm4 /general/theme`) | `Orchis-Teal-Dark-Compact` | Gestor de ventanas → Estilo (Window Manager → Style) |
| Title font (`xfwm4 /general/title_font`) | `JetBrainsMono NFM Blocks Bold 9` | Gestor de ventanas → Estilo |

The wallpaper is the default one (`xfce-x.svg`; in `xfce4-desktop` there is the `last-image` that xfdesktop writes). **No icons on the desktop** (2026-10-02, at the user's request): `/desktop-icons/style` = 0 (*Escritorio → Íconos → Tipo de ícono: Ninguno* — *Desktop → Icons → Icon type: None*; unset, the default is 2, file and launcher icons). The login screen (step 10) uses these same values.

#### Panels

**How they ended up (2026-10-02):**

| Panel | Plugins, in order |
|---|---|
| `panel-1` (top) | applications menu, separator, workspaces, separator, **Docklike**, separator, clock, separator, **Clipman**, **volume**, system tray, power, **Salir** (Exit) (launcher with the power icon) |
| `panel-2` (bottom, always hides) | show desktop, separator, 4 launchers, separator, folders menu |

It is read over SSH by going through `/panels/panel-N/plugin-ids` and `/plugins/plugin-<id>` of the
`xfce4-panel` channel.

**Docklike's options** (they do not go in xfconf, but in `~/.config/xfce4/panel/docklike-2.rc`,
which is backed up with the `panel/` folder), changed by the user on 2026-10-02:
`noWindowsListIfSingle=true` (no window list if the app has only one),
`onlyDisplayVisible=true` (only the windows of the current workspace),
`onlyDisplayScreen=true` (only those of this screen), `middleButtonBehavior=1` (middle-click
action) and `inactiveColor=rgb(94,92,100)` (indicator of the apps without focus).

The top panel has an **own opaque black background** (`background-style` = 1, RGBA 0,0,0,1);
the bottom one uses the theme's style and **always hides** (`autohide-behavior` = 2: it comes out when the
mouse is taken to the bottom edge; until 2026-10-03 it was 1, "intelligently", which in the
Wayland session of step 15 cannot work and the user preferred a single one for both). Power: the tray icon is
**hidden** (`xfce4-power-manager`, `show-tray-icon` = `false`), because the power plugin is already
in the panel. Notifications: history size limit enabled.

#### Top panel: active workspace, exit button and battery

**Active workspace: a white circle with the number in black**, and the others only with the
number. The workspaces plugin (`pager`, `plugin-20`) is in buttons mode
(`miniature-view` = `false`) and the active workspace is the **checked** button (`:checked`); in
xfce4-panel 4.20 each plugin is called in CSS `#<name>-<id>` (`libxfce4panel`), so it is
painted from `gtk.css` (see the list of rules below). With miniatures it would not be possible.

**Exit button with the greeter's power icon.** The **Actions** plugin draws
"Cerrar sesión" ("Log Out") with an icon fixed in its code (`xfsm-logout`). It was **replaced by a
Launcher** (`plugin-23`, in the same place) with `~/.config/xfce4/panel/launcher-23/salir.desktop` (`exit.desktop` in this repository's
`legion/xfce/`):
`Icon=system-shutdown-symbolic` (the one the login screen uses; in Papirus-Dark it is
`16x16/symbolic/actions/system-shutdown-symbolic.svg`) and `Exec=xfce4-session-logout`, which opens
the dialog with log out, reboot, power off and suspend (the same as Super+Escape). The
icon can be changed from the launcher's properties.

**Battery percentage with the clock's font.** The clock (`plugin-8`) has its font
set (`digital-time-font` = `JetBrainsMono NFM Blocks Bold 10`); the text of the power
plugin (`plugin-19`) does not, and it inherited the **weight 500** that Orchis gives to the panel's texts. It is
set in `gtk.css`. Measured: in the battery area there were 9 % more light pixels
(4192 → 4560) and the clock did not change.

#### Bottom panel: rounded corners

**There is no graphical option** in Xfce 4.20 for the panel's shape (*Preferencias del panel* (*Panel Preferences*) only
changes background, size, length and position). It is done with GTK CSS, in
`~/.config/gtk-3.0/gtk.css` (backed up in `fish/void/xfce/gtk.css`):

```css
#XfcePanelWindow.panel-2 {
    border-radius: 14px;
}
```

In xfce4-panel 4.20.7's code (`panel/panel-window.c`) each panel is a window with
CSS name `XfcePanelWindow` and the class `panel-<id>`, so the rule touches **only the bottom
panel** (`panel-2`, the launchers one; the Docklike is in the top one), not the top
one. It needs **xfwm4's compositor
active** (`xfconf-query -c xfwm4 -p /general/use_compositing` → `true`; in Xfce Wayland labwc composites and
it also comes out rounded) and that the panel uses
the theme's style (without its own color in *Apariencia → Fondo* / *Appearance → Background*). After changing it:
`xfce4-panel -r`. For more or less rounding, change the `14px`. **Verified on
2026-10-02** by eye by the user.

**The highlight of the buttons** (when hovering over the launchers, show desktop or the
folders menu) also goes rounded: `#XfcePanelWindow.panel-2 button` with
`border-radius: 12px` and **`margin: 2px`**. Without the margin, the buttons at the ends reach
the panel's edge and their corner sticks out square outside the curve; with 2 px they are
concentric (14 − 2 = 12). (First it was 4 px / 10 px; the highlight was enlarged at the
user's request.) The panel grows a bit in width (306 → 318 px).

**Panels' shadow off** (`xfwm4 /general/show_dock_shadow` = `false`, 2026-10-02):
xfwm4's compositor draws around the panels a **rectangular** shadow, which does not know
about the rounded corners and stuck out as a light semi-transparent square outside the
curve. Checked with enlarged screenshots of the corner before and after. It is
*Ajustes del gestor de ventanas, retoques → Compositor → Mostrar sombras bajo las ventanas
acopladas* (*Window Manager Tweaks → Compositor → Show shadows under dock windows*). The shadow of normal windows (`show_frame_shadow`) stays enabled. Verified on
2026-10-02 with screenshots (to capture the panel `/panels/panel-2/autohide-behavior` had to be set to 0
for a moment: with the simulated pointer it does not unfold).

#### Summary: all the rules of `~/.config/gtk-3.0/gtk.css`

Everything that has no graphical option in Xfce 4.20 goes here (it is restored with the rest in this
step; backed up in `fish/void/xfce/gtk.css`). After changing it: `xfce4-panel -r`.

| Rule | What it does |
|---|---|
| `#XfcePanelWindow.panel-2 { border-radius: 14px }` | rounded corners of the bottom panel (see above) |
| `#XfcePanelWindow.panel-2 button { border-radius: 12px; margin: 2px }` | rounded highlight of its buttons on hover; the margin makes it concentric with the panel (14 − 2 = 12) (2026-10-02) |
| `#pager-20 button` / `:checked` / `:checked label` | white circle with a black number on the active workspace (`min-width`/`min-height` 20 px, `border-radius` 999 px) |
| `#power-manager-plugin-19 label` | battery in `JetBrainsMono NFM Blocks`, bold, 10 pt |
| `#panel_window { background-color: #000000 }` | **black** top bar on `xfce4-screensaver`'s unlock screen |
| `#panel_window label` | its texts (machine, date and time) with the clock's font |

**The unlock screen** (the one that comes out when coming back from suspend or with Super+Ctrl+L) is
`xfce4-screensaver`'s, not lightdm's: its bar **imitates the greeter** (in its
`xfce4-screensaver-dialog.ui` it is a `GtkBox` called `panel_window`, with the class
`lightdm-gtk-greeter`), so Orchis paints it transparent the same way. It runs **as the user**:
it reads this `gtk.css`, not `lightdm`'s (step 10). It is created on every lock, so it takes the
changes without restarting anything.

**The plugin numbers (`-19`, `-20`) come from the panel's configuration**; when restoring it
(above) they are the same. If the panel is redone by hand, check them with
`xfconf-query -c xfce4-panel -lv | grep '^/plugins/plugin-[0-9]* '` and adjust the rules.

#### New windows centered

```bash
xfconf-query -c xfwm4 -p /general/placement_ratio -s 100   # placement_mode is already "center"
```

In the interface: *Ajustes del gestor de ventanas → Colocación* (*Window Manager Tweaks → Placement*), the control of "tamaño mínimo
para la colocación inteligente" ("minimum size for smart placement") at the maximum and "en el centro de la pantalla" ("at the center of the screen"). **How it really
works** (xfwm4's code, `src/placement.c`): a window is placed according to
`placement_mode` (center) if `placement_ratio >= 100` **or** if its area is **smaller** than that
percentage of the screen; otherwise, it goes to smart placement, which looks random. With
the default `20` only the small ones were centered. Apps that ask for or remember their own
position do not move. **Verified on 2026-10-02:** an xterm of 868×634 opened at x = 249,
the center of 1366.

#### Focus: follows the mouse; raise, with a click

Changed by the user in *Ajustes del gestor de ventanas → Foco* (*Window Manager Tweaks → Focus*) (2026-10-02):

| Setting (`xfwm4`, `/general/…`) | Before | Now |
|---|---|---|
| `click_to_focus` | `true` (click to focus) | **`false`** (the focus follows the mouse) |
| `focus_delay` | 250 | **5** ms |
| `raise_on_focus` | `false` | ~~`true`~~ → **`false`** since 2026-10-06 (see below) |
| `raise_delay` | 250 | **750** ms (delay before raising; it stayed at 749 when moving the control and was set to 750 with `xfconf-query`) |

Unchanged: `focus_new` = `true`, `raise_on_click` = `true`, `prevent_focus_stealing` =
`false`. It is in the `xfwm4` channel, together with `placement_ratio` = 100 (centered windows),
`easy_click` = `Super`, the theme and the title font.

**Change of 2026-10-06 (the user's request, on both machines): it no longer raises on focus.** The focus
follows the mouse, but the window **only comes to the front with a click** (or with an explicit shortcut: Alt+Tab,
Super+arrows). In xfwm4, `raise_on_focus` = **`false`** (`xfconf-query -c xfwm4 -p /general/raise_on_focus
-s false`, it applies at once); in labwc, `<raiseOnFocus>no</raiseOnFocus>` in the common `rc.xml` (step 15; the
clicks already focus and raise because of the `mousebind` of `<default/>`: `Client`/`Title`/`Frame` → `Focus` +
`Raise`). `raise_delay` (750) is no longer used. Backed up in `fish/void/xfce/xfce-perchannel-xml/xfwm4.xml`.

#### Omarchy's shortcuts

**This is Xfce X11's** (xfwm4 and `xdotool`). In Xfce Wayland, the normal desktop, the same shortcuts
go in labwc's `rc.xml` (step 15); the focus and placement above, too.

Taken from Omarchy's current shortcuts (`default/hypr/bindings/*.lua` of
`github.com/omacom/omarchy`, branch `quattro`, 2026-10-02). Omarchy goes on Hyprland (tiling)
and Xfce is floating: **there is no equivalent** for splitting, floating/tiling, groups,
swapping windows, scratchpad, resizing with the keyboard nor Omarchy's own menus
(themes, backgrounds, reminders, web apps, emojis). **They are added to Xfce's**, which keep
working (Ctrl+Alt+T, Super+E, Super+R, Alt+F4…), except **Super+Tab**, which before switched
window and now switches workspace.

| Omarchy | Does | Command in Xfce |
|---|---|---|
| Super+Enter | Terminal | `exo-open --launch TerminalEmulator` (xterm) |
| Super+Shift+Enter, Super+Shift+B | Browser | `exo-open --launch WebBrowser` |
| Super+Shift+Alt+B | Private browser | `firefox --private-window` |
| Super+Shift+F | Files | `exo-open --launch FileManager` |
| Super+Shift+N | Editor | `mousepad` |
| Super+Space | Launcher | `xfce4-appfinder` (full view, the one the user uses) |
| Super+Alt+Space | Apps menu | `xfce4-popup-applicationsmenu` |
| Super+Escape | System menu | `xfce4-session-logout` |
| Super+Ctrl+L | Lock | `xflock4` (needs `xfce4-screensaver`) |
| Super+Ctrl+V | Clipboard | `xfce4-popup-clipman` |
| Super+Ctrl+A / W / D / P | Audio / network / display / power | `pavucontrol` / `nm-connection-editor` / `xfce4-display-settings` / `xfce4-power-manager-settings` |
| Super+Ctrl+T | Activity | `exo-open --launch TerminalEmulator btop` |
| Super+Ctrl+B | Bluetooth | `blueman-manager` |
| Super+W, Super+Q | Close window | `xdotool getactivewindow windowquit` |
| Super+F | Full screen | `xdotool getactivewindow windowstate --toggle FULLSCREEN` |
| Super+Alt+F | Full width | `xdotool getactivewindow windowstate --toggle MAXIMIZED_VERT %1 windowstate --toggle MAXIMIZED_HORZ %1` |
| Super+O | Pop out and pin | `xdotool getactivewindow windowstate --toggle ABOVE` |
| Super+1…0 | Go to workspace | `xdotool set_desktop N-1` |
| Super+Shift+1…0 | Move window to the workspace **and follow it** | `xdotool getactivewindow set_desktop_for_window N-1 set_desktop N-1` |
| Super+Tab / Super+Shift+Tab | Next / previous workspace | xfwm4 actions `next_workspace_key` / `prev_workspace_key` |
| Super+drag left / right | Move / resize | xfwm4's `easy_click` = `Super` (it was `Alt`) |
| Alt+Tab, volume and brightness keys | — | they already came in Xfce |
| Print / Shift+Print / Alt+Print | Screenshot | `xfce4-screenshooter` (already assigned; it was not installed). It does not record video |
| **Super+← → ↑ ↓** | Focus to the window on that side | `~/.local/bin/ventana-foco izq\|der\|arr\|abj` (left/right/up/down) (added on 2026-10-02) |
| **Super+Shift+← → ↑ ↓** | Snap: halves and, chaining two arrows, corners; between the two halves, almost maximized | `~/.local/bin/ventana-acoplar izq\|der\|arr\|abj` (added on 2026-10-02) |
| **Super+Shift+Space** | Home position (almost maximized; dialogs at the center) | `~/.local/bin/ventana-acoplar inicio` (home) (2026-10-03) |

The packages they use (`xdotool`, `xfce4-screensaver`, `xfce4-screenshooter`, `btop`,
`blueman`) are installed in step 9. **Without `xfce4-screensaver` running, `xflock4` locks
nothing** (nor does Xfce's Ctrl+Alt+L); its autostart starts it on every session. Everything is in
the `xfce4-keyboard-shortcuts` channel, which is restored with the others at the beginning of this step.

**Two traps, already solved, that must not be repeated:**

1. **xfwm4 keeps only ONE shortcut per action** (`params->keys[id]` in `src/settings.c` of
   xfwm4 4.20: `parseShortcut` takes the first one it finds). If an action has two
   (e.g. `workspace_5_key` with Ctrl+F5 **and** Super+5), when xfwm4 starts only one works,
   at random; changing it on the fly "fixes" it until the next start. It happened to Super+5.
   That is why **Omarchy's shortcuts that duplicate an xfwm4 action are commands with
   `xdotool`** (channel `/commands/custom`) and xfwm4 keeps only Xfce's (Ctrl+F1…,
   Alt+F4, Alt+F11, Alt+F10, Alt+F12). Check that no action is repeated:
   `xfconf-query -c xfce4-keyboard-shortcuts -lv | grep '^/xfwm4/custom/' | awk '{print $2}' | sort | uniq -d`
   (it must come out empty). Tested by restarting xfwm4 (`xfwm4 --replace`, as when logging in)
   and pressing each shortcut for real: they all work.
2. **Super+Shift+number is registered with the symbol, not with the number:** with Shift, key 1
   gives `!`. If `<Super><Shift>1` is registered, the shortcut is not captured and the key reaches the
   application (Thunar typed text). In `latam`, Shift+1…0 = `exclam`, `quotedbl`,
   `numbersign`, `dollar`, `percent`, `ampersand`, `slash`, `parenleft`, `parenright`,
   `equal` (read from `xkbcomp -xkb :0 -`, not from memory). **If the keyboard layout
   changes, those ten have to be redone.**

There are 5 workspaces; Super+6…0 do nothing.

**Super+arrows and Super+Shift+arrows (2026-10-02), in the style of a tiling WM:**
- **Snap (`ventana-acoplar`, backed up in `fish/void/xfce/`):** Super+Shift+arrow puts the
  active window in that half; **chaining** (↓ and then →) it goes to the corner; from a corner,
  the "opposite" arrow makes it grow to the half (bottom-right + ← = bottom half). **Almost maximized (region "llena", "full") is the intermediate step between the two halves**, inside
  the monitor (2026-10-03): left half + → = full; full + → = right half (the same with
  ↑/↓). **Towards the edge it does nothing** (← on the left half, or outwards from a quarter),
  and **the quarters never go to full** with arrows: inwards they grow to the half. (Before it was
  repeating the arrow outwards, "as if going out of the monitor": not intuitive.) The same in
  labwc (step 15). **Super+Shift+Space**
  (`ventana-acoplar inicio`) takes it back to the home position: "full", or to the center if it is a
  dialog, of fixed size or the finder. It works **on the window's monitor** (with `xrandr`; without
  it, the whole desktop, which with a single screen is the same), respects the window's **minimum size**
  (stuck to the edge it touches) and **records where it sent each window**
  (`$XDG_RUNTIME_DIR/ventana-acoplar/`) so as not to deduce wrongly the state of those that do not reach the
  requested size. Detail and tests: the Legion's recipe (`void-legion-go2.md`), step 13.
  **New windows almost maximized** (like labwc): `ventanas-nuevas` ("new windows"), event-driven watcher
  (`xprop -spy`) that starts with the session (`~/.config/autostart/ventanas-nuevas.desktop`); it does not touch
  dialogs, child windows, fixed-size ones, the finder nor full-screen ones, and **in the
  Wayland session it exits without doing anything** (there labwc's rules do it). **8 px gap the same everywhere**
  (edges, panel and between windows: `HUECO=8` (gap) at the beginning of the script). Three cases:
  - windows with an xfwm4 frame (xterm, Thunar): the frame is added (`_NET_FRAME_EXTENTS`);
  - windows with **their own bar** (Firefox and other GTK ones): the **invisible shadow** they
    include is subtracted (`_GTK_FRAME_EXTENTS`, in Firefox 56/56/50/63 px); without that the visible part ended up
    much smaller and tucked inwards;
  - **fixed-size** windows (minimum = maximum, like the screenshot one): they are not
    resized; they are stuck to that side (centered on the other axis) or to the corner, and their position
    is deduced from the edges they touch.
  xfwm4's `tile_*_key` actions stay on Super+numeric keypad (this laptop does not have one)
  and are not used. **Traps:**
  1. **Do not simulate keys from the script.** The first version asked xfwm4 for the snapping
     by sending Super+KP_*: with the real keys pressed, the keyboard stays captured by the
     shortcut and the simulated key does not reach xfwm4 (in tests with simulated keys it did
     work, because they were released instantly). That is why the script places the window itself.
  2. **The focus follows the mouse:** when moving, the window stops being under the pointer and the focus
     would jump to the one below (the next arrow would move another window). The script takes the
     pointer to the **center of the destination it has just calculated** (without waiting for xfwm4 to move the
     window nor reading its geometry again: before there was a `sleep 0.1`; `xdotool --sync` does not work, it
     hangs if the window was already in its place).
- **Focus by direction:** xfwm4 does not bring that action, so it is a script, `ventana-foco` ("window focus")
  (backed up in `fish/void/xfce/`): it takes the center of the active window, looks among the
  normal windows of the current workspace that are not minimized for the one in that direction (distance +
  2 × lateral deviation) and **takes the pointer to its center** before activating it. Two traps:
  1. **xterm does not declare `_NET_WM_WINDOW_TYPE`**: a window without a type counts as normal
     (EWMH). Requiring `TYPE_NORMAL` left out all the xterms.
  2. **Launched from the shortcut, `xdotool windowactivate` does not change the focus** (with Super pressed
     xfwm4 ignores it; from a terminal it did work). As the focus follows the mouse, moving the
     pointer to the window is what really gives the focus; activating and raising go afterwards.
  Verified with the real keys (30 switches in a row, none failed).

#### xfce4-terminal (not used)

**xfce4-terminal keeps its configuration in xfconf**, not in a file (since version
1.x it no longer uses `terminalrc`). From the session itself:

```bash
xfconf-query -c xfce4-terminal -p /font-use-system -n -t bool -s false
xfconf-query -c xfce4-terminal -p /font-name -n -t string -s "JetBrainsMono Nerd Font Mono 11"
```

Over SSH, `xfconf-query` needs the graphical session's bus: `DISPLAY=:0` and the
`DBUS_SESSION_BUS_ADDRESS` taken from `xfce4-session`'s environment
(`tr '\0' '\n' < /proc/$(pgrep -x xfce4-session)/environ`). With lightdm it is not in
`/run/user/1000/bus`.

**Verified on 2026-10-02:** Papirus-Dark active, `folder.svg` → `folder-teal.svg`, Docklike
in the top panel, Clipman and volume in the panel, and `Orchis-Teal-Dark-Compact` as GTK and xfwm4
theme.

### 14. Steam and Game Mode like SteamOS (optional; 2026-10-02 and 03)

To see how Steam goes (and then gamescope, SteamOS's Game Mode session) on Void before
thinking about the Legion. **Reversible**, and not needed for anything of the above.

```bash
sudo sh "<disco>/Backups Linux/fish/void/steam/instalar-steam.sh"            # installs
sudo sh "<disco>/Backups Linux/fish/void/steam/instalar-steam.sh" --quitar   # removes it all
```

(The `--quitar` reads `paquetes-instalados.txt`, which the script writes **next to it**: run it from
the same folder that was used to install. Copy of this installation's in the same folder of the
disk.)

What it does, in order:
1. **Repositories** `void-repo-nonfree`, `void-repo-multilib` and `void-repo-multilib-nonfree`
   (Steam is *nonfree* and needs 32-bit libraries; it is what Void's manual says,
   *External applications → Steam*).
2. **Packages** (xbps shows the list and asks to confirm): `steam`, `gamescope`, `MangoHud`,
   **`MangoHud-mangoapp`** (the performance overlay of the quick menu; it goes in a subpackage),
   **`MangoHud-32bit`** (MangoHud's layer is loaded *inside* the game, and a 32-bit game
   —Blazing Beaks is one— needs the 32-bit one; both are installed),
   `mesa-vulkan-intel` (Vulkan for this GPU; **without it gamescope does not start**), `Vulkan-Tools`
   (`vulkaninfo`) and the 32-bit ones that `/usr/share/doc/steam/README.voidlinux` asks for:
   `libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit mesa-dri-32bit
   mesa-vulkan-intel-32bit vulkan-loader-32bit libva-32bit libpulseaudio-32bit
   alsa-pipewire-32bit` (the last three: video and audio of 32-bit games). **Besides**, since
   2026-10-05, `gamescope-32bit` (gamescope's Vulkan layer for 32-bit games) and, since
   2026-10-07, `pipewire-32bit` and `libspa-videoconvert-32bit` (Remote Play in Game Mode: Steam's
   client is 32-bit; Legion recipe, step 14) and, only with an AMD GPU, `mesa-vaapi` and
   `mesa-vaapi-32bit` (not here). The exact list and the why, in the script's header. The two
   PipeWire ones were added to this installation on 2026-10-09 (`ideapad-al-dia.sh --steam-32bit`, step 16).
3. **Limits, like on SteamOS:** `/etc/security/limits.d/90-steam.conf` = `nofile 524288` for
   `isaac` (Proton/esync: with the default 4096 it fails with "eventfd: Too many open files"; it applies
   from the next login) and `/etc/sysctl.d/90-steam.conf` =
   `vm.max_map_count = 2147483642` (some games with Proton fail with the default 65530).
4. Checks Vulkan: here `Intel(R) HD Graphics 5500 (BDW GT2)`, Vulkan 1.3, Mesa driver.

Afterwards, **before opening Steam for the first time**, its desktop launcher with `-steamdeck` (the
same client as Game Mode; otherwise, each mode switch downloads the other client, ~64 s: see
*Pendientes*, "Steam reinstala su cliente…" ("Steam reinstalls its client…")):

```bash
install -D -m 644 "<disco>/Backups Linux/fish/void/legion/steam/steam.desktop" ~/.local/share/applications/steam.desktop
```

Log out and log back in (the `nofile` limit) and open Steam **from the menu** (not with `steam`
in an xterm: without `-steamdeck`, another client). The first time it updates itself (~500 MB) and asks
to log in. The library stays in `~/.local/share/Steam` (the `--quitar` does not delete it). For the
reinstall, the whole step in order is in *Installation order* (below).

**What was seen (2026-10-02):**
- **Native Linux games** (Nuclear Throne): they work without touching anything.
- **Windows games (Proton) with Direct3D 11/12 fail with this GPU:** they close after a
  second. With `PROTON_LOG=1 %command%` in their launch options, the log
  (`~/steam-<AppID>.log`) says `Skipping: Device does not support required feature
  'descriptorIndexing'` and `DXVK: No adapters found ... A Vulkan 1.3 capable setup is
  required`: Proton's DXVK (3.1) requires something that Mesa's driver does not give on Broadwell. It is not
  Void nor the configuration; on an AMD GPU (the Legion) it does not happen.
- **Fix, game by game:** *Propiedades → General → Opciones de lanzamiento* (*Properties → General → Launch Options*) =
  **`PROTON_USE_WINED3D=1 %command%`** (Direct3D over OpenGL instead of Vulkan). Tested with
  Blazing Beaks (GameMaker, AppID 585710): it starts, it is seen and it plays fine.
- **Blazing Beaks also carries "Proton Hotfix" forced** (*Propiedades → Compatibilidad* / *Properties → Compatibility*;
  `config.vdf` → `CompatToolMapping` → `585710` = `proton_hotfix`, priority 250 = chosen by hand).
  Why was not noted. According to `~/.local/share/Steam/logs/compat_log.txt`, on 2026-10-02 at 23:20
  Proton Experimental was used (two sessions of 24 and 16 s: the DXVK crashes above) and at
  23:25:38 Hotfix was forced. It was an attempt during that failure, whose real fix turned out to be
  `PROTON_USE_WINED3D=1`. **Without the forcing, Steam would not use Proton 11.0:** for this game Valve's
  recommendation applies, **`proton-7.0-5` (Proton 7.0, priority 85, not installed: it would
  download it)**, above the account's general one (`proton-stable`, priority 75). No other
  game uses Hotfix (`CompatToolMapping` only has the 585710). **Pending** the user's test
  (see *Pendientes*).
- The error "Xalia: No displays available" of the log is from a Proton helper for controllers
  and has nothing to do with it: it also comes out when the game works.
- **Steam uses quite a lot of processor** (its interface, `steamwebhelper`, is a Chromium): on this
  2-core i3, more than a 2D game. Minimize it while playing.
- **gamescope inside Xfce works:** `gamescope -W 1366 -H 768 -f -- steam -gamepadui`
  (Steam Deck interface in full screen; `-w 1280 -h 720` without `-f` for a window).
  Blazing Beaks launched from there, fine. gamescope shortcuts: **Shift+Tab** = Steam menu,
  **Ctrl+Shift+Tab** = quick menu. Harmless warnings: `VERSION_ID: variable sin asignar` ("unassigned variable")
  (Void does not put a version in `/etc/os-release`), those of Fontconfig and those of `xkbcomp`.

#### Game Mode like SteamOS: gamescope on the screen, autologin and automatic switches

**How it ends up (verified on 2026-10-03):** on power-on it enters **by itself, without login screen nor
password**, in the last mode used. In Game Mode, Steam with SteamOS's interface and
**gamescope handling the screen itself** (Wayland + Xwayland on DRM/KMS, like SteamOS: what
on the Legion would give VRR, HDR and refresh rate switching). **"Cambiar a escritorio"** ("Switch to Desktop") (power
menu) closes Steam and enters Xfce by itself (**on Wayland**, the normal desktop since step 15;
X11 stays as a backup); from Xfce, the **"Modo Juego"** ("Game Mode") launcher (applications
menu, Games) enters Game Mode by itself (it closes Xfce at once, like SteamOS: save
first). **Administration still needs a password**: `sudo`, installing packages, `update-system`…
The only thing that runs without it is `cambiar-modo-root`, which only accepts `juego` (game), `escritorio` (desktop: Xfce
Wayland) or `escritorio-x11`.
Checked: the performance overlay obeys the quick menu, Steam's on-screen keyboard
types, the xterm-steam works inside (with Claude Code), and switching from one mode to the other takes
~2 s since Steam is closed.

**Installation order** (all reversible; `instalar-cambio-sin-contrasena.sh` is the one that removes the
password when logging in). **In a reinstall, the whole step 14 is this block**, from Xfce X11:

```bash
B="<disco>/Backups Linux/fish/void"; D="$B/steam"
sudo sh "$D/instalar-steam.sh"                   # repos, Steam, gamescope, MangoHud, Vulkan, limits
install -D -m 644 "$B/legion/steam/steam.desktop" ~/.local/share/applications/steam.desktop   # -steamdeck
#   log out and log in (nofile); open Steam FROM THE MENU: it updates and logs in; close it
sudo sh "$D/instalar-modo-juego.sh" --sin-pantalla-de-carga   # launcher, X session, steamos-session-select…
#   (--sin-pantalla-de-carga since 2026-10-05, like the Legion: without the option steam-cargando comes back)
sudo sh "$D/probar-sesion-directa.sh"           # the Wayland "direct screen" session
sudo sh "$D/instalar-cambio-sin-contrasena.sh"  # autologin + switch without password
sudo sh "$B/xfce-wayland/instalar-xfce-wayland.sh"   # step 15: BEFORE rebooting
sudo bash "$B/legion/como-steamos.sh"           # SteamOS settings ("Igualada con la Legion"); -pipewire in steam.desktop
udisksctl unmount -b /dev/sdb4 && sudo reboot   # enters Game Mode by itself
# undo, in reverse:  … como-steamos.sh --quitar ; instalar-xfce-wayland.sh --quitar ;
#   instalar-cambio-sin-contrasena.sh --quitar ; probar-sesion-directa.sh --quitar
```

`como-steamos.sh` leaves its log in `~/como-steamos.log`, **owned by root** (it writes it with `sudo`): it is the
only foreign file expected in `~` (see *Comprobación final*). Afterwards, `xterm-steam` (below; Decky
is no longer installed here since 2026-10-09), what is done by hand of the *Full list*, point 14, and step 16.

(`probar-inicio-automatico.sh` was an intermediate step and is no longer needed: `instalar-cambio-sin-
contrasena.sh` replaces it.)

**After installing, once, inside Game Mode:** *Configuración → Teclado* (*Settings → Keyboard*) → choose
**Español (Latinoamérica)**. It is the keyboard of Steam's interface (and of the on-screen keyboard); the
one of the games and of the xterm is set by the launcher (`XKB_DEFAULT_LAYOUT`). They are two separate things, the same
as in SteamOS's recipe (step 2).

What each script puts:
- **`instalar-modo-juego.sh`:**
  - **`/usr/local/bin/steam-modo-juego`**, the launcher. It starts its own **D-Bus session
    bus** (`dbus-run-session`; without it Steam had no `DBUS_SESSION_BUS_ADDRESS` and its interface
    failed with `Failed to connect to the bus`), sets `XDG_SESSION_DESKTOP=gamescope` and
    `XKB_DEFAULT_LAYOUT` (read from `00-keyboard.conf`, step 2), and launches
    `gamescope -e … -- sh -c '( steam-cargando; mangoapp ) & steam -steamos3 -steampal -steamdeck
    -gamepadui'`.
    **Two modes according to the session:** without `DISPLAY` (Wayland session) gamescope goes **on the
    screen** with `--adaptive-sync`; with `DISPLAY` (X session, the backup one) it goes **nested** in
    full screen (`-f -W/-H` from `xdotool getdisplaygeometry`, and `xset s off -dpms` so that X
    does not turn off the screen). **On the screen, besides, the options and variables of SteamOS's
    session** (`--generate-drm-mode fixed --xwayland-count 2 --default-touch-mode 4
    --hide-cursor-delay 3000 --fade-out-duration 200`, `STEAM_MULTIPLE_XWAYLANDS=1`,
    `STEAM_GAMESCOPE_*_SUPPORTED`, `GAMESCOPE_MODE_SAVE_FILE`… list in the script; 2026-10-04, done
    on the Legion): without them, when connecting or removing a monitor while running Steam kept the
    proportions of the previous one. **Without** SteamOS's `-w 1280 -h 800 --max-scale 2 --cursor-scale-height 720`
    (stretched and blurry image, big cursor). **Applied on 2026-10-04** (repeating `instalar-modo-juego.sh`; still to be tested here);
    check with `pgrep -a gamescope` (`--xwayland-count 2`).
    **The desktop's cursor also in Game Mode** (2026-10-04): the launcher reads
    `CursorThemeName` from Xfce's xsettings (Volantes), exports `XCURSOR_THEME`/`XCURSOR_SIZE=24` and
    puts `gtk-cursor-theme-name` in `~/.config/gtk-3.0/settings.ini` (Steam's interface,
    Chromium, only listens to that); like SteamOS with its `steam` theme, which is not published.
    Checked on the Legion (2026-10-04); here applied on 2026-10-04, still to be tested (log:
    `cursor: volantes_cursors`).
    **It knows when Steam ends event-driven**, not by polling: a pipe
    (`$XDG_RUNTIME_DIR/steam-modo-juego.fifo`) where Steam's wrapper writes when Steam
    ends and gamescope's subshell if gamescope falls first; the launcher waits blocked reading. If
    Steam ended and it goes on the screen, **it closes gamescope at once** (see *What it cost* 6).
    At the end it calls `steamos-session-select xfce` (→ `cambiar-modo-root escritorio`: Xfce on
    Wayland, step 15). Log: `~/.local/state/steam-modo-juego.log`
    (it starts with the time of entering).
  - **`/usr/share/xsessions/steam-modo-juego.desktop`**: the X session (nested), as a backup.
  - **`/usr/local/bin/steamos-session-select`**: the one Steam calls for "Cambiar a escritorio"
    (on SteamOS it has the same name), the Xfce launcher and `steam-modo-juego` when ending. If
    `cambiar-modo-root` exists (and `sudo -n` allows it), it uses it: from Steam it only closes Steam
    (`steam -shutdown`) and the switch is done by `steam-modo-juego` when ending, still inside the
    session; from Xfce, `cambiar-modo-root juego`. Otherwise, what was there before: it leaves the chosen session in
    AccountsService (`SetXSession`) and in `~/.dmrc` and logs out (login screen with
    password). Log: `~/.local/state/steamos-session-select.log`.
  - **`/usr/local/bin/steamos-update`** (with `-steamos3` Steam asks for system
    updates: it answers "No update available", code 7, like SteamOS; here
    `update-system` is used), **`/usr/share/applications/modo-juego.desktop`** (the Xfce launcher) and
    **`cap_sys_nice`** on `/usr/bin/gamescope` (without it: "No CAP_SYS_NICE … Performance will be
    affected"; **it is lost when updating gamescope: repeat the script**; check with
    `getcap /usr/bin/gamescope`).
  - **Audio:** the launcher starts **`pipewire`** (if it is not running already), which launches `wireplumber` and
    `pipewire-pulse` (`context.exec` of `/etc/pipewire/pipewire.conf.d/`), and closes them when ending.
    In Xfce the session's autostart starts it (`/etc/xdg/autostart/pipewire.desktop`); in
    Game Mode there is no autostart and Steam did not see any audio device (2026-10-03).
  - **Brightness: `/usr/local/lib/steam-modo-juego/bin/sudo`**, first in the `PATH` only inside
    Game Mode. Steam (with `-steamos3`) changes the brightness with `echo N | sudo -n tee
    /sys/class/backlight/<x>/brightness`, which here asks for a password. That `sudo` turns **only that
    exact command** (number and name checked) into **elogind's `SetBrightness`**
    (`busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto
    org.freedesktop.login1.Session SetBrightness ssu backlight intel_backlight N`): the mechanism of
    GNOME and KDE, which lets the session on screen change its brightness **without password, without
    root and without changing permissions**. Everything else goes to the real `sudo`. It writes each value in
    `steam-modo-juego.log` (`brillo N (intel_backlight)` — "brightness N"). A udev rule
    (brightness writable by the `video` group: any program, even without a session on screen) and
    a root helper in sudoers (root code without password) were discarded. The brightness bar of the quick menu
    works (2026-10-03).
  - The launcher **empties its log when entering and opens it in append mode** (`>>`): with `>`, the output
    of gamescope covered the lines that the brightness `sudo` adds.
  - **`/usr/local/bin/steam-cargando`** ("steam loading") (it can be left out: `instalar-modo-juego.sh
    --sin-pantalla-de-carga`, like the Legion since 2026-10-04; the launcher works without it): the **loading screen** while Steam starts, the same
    as Plymouth at power-on: the firmware logo (`/sys/firmware/acpi/bgrt/image`, in its place:
    `xoffset`/`yoffset`) and Void's symbol spinning below (the 36 frames of the
    `bgrt-void` theme, at ~30 per second, in `two-step`'s position). Python with GTK (already installed).
    The launcher opens it inside gamescope before Steam, and **`mangoapp` starts when it
    closes** (`( steam-cargando; mangoapp ) &`). It closes **event-driven**: `xprop -root -spy
    GAMESCOPE_FOCUSABLE_WINDOWS` (gamescope publishes the list of windows there) and, as soon as
    another program's window that is not `mangoapp` (that of `steamwebhelper`) appears, it ends. If that event does not
    arrive, after 3 min it closes anyway. It writes both times in `steam-modo-juego.log`
    (`steam-cargando: en pantalla` ("on screen") / `apareció la ventana de steamwebhelper; fuera` ("steamwebhelper's window appeared; out"); on
    2026-10-03, 9 s). See *What it cost* 9–11. To measure the gap between the still logo and the
    loading screen, the log also carries `lanzando gamescope` ("launching gamescope") (the launcher) and
    `steam-cargando: arrancando` ("starting") (before loading GTK): up to "arrancando" it is gamescope and
    Xwayland; from there to "en pantalla", Python and GTK. On a cold boot on 2026-10-03, 14 s
    between entering and "en pantalla" (mechanical disk).
- **`probar-sesion-directa.sh`:** the Wayland session
  `/usr/share/wayland-sessions/steam-modo-juego-directo.desktop` (same launcher). It also puts a
  wrapper of the login screen with `NO_AT_BRIDGE=1` (`greeter-wrapper` in lightdm.conf)
  which **did not solve** what is in *What it cost* 2; it does not get in the way.
- **`instalar-cambio-sin-contrasena.sh`:**
  - **`/etc/xdg/lightdm/lightdm.conf.d/60-modo-steam.conf`**: autologin of `isaac` into
    `steam-modo-juego-directo`, `xfce-wayland` or `xfce` (the last mode used; running the
    script again keeps it, and only the first time it sets Game Mode). lightdm reads that folder **before** `lightdm.conf`, so
    the `autologin-user`/`autologin-session` lines that the ISO brought are commented there
    (`--quitar` gives them back: `anon`/`xfce`).
  - **`/usr/local/bin/cambiar-modo-root juego|escritorio|escritorio-x11`** (root): `juego` =
    `steam-modo-juego-directo`; **`escritorio` = Xfce on Wayland** (`xfce-wayland`, step 15,
    since 2026-10-03); `escritorio-x11` = Xfce X11, as a backup (`escritorio-wayland` is still
    accepted, as a synonym of `escritorio`). It changes that session and restarts
    lightdm (`setsid sv restart lightdm`), which enters it by itself, like SteamOS's "Switch to Desktop"
    (which changes sddm's autologin and restarts it).
  - **`/etc/sudoers.d/zz-cambiar-modo`**: `isaac` can run **only** that script without
    password. Validated with `visudo -cf` before putting it. **The name starts with `zz` on
    purpose:** `sudoers.d` is read in alphabetical order and **the last matching rule wins**;
    with `cambiar-modo`, the `wheel` one (which asks for a password) was read afterwards and overrode it.

**Why SteamOS's arguments** (`-steamos3 -steampal -steamdeck -gamepadui`, those of
the Legion's `/usr/lib/steamos/steam-launcher`; CachyOS uses the same ones): without them Steam believes it is a
PC in Big Picture, with **another interface**, without "Switch to Desktop" and **without handling the overlay**
(it never writes in `MANGOHUD_CONFIGFILE`; it uses its own FPS counter). With them it also tries to
tune the machine like a Deck (in `~/.local/share/Steam/logs/steamui_steamos.txt`: TDP, charge
limit, power profile, "wifi power management: 1") through `steamos-manager`, which here does not
exist: it does nothing. In Settings SteamOS options show up that here do nothing.

**Quick menu → Performance:** the advanced options (FPS limit, **scaling filter**: FSR,
NIS…) are behind the **"Vista avanzada"** ("Advanced view") switch, at the end of the menu, as on SteamOS; they are given by
gamescope (it announces `STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT`, `…_NIS_SUPPORTED`,
`…_DYNAMIC_FPSLIMITER`). **TDP and GPU clock** are handled by Steam through
**`steamos-manager`**, which here is not installed (see *steamos-manager*, below).

**The performance overlay (mangoapp), like SteamOS** (the Legion's `/usr/lib/steamos/gamescope-session`):
gamescope **without** `--mangoapp`; the session creates
`$XDG_RUNTIME_DIR/steam-modo-juego/mangohud.config` (`MANGOHUD_CONFIGFILE`), which starts at
`no_display` **written with `echo`**, exports `STEAM_USE_MANGOAPP=1`,
`STEAM_MANGOAPP_PRESETS_SUPPORTED=1`, `STEAM_MANGOAPP_HORIZONTAL_SUPPORTED=1` and
`STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND=1`, and launches `mangoapp` separately (after the loading screen). Steam rewrites the file
when changing the level. The warning `Unknown option 'nis_steam_sharpness'` is harmless.

**What it cost (2026-10-03), so as not to repeat it:**
1. **`gamescope --mangoapp`: the overlay always showed.** The file that gamescope creates had
   `no_display` **followed by a null byte** (`od -c`); MangoHud did not recognize it. Hence SteamOS's
   method.
2. **With lightdm's login screen, the session on the screen got lost.** When going from a
   login screen to the Wayland session, lightdm opens another console and the login screen
   **does not die** with its `SIGTERM` (one took 88 s; another was still alive after 13 min; it does not even receive
   the signal: its intermediate process does not pass it on). After ~20–27 s something of that half-closed login screen
   takes the console away from gamescope (`Session paused`); when it dies, lightdm sometimes
   **locks the session** (`Locking login1 session`) and there is no way back. It happened with and without
   `-steamos3`, with and without the accessibility bus (at-spi), and also to an Xfce X session
   opened after a hung login screen. **The solution is not to use the login
   screen**: autologin at power-on and switches by restarting lightdm (like SteamOS with sddm).
   Diagnosis: `diag-lightdm.sh` (it saves lightdm's log in `diag-lightdm.txt`).
3. **`at-spi-enabled = false`** (`greeter-sin-atspi.sh`) and **`NO_AT_BRIDGE=1`**
   (`probar-sesion-directa.sh`) were put for the above and **did not solve it**. Here they are
   applied and do not get in the way. **`greeter-sin-atspi.sh` is not in the installation order: in a
   reinstall it is not run** (that is why this machine has the line `at-spi-enabled = false` in
   `lightdm-gtk-greeter.conf` and the backup of step 10 does not). The `NO_AT_BRIDGE` is put again by
   `probar-sesion-directa.sh`. Steam's on-screen keyboard does not use at-spi (it types through
   gamescope, `libei`).
4. **gamescope's process is called `gamescope-wl`**, not `gamescope`.
5. **A background process launched from the session dies with it** before doing anything: that is why the
   mode switch is done by `steam-modo-juego` when gamescope ends, still inside the session.
6. **On the screen, gamescope took ~26 s to close** after Steam: it asks elogind to release the
   screen and that D-Bus call runs out its timeout (`Could not close device: Connection timed out`). The
   launcher closes it at once as soon as Steam ends (the kernel releases the screen when
   the process closes): from ~27 s to ~2 s until Xfce. Nested in X it does not happen.
7. **"Xfce Session (Wayland)" did not work** (labwc was missing): now it is step 15, and it is entered
   with the "Escritorio Wayland" ("Wayland Desktop") launcher, never from the login screen (*What it cost* 2).
8. **How long it takes to enter.** gamescope opens instantly; the slow part is Steam: ~11 s of `steam.sh`
   checking its environment, the client's verification and its interface (a Chromium, on a 2-core
   i3 with a mechanical disk). **Measured on 2026-10-03:** just powered on (the disk cold, even if
   entering from the desktop), 51 s until Steam's interface (loading screen after 3 s); the
   second time in the same power-on, **10 s** (loading screen after a second): it has it in memory. With `-steamos3` it uses another client (`steamdeck_stable`), and sometimes it **reinstalls it and
   restarts** (`uninstalled manifest found … steam_client_steamdeck_stable`, then `Restarting
   Steam by request`): **~64 s more**; on 2026-10-03 it happened three times and it is not known why. If an
   entry takes long, look for those lines in `~/.local/share/Steam/logs/console-linux.txt` near
   the time the launcher leaves.

9. **Plymouth does not work between one session and another.** It was tried launching it from `/etc/sv/lightdm/conf`
   when restarting lightdm: lightdm closes it as soon as the session starts (less than 1 s) and the long part is
   Steam loading **inside** gamescope, which already owns the screen. Hence `steam-cargando`.
   **The still logo seen for an instant when switching is not Plymouth:** it is the boot image that
   stays in the screen's memory (the kernel carries `FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER`:
   the console does not clear the screen until it has something to write). The same happened with an old
   `unix_chkpwd` warning (see *Troubleshooting*).
10. **With `gamescope -e` a normal window is not seen** (black screen): only those that
    carry a Steam game number (`STEAM_GAME`) count and the one Steam says is shown
    (`GAMESCOPECTRL_BASELAYER_APPID`, on the root). `steam-cargando` sets itself `STEAM_GAME=7` and puts
    `GAMESCOPECTRL_BASELAYER_APPID=7` itself; on exit it removes it if it is still its own (Steam puts
    its own when it has its interface). Without `-e`, in nested gamescope, it was seen: always test with `-e`.
11. **`mangoapp` drew the overlay on top of the loading screen:** Steam writes the saved level
    in `MANGOHUD_CONFIGFILE` when starting, before its window. That is why `mangoapp` starts
    afterwards; when starting it reads what is in the file and follows its changes. And `status` of
    `/sys/firmware/acpi/bgrt` is 0 here even though the image is good: do not look at it.

**If it gets stuck:** Ctrl+Alt+F2, log in, `pkill -KILL -x gamescope-wl`, and `sudo sv restart lightdm`
(it enters by itself in the autologin mode). To see why: the two logs above and
`sudo sh "<disco>/Backups Linux/fish/void/steam/diag-lightdm.sh"`.

**Clean close of Steam when going from the desktop to Game Mode** (2026-10-04, in
`instalar-modo-juego.sh` → `steamos-session-select`, common to both machines): if the desktop's
Steam is open, `steam -shutdown` and it waits **event-driven** for it to end (`timeout 30 pidwait
-u <uid> -x steam`) before `cambiar-modo-root juego`; log: `cerrando el Steam del escritorio` ("closing the desktop Steam")
→ `Steam cerrado limpio` ("Steam closed cleanly"). **Why:** the session switch restarts lightdm and **killed** that Steam;
when starting in Game Mode, Steam saw that "it did not close well" (`Looks like steam didn't shutdown
cleanly`) and did the full verification (`Verifying all executable checksums`) instead of the
quick one (`Verifying file sizes only`). Measured on the Legion (here applied on 2026-10-04, not measured): Game Mode → desktop ~2 s; desktop
→ Game Mode **3 s** (before 21 s), also with Steam open (it closes in 2 s); on power-on after a
reboot, 6 s (full verification of 2 s, without errors). The 44 `bad CRC` binaries it saw
once were leftovers of the client switch (see above): repaired, they have not come back.

**Clean close of Steam also at power-off or reboot** (2026-10-04,
`instalar-cambio-sin-contrasena.sh`, common to both machines): **`/etc/runit/shutdown.d/05-cerrar-steam.sh`**.
Steam's power menu asks for the reboot **directly from elogind** (D-Bus `login1` `Reboot`; in
its log, the answer from `:1.9` = `elogind-daemon`) **without closing itself**; then runit's shutdown
killed it and on start Steam did the full verification. The script runs in runit's stage 3
**before** `10-sv-stop.sh` (which stops lightdm and with it the session): if there is Steam, `steam -shutdown`
as its user (with the process's own environment, `chpst -u`) and it waits **event-driven** (`timeout 20
pidwait -x steam`). It leaves **`/run/apagando-sistema`** ("system shutting down"), and `cambiar-modo-root` does nothing if it exists:
in Game Mode, when Steam ends the launcher takes it as "Switch to Desktop" and, without that mark,
the shutdown **would change the boot mode to desktop**. `/run` is emptied at boot.
- **It applies to every software shutdown that goes through runit with the session alive:** Steam's menu, `reboot`,
  `poweroff`, `shutdown`, `halt`, `loginctl`, power button (elogind calls `/usr/bin/halt`,
  `/usr/bin/reboot`, `/sbin/poweroff`, those of `runit-void`) and critical battery. **Not** with `reboot -f`
  (it does not call init) nor with a physical power-off.
- **It is not Void's documented way**: the documented one, `/etc/rc.shutdown`, is launched by
  `20-rc-shutdown.sh` **after** `10-sv-stop.sh` (with Steam already dead). `shutdown.d/` belongs to
  `runit-void` (all its files are the package's) and it is the same mechanism with which Void builds its
  shutdown (`/etc/runit/3` loads `shutdown.d/*.sh` in order); a file that belongs to no package
  survives updates. If one day it stops working, check that `/etc/runit/3` still
  goes through `shutdown.d/*.sh`.
- **Cost:** none in use (it is not a service); at shutdown, however long Steam takes to close (~2 s).
- **Logging out from the desktop (Xfce) did not go through here in time** (found on 2026-10-04 on both
  machines): with the panel's exit button, Super+Escape or Ctrl+Alt+Del, `xfce4-session`
  **first closes the session** and then asks for the reboot; when `xfce4-session` ends,
  labwc (`--session xfce4-session`) or the X of the `xinitrc` close, and Steam died with Xwayland/X (`X
  connection to :0 broken` in `webhelper-linux.txt`, without `Shutdown`; on start, `Verifying all
  executable checksums`). Xfce's autostart `RunHook`s (on logout/reboot/power-off)
  **do not work**: `xfce4-session` 4.20 launches them without waiting for them (`xfsm-global.c`). **Fix
  (`instalar-cambio-sin-contrasena.sh`, step 3c): wrapper `/usr/local/bin/xfce4-session`**
  (`/usr/local/bin` goes before `/usr/bin` in the session's `PATH`): it runs the real one and, when it
  ends, `steam -shutdown` and waits **event-driven** (`timeout 20 pidwait -u <uid> -x steam`) with the
  session still alive; on reboot, `05-cerrar-steam.sh` also finds it alive. It applies to Wayland and
  X11, it does not change Xfce's dialog (if it is canceled, Steam stays open) and without Steam it does nothing.
  It takes effect in the session after installing it. **A dirty close that already happened cleans itself
  up:** the next start of Steam sees `Looks like steam didn't shutdown cleanly` and does the full
  verification ONCE (`Verifying all executable checksums`, seconds); the next close
  is already clean and the starts go back to `Verifying file sizes only` (that is how it happened on both machines
  on 2026-10-04: 20:57:00 full → 20:58:06 `Shutdown` → 21:00:06 quick on the IdeaPad). There is nothing
  to delete or repair. **Switching between Wayland and X11 desktop** with
  their launchers and Steam open: `cambiar-modo-root` restarts lightdm directly; since
  2026-10-04 it first closes Steam with the same block as `05-cerrar-steam.sh` (from Game Mode
  Steam has already ended when it gets there). It is applied by repeating `instalar-cambio-sin-contrasena.sh`.
  **Verified on the Legion on 2026-10-04:** Steam open on Wayland → "Escritorio X11" ("X11 Desktop") launcher →
  `Shutdown` (21:12:17) and, on X11, `Verifying file sizes only`.
- **Race with elogind when switching mode** (found on the Legion on 2026-10-04, when pressing
  "Escritorio Wayland" while on Wayland): `cambiar-modo-root` did `sv restart lightdm` at once;
  the new session started while elogind was still cleaning up the old one and, when the user was left without
  sessions, elogind **deleted `/run/user/1000` with the `wayland-0` just created by the new labwc**
  (directory recreated at 21:37:44; without `wayland-0` nor `wayland-0.lock`). Everything that started
  afterwards fell to X11 through Xwayland: `xfce4-session` tried to launch `xfwm4` (`Could not find a screen
  to manage`), the panel used X11 (`libxfce4windowing: Failed to fetch _NET_NUMBER_OF_DESKTOPS`, instead
  of `Window<->Workspace association is not available`), labwc kept repositioning it (`view has
  no last placement info` ~60/s in `~/.xsession-errors`) and **the screen flickered with the panels
  different** (their configuration did not change). Fix on the spot: reboot. **Permanent fix**
  (`instalar-cambio-sin-contrasena.sh`, step 3a): `cambiar-modo-root` does **`sv once cambio-modo`**
  (one-shot runit service, `/etc/sv/cambio-modo`, with a `down` file so that it does not
  start at power-on), which runs **`/usr/local/lib/cambiar-modo/reiniciar-lightdm <uid>`**: `sv stop lightdm`, waits **event-
  driven** (`inotifywait` on elogind's state files in `/run/systemd/users` and
  `/run/systemd/sessions`) for `seat0`'s session to close and, if the user was left without
  sessions, for elogind to delete `/run/user/<uid>` (`delete_self`); caps 10 s + 5 s; then `sv start
  lightdm`. With another session open (SSH) elogind deletes nothing and it does not wait. Log in
  `/run/cambiar-modo.log`. **Why runit and not a process launched from the session:** the first
  version launched it with `setsid` from `cambiar-modo-root`; it stopped lightdm and **died with the session**
  before starting it again (log with only `parar lightdm` ("stop lightdm")): the screen stayed off and
  `ssh -t lego sudo sv start lightdm` had to be done from the IdeaPad (2026-10-04). The `sv restart`
  of before worked because runit also ran it. **Verified on the Legion on 2026-10-04**
  (Wayland → "Escritorio Wayland", the case that failed): `parar lightdm` 22:47:24.691 → `arrancar
  lightdm (0.4 s)` ("start lightdm"), `wayland-0` present and the panel through Wayland. Also installed on the IdeaPad.
  **If the screen stays off after a mode switch:** `cat /run/cambiar-modo.log` and, from
  another machine, `ssh -t <machine> sudo sv start lightdm`.
- **Here applied on 2026-10-04** (repeating `instalar-cambio-sin-contrasena.sh`: it kept the mode
  `xfce-wayland`) and **verified with the wrapper** the same day: Steam open on the desktop,
  reboot with the panel's button → `Shutdown` at 20:58:06 and, when opening it, `Verifying file sizes
  only` (before, without it, `X connection to :0 broken` and full verification). **Verified on the Legion on 2026-10-04** (reboot from Steam's menu in Game Mode):
  `Shutdown` in Steam's log, the boot mode stayed in Game Mode (the mark stopped
  `cambiar-modo-root escritorio`), and on boot `Verifying file sizes only` and the interface after 4 s.

#### Decky Loader (Game Mode plugins) — REMOVED from the IdeaPad on 2026-10-09

**The user's decision (2026-10-09):** out of this machine; **the Legion keeps it** (its recipe).
Here it had **0 plugins** and its service ran as root doing nothing. **What is lost:** Decky's
menu (plug icon in Game Mode's quick menu) and the option to install plugins. It is put back
with the first command below. Command to remove it (run by the user):

```bash
sudo sh "<disco>/Backups Linux/fish/void/steam/instalar-decky.sh" --quitar && sudo rm -rf /home/isaac/homebrew
```

`--quitar` deletes the link `/var/service/decky`, `/etc/sv/decky`, `~/homebrew/services` (the binary
`PluginLoader`, 25 MB), `~/.steam/steam/.cef-enable-remote-debugging` (Steam stops opening its debugging port
`127.0.0.1:8080` **the next time it starts**; only Decky used it) and the link
`/home/deck` (only the plugins used it). It leaves `~/homebrew/plugins` (empty) and
`~/homebrew/settings/loader.json`, **both owned by root**: hence the `rm -rf` (without root they cannot be
deleted). **The packages stay:** `inotify-tools` is also used by `reiniciar-lightdm` (mode
switch), and `psmisc` (`killall`, `fuser`, `pstree`; 1 MB) is kept the same as on the Legion. **Pending to
run and check** (*Comprobación final*).

What is below is how it was (the same as on the Legion), as a reference:

```bash
sudo sh "<disco>/Backups Linux/fish/void/steam/instalar-decky.sh"            # installs or updates
sudo sh "<disco>/Backups Linux/fish/void/steam/instalar-decky.sh" --quitar   # leaves ~/homebrew/plugins
```

It does the same as the official installer (`decky-installer/install_release.sh`) and as Bazzite
(`ujust setup-decky`), with a **runit service** instead of the systemd one:
- `~/homebrew/{services,plugins}` and **`~/.steam/steam/.cef-enable-remote-debugging`**: Decky
  connects to Steam's interface through its debugging port (`127.0.0.1:8080`), which Steam opens when
  starting if that file exists.
- The **`PluginLoader`** binary of the latest stable version (v3.2.9 on 2026-10-03), downloaded from
  GitHub; nothing is built.
- **`/etc/sv/decky`**: `PluginLoader` as root, with the variables of its `plugin_loader.service`
  (`PLUGIN_PATH`, `LOG_LEVEL`) plus `UNPRIVILEGED_USER=isaac`, `UNPRIVILEGED_PATH` and
  **`KEEP_SYSTEMD_SERVICE=1`** (without it, when updating it tries to write
  `/etc/systemd/system/plugin_loader.service`). It listens on `127.0.0.1:1337`.
- `psmisc` (`killall`: Decky restarts `steamwebhelper` with it), `inotify-tools` (see
  *Updates*) and **`/home/deck` → `/home/isaac`**
  (like Bazzite: there are plugins that take that path for granted).

**Updates:** Decky checks by itself every 6 h and they are applied with a click from its menu, as on
SteamOS. What it does not know is how to **restart itself** with runit: it detects the init through `/sbin/init`
(`runit-init`, which it does not know) and its restart does nothing. That is why the service's `run` waits,
**event-driven** (inotify: `inotifywait -m` on `~/homebrew/services`, package `inotify-tools`, and
a pipe `/run/decky-avisos` where PluginLoader also warns if it closes), for the **signal that it
finished** (its `updater.py`: downloads to `PluginLoader.new`, writes the version in
`.loader.version`, deletes `PluginLoader`, renames and, as the last step, `chmod` executable;
"different version, `PluginLoader.new` does not exist and `PluginLoader` is executable" = finished),
closes `PluginLoader` and runit starts it again. Between one event and the next nothing is polled.
**Tested with a simulation** of those steps (it woke up with each event and restarted right at the
`chmod`); **with a real update, not tested yet**.

**Verified on 2026-10-03:** after rebooting, Decky appears in the quick menu (plug icon).
Its log goes to `vlogger`, which on Void keeps nothing (there is no system log).

#### steamos-manager (built, not installed here)

It is Valve's service with which Steam handles **TDP, GPU clock, power profiles,
charge limit** and more (open source, MIT, Rust; official repository
`gitlab.steamos.cloud/holo/steamos-manager`). CachyOS packages the official one (v26.4.1, with two
patches for its session names); Bazzite too, plus PowerStation (TDP on laptops without a
firmware controller) and InputPlumber (controllers). What it controls on each machine comes from a
per-device profile (`/usr/share/steamos-manager/devices/*.toml`). **It does not need systemd to
start** (without `NOTIFY_SOCKET` it skips notifying systemd); it uses it only for specific
functions (Orca, Wi-Fi backend, fan, CPU scheduler), which without it do not appear. Its
session switch only activates with sddm/plasmalogin: with lightdm it does not clash with
`steamos-session-select`.

- **Built on 2026-10-03 on the Legion** (16 threads: 2 min 20 s), inside a Void
  container (`podman`, image `ghcr.io/void-linux/void-glibc-full`) so that it links against the same
  libraries as here; dependencies: `rust cargo clang make git pkg-config eudev-libudev-devel
  speech-dispatcher-devel glib-devel` (without `glib-devel` it fails in `glib-sys`). Checked here:
  `ldd` finds everything and `steamosctl --version` = 26.4.1. **Backed up** in
  `fish/void/steam/steamos-manager/steamos-manager-v26.4.1-void.tar.gz` (the tree of
  `make install`; in this repository, a Release asset). The build folder and the image were deleted from the Legion.
- **It is not installed on this ideapad because here it would give nothing useful:** TDP it only knows how to do with
  `amdgpu`, firmware attributes or a remote interface (nothing for Intel); the Intel GPU clock
  it looks for in `/sys/class/drm/card0/device/gt_min_freq_mhz` and with this kernel it is in
  `/sys/class/drm/card0/gt_min_freq_mhz` (it would not detect it); this laptop does not expose power
  profiles (`/sys/class/platform-profile` empty); the i3-5005U has no turbo; Lenovo's charge limit
  is `conservation_mode`, which is not among the methods it knows. And what it would do is
  `iw dev … set power_save on` (the "wifi power management" that Steam asks for), which here is not wanted.
- **On the Legion it is installed since 2026-10-04** (its recipe, step 14):
  `instalar-steamos-manager.sh` (in this folder) and the launcher of `instalar-modo-juego.sh`, which
  since that day starts the user process **only if `/usr/lib/steamos-manager` exists** (here nothing
  changes when repeating it). There `tracefs` and amdgpu's overdrive had to be mounted/set (for the manual GPU
  clock; removed by a misunderstanding and given back on 2026-10-08) and, since 2026-10-08, an
  own patch (`set_clocks` only writes the clock with the level at `manual`: without it, hundreds of `Error
  setting manual GPU clock` per session). Both, **verified on the Legion on 2026-10-08**.
- **Where it is useful is the Legion Go 2:** its model (`83N0`, Z2 Extreme) has an official profile
  (`legion-go-series.toml`: TDP through `lenovo-wmi-other-0`, GPU through `amdgpu`, `lenovo-wmi-gamezone` profiles). SteamOS already brings it.

#### xterm as a "non-Steam game"

The same as in SteamOS's recipe (§13.2, §13.6, §13.9), and with the same bug: **Steam forces
`LC_ALL=C`** on everything it launches and xterm starts without UTF-8 (fastfetch's icons and accents as
`â`, `Ã`); besides it puts its `LD_PRELOAD` (`gameoverlayrenderer.so`; here it only gives "wrong ELF
class" warnings). Wrapper **`~/.local/bin/xterm-steam`** (backed up in `fish/void/steam/`):
`unset LD_PRELOAD`, `unset LC_ALL` and, only in the Game Mode session, `xrdb -nocpp -load
~/.Xresources` (gamescope's Xwayland does not have it loaded) and the size that fills the screen
(gamescope does not maximize; `xdotool getdisplaygeometry` and the 8×18 px cell of step 11: 170×42
here). In Xfce it opens a normal xterm.

```bash
cp "<disco>/Backups Linux/fish/void/steam/xterm-steam" ~/.local/bin/ && chmod 755 ~/.local/bin/xterm-steam
```

In Steam: *Añadir un juego → Añadir un juego que no es de Steam → xterm* (*Add a Game → Add a Non-Steam Game → xterm*); then *Propiedades →
Acceso directo → Destino* (*Properties → Shortcut → Target*) = `/home/isaac/.local/bin/xterm-steam`. **Verified on 2026-10-02**
from Steam in Xfce: UTF-8 fine (fastfetch with icons and accents); **on 2026-10-03, also in
Game Mode** (the wrapper looks at `XDG_SESSION_DESKTOP=gamescope`, which `steam-modo-juego` sets).

**Library art** (cover, banner, logo and quick menu icon; made on the Legion on
2026-10-04, here not applied): `python3 "<disco>/Backups Linux/fish/void/steam/arte-xterm/generar.py"`
with Steam closed (it needs `python3-Pillow`, `librsvg-utils` and Papirus). Detail in the
Legion's recipe, step 14.

#### Matched with the Legion (2026-10-05): no loading animations and SteamOS settings

> **Note (2026-10-07, up to date on 2026-10-09):** `instalar-modo-juego.sh` (common) carries since
> 2026-10-07 the hook of SteamOS's gamescope portal (Legion recipe, step 14, "Screen sharing
> in Game Mode"): it only acts if `/usr/local/share/xdg-desktop-portal/gamescope-portals` exists,
> which **here is not installed** (nor the patched gamescope), so here nothing changes. And
> `instalar-steam.sh` (common) also installs `pipewire-32bit` and `libspa-videoconvert-32bit` (Remote Play
> in Game Mode; Steam's client is 32-bit). **Both were repeated here on 2026-10-09** with
> `ideapad-al-dia.sh` (step 16): the installed launcher is the same as Common's and both packages are there.
> Remote Play in the IdeaPad's Game Mode is still **untested**.

**In a reinstall `ideapad-como-legion.sh` is not needed:** the block of *Installation order*
already runs `como-steamos.sh` and `instalar-modo-juego.sh --sin-pantalla-de-carga`, and Plymouth is not
installed. What is below is what was done on 2026-10-05 on the installation that existed.

**The user's request:** set the IdeaPad like the Legion with what was learned there, remove the loading-screen
animations, match the desktop and the clean close of Steam, **without** Steam in the
background on the desktop. First everything was compared (2026-10-05):
- **Desktop:** it was already the same. The Legion's `xfce-perchannel-xml` against this one's: only what is
  each machine's own changes (Super+Shift+number with the symbols of its keyboard, Num Lock, screens,
  tray icons, window sizes); labwc's `rc.xml`/`autostart`/`environment` and the
  window scripts (`ventana-acoplar`, `ventana-foco`, `ventanas-nuevas`), `fondo-vigilante` and
  `brillo`, identical to Common's.
- **Clean close of Steam:** it was already there (`05-cerrar-steam.sh`, `xfce4-session` wrapper,
  `reiniciar-lightdm` with `sv once cambio-modo`, of 2026-10-04).
- **Missing:** remove Plymouth and Game Mode's loading screen, the SteamOS settings
  (`como-steamos.sh`) and the new Game Mode launcher.

```bash
sudo bash "<disco>/Backups Linux/fish/void/ideapad-como-legion.sh"   # log: ~/ideapad-como-legion.log
udisksctl unmount -b /dev/sdb4 && sudo reboot                        # Common, unmounted first
```

`ideapad-como-legion.sh` ("ideapad like the Legion"; in `fish/void/`; it only runs on `ideapad-100`; not in this repository), in order:
1. **Plymouth out**, like on the Legion: `instalar-plymouth.sh --quitar` (it removes `splash`, the theme
   `bgrt-void`, gives back `agetty-tty1`, redoes the `rc.conf` block, the initramfs and the menu with
   the theme), `xbps-remove plymouth plymouth-data`, `rm -rf /etc/plymouth` and `dracut --force
   --regenerate-all` again (already without the module); it checks with `lsinitrd` that no initramfs carries it.
2. **SteamOS settings:** the Legion's `como-steamos.sh` (in `fish/void/legion/`, common; Legion recipe,
   step 14, "SteamOS settings"): `split_lock_mitigate=0` (here it does nothing: the
   Broadwell does not have that detection), inotify, `fq_codel`, huge pages `always`, `rtkit` (only
   installed: **D-Bus starts it on demand, not runit**, since 2026-10-08; see below), `earlyoom`,
   `gamemode`, `gamescope-32bit`, `-pipewire` in `~/.local/share/applications/steam.desktop` (there is no
   Steam autostart: it says "no está" ("it is not there") and goes on), `preempt=full` in `GRUB_CMDLINE_LINUX` and
   `memlock` 8 MiB.
3. **Game Mode:** it copies `instalar-modo-juego.sh` and `instalar-steam.sh` from Common to `~/steam` (that
   copy was deleted on 2026-10-09: they were old versions, the same as Common's `.bak`) and runs
   `instalar-modo-juego.sh --sin-pantalla-de-carga` (it removes `steam-cargando`; it brings gamescope's
   layer, the FPS limiter and `-pipewire`; variable rate shading and the screen range are not
   set here: they are for an AMD GPU and for the Legion).

**Verified on 2026-10-05** after rebooting (22:30): without Plymouth (package, `/etc/plymouth` and `splash`
out), the 6 consoles with `agetty`, kernel line with `preempt=full`, `split_lock_mitigate` 0,
`fq_codel`, huge pages `always`, **PipeWire in real time** (the 4 `data-loop` in RR 20), `rtkit`
(then, as a runit service; see below) and `earlyoom` running, `memlock` 8388608 in the session, the launcher with `ENABLE_GAMESCOPE_WSI` and without
`steam-cargando`, and the desktop's Steam with `-steamdeck -pipewire`. **From GRUB's menu (still
visible, 5 s, with its theme) to the session: black screen, without animation.** Still to test a game in
Game Mode with the new layer (with the HD 5500 the Windows ones still go with `PROTON_USE_WINED3D=1`; if
one goes badly: `DISABLE_GAMESCOPE_WSI=1 %command%`).

**`rtkit` out of runit (2026-10-08, approved by the user; the same on the Legion):** `como-steamos.sh`
linked it in `/var/service` and besides D-Bus starts it on demand
(`/usr/share/dbus-1/system-services/org.freedesktop.RealtimeKit1.service`). They clashed: on the Legion
(2026-10-07) D-Bus won and runit's one exited with code 1 and was relaunched every second; here runit's
won, but the same could happen. Now `como-steamos.sh` does not link it (and if it finds
`/var/service/rtkit`, it does `sv down rtkit` and removes it). On this machine, already installed, it was removed with
`sudo sh /tmp/quitar-rtkit-runit.sh` (`sv -w 5 down rtkit` and `rm /var/service/rtkit`; it does not kill
D-Bus's `rtkit-daemon`; the user runs it). **Verified after rebooting on 2026-10-08**
(boots at 00:14 and 00:41), with the *Comprobación final*: without `/var/service/rtkit`, a single
`rtkit-daemon` with parent `runit` (D-Bus started it; never `runsv rtkit`) and the four `data-loop` in
RR 20.

**An error window on the first boot** ("El gestor de sesiones debe estar inactivo al solicitar
el apagado" — "The session manager must be idle when requesting a shutdown", from `xfce4-session-logout`): Xfce rejects a command to power off or log out that arrives
while the session is starting. It was rebooted with `sudo reboot` and no trace was left of who asked for it (the two
or three `shutdown` records of `last -x` per reboot are normal here since 2026-10-04). **When
rebooting again it did not come out.** If it comes back without touching anything: a wrapper of `xfce4-session-logout` in
`/usr/local/bin` that notes who calls it.

#### Firefox as a "non-Steam game" (2026-10-05, done on the Legion)

In Game Mode, Firefox (with "Barra de título" ("Title Bar") unchecked, step 15) draws its own frame and can be
shrunk with no way of going back to full screen. The common wrapper **`fish/void/steam/firefox-steam`**
starts it without a frame (`MOZ_GTK_TITLEBAR_DECORATION=system`) and sets it to the screen's size. Detail and
verification in the Legion's recipe, step 14, "Firefox as a game". **Here not installed** (there is no
Firefox in Steam); if it is added: `install -m 755 <that file> ~/.local/bin/` and Target =
`/home/isaac/.local/bin/firefox-steam`, with Firefox closed.

### 15. Xfce on Wayland (labwc): the normal desktop (2026-10-03)

**What it is:** the same Xfce, but the windows are handled by **labwc** (Wayland compositor) instead of
xfwm4: it is what `startxfce4 --wayland` does in Xfce 4.20, the "Xfce Session (Wayland)" session
(`/usr/share/wayland-sessions/xfce-wayland.desktop`). **It is the normal desktop** (the user's
decision, 2026-10-03, after trying it): Game Mode's "Cambiar a escritorio" ("Switch to Desktop") enters it, and Xfce
X11 stays **as a backup**. It is switched **without password** with two launchers (finder, Super+Space:
**"Escritorio Wayland"** ("Wayland Desktop") → `cambiar-modo-root escritorio`, **"Escritorio X11"** ("X11 Desktop") →
`cambiar-modo-root escritorio-x11`; step 14). **On power-on it enters the last mode used** (the
mode switch rewrites `autologin-session`): if it was powered off in X11, it powers on in X11.
**Never log in from the login screen** (step 14, *What it cost* 2). Switching session
closes the current one entirely (also Claude Code: `claude -r` in the new one). It needs step 14
(`cambiar-modo-root`, Xwayland). Verified on 2026-10-03: fastfetch says `labwc 0.20.2
(Wayland)`.

**Installation** (from Xfce X11; the pieces are in `fish/void/xfce-wayland/`). **In a reinstall
it is already done** inside the *Installation order* block of step 14, before its reboot; this is to
put it or redo it alone:

```bash
sudo sh "<disco>/Backups Linux/fish/void/steam/instalar-cambio-sin-contrasena.sh"   # escritorio = Wayland
#   (it keeps whatever autologin mode there was; the first time, Game Mode)
sudo sh "<disco>/Backups Linux/fish/void/xfce-wayland/instalar-xfce-wayland.sh"
# remove: … instalar-xfce-wayland.sh --quitar   (it leaves the labwc package)
```

What `instalar-xfce-wayland.sh` puts:
- the **`labwc`** package (0.20.2; Xwayland and `gtk-layer-shell` were already there);
- **`~/.config/xfce4/labwc/`** (the folder that `startxfce4 --wayland` uses, not `~/.config/labwc`):
  - `environment`: `XKB_DEFAULT_LAYOUT=latam`, `XKB_DEFAULT_MODEL=pc105`,
    `XCURSOR_THEME=volantes_cursors`, `XCURSOR_SIZE=24`;
  - **`lock`** (empty): without it, `startxfce4` rewrites the keyboard of `environment` reading
    `/etc/vconsole.conf`, which Void does not have, and leaves it at `en`, which does not exist;
  - `autostart`: `xrdb -nocpp -merge ~/.Xresources` in Xwayland (on X11
    `/etc/lightdm/Xsession` does it; without it, xterm comes out without palette, font or copy/paste);
    **it only works if Xwayland does not shut down** → `rc.xml` carries `<xwaylandPersistence>yes` (see below);
  - `rc.xml`, with xfwm4's settings and the shortcuts of step 13 translated (below);
- **`~/.local/bin/brillo +N|-N`** ("brightness"): brightness keys (on Wayland xfce4-power-manager cannot
  catch them), through elogind's `SetBrightness` like Game Mode: without root; never below
  5 %;
- **`~/.local/bin/fondo-vigilante`** ("wallpaper watcher") (2026-10-04, from labwc's `autostart`): when the
  screens change (GTK event: added, removed, geometry or scale) it asks `xfdesktop --reload` to
  paint the wallpaper again. On the Legion, when coming from Game Mode, `xfsettingsd` reconfigured the
  screens after painting it and the internal one stayed black (cursor and windows did show); detail in its
  recipe, step 15. **Here applied on 2026-10-04** (repeating `instalar-xfce-wayland.sh`: only
  `autostart` changed; `rc.xml` and `environment` were the same); with a single screen, untested; log `~/.local/state/fondo-vigilante.log`;
- **the Orchis theme for labwc** (`tema-labwc.sh`, below);
- the launchers `/usr/share/applications/escritorio-wayland.desktop` and `escritorio-x11.desktop`
  (`Exec=sudo -n /usr/local/bin/cambiar-modo-root …`).

**`rc.xml`** (after editing it: `labwc --reconfigure`, without logging out):
- **Like xfwm4:** 8 px gap (`<core><gap>`), new windows centered (`placement`
  `center`; now only noticed on dialogs and fixed-size ones: the rest open almost
  maximized, see *New windows* below), focus that follows the mouse **without raising** (`followMouse` yes, `raiseOnFocus` **no** since 2026-10-06: it raises with a click; step 13, *Focus*), dragging with
  Super+click (left moves, right resizes), 5 workspaces **named only "1"…"5"**
  (`<names>`; with `number="5"` they came out as "Workspace 1"…) and **no popup when switching workspace**
  (`popupTime` 0: the panel already says it).
- **Shortcuts:** those of `/commands/custom` of step 13 (Omarchy) and those of xfwm4, with the same
  keys. Those that were `xdotool` are labwc actions: Super+Q/W and Alt+F4 close, Super+F
  full screen, Super+Alt+F maximize, Super+O always on top, Super+1…5 go to the workspace,
  **Super+Shift+1…5 take the window and go** (here with the number: labwc resolves it by key,
  not by the `latam` symbol), Super+Tab / Super+Shift+Tab next / previous workspace.
  Volume with `wpctl` (the panel's plugin does not catch keys on Wayland either), brightness with `brillo`.
- **Super+Shift+arrows** (`ventana-acoplar`): `SnapToEdge` with `combine="yes"`: half; with the
  window already in a half, the arrow of an adjacent side leaves it in a **quarter**. **Almost maximized (region "llena", "full") is the intermediate step between the two halves**, inside
  the monitor (2026-10-03): left half + → = full; full + → = right half (the same with
  ↑/↓). **Towards the edge it does nothing** (← on the left half, or outwards from a quarter),
  and **the quarters never go to full** with arrows: inwards they grow to the half. (Before it was
  repeating the arrow outwards, "as if going out of the monitor": not intuitive.) In
  `rc.xml`, each arrow is a chain of `If`: dialog → `MoveToEdge`; already on that side or in one of
  its quarters (`query tiled="left"`, `"up-left"`, `"down-left"`) → `None` (nothing); on the opposite
  half → `SnapToRegion llena`; in a quarter of the other side → `SnapToEdge` to the half that
  corresponds (`combine="no"`, set by hand and not with `combine`); otherwise, `SnapToEdge combine="yes"`.
  (Before that, `ToggleSnapToEdge` released the window when repeating; with `SnapToEdge` without `combine`
  there were only halves.)
  (In this repository the region is called `full`: `common/xfce-wayland/labwc/rc.xml`.)
  **Fixed-size windows** (e.g. the Docklike's preferences): labwc counts them as
  `type="dialog"` (also those that have a parent window; labwc's code, `src/xdg.c`), and with
  `ToggleSnapToEdge` they ended up halfway, in the corner of the half. That is why they go with
  `If query type="dialog"` → **`MoveToEdge`** (`snapWindows="no"`): they stick to the edge without changing
  size and, chaining two arrows, to the corner, like in `ventana-acoplar`. **It cannot be matched
  entirely** (labwc does not give the windows' position nor remember the previous key): they are not centered
  on the other axis (they stay where they were on it; as the new ones come out centered, the first arrow
  does leave them centered) and repeating the arrow does not release them. Instead, **Super+Shift+Space**
  takes them back to the center (`UnSnap` + `AutoPlace policy="center"`; see below, *New windows*).
  This (option A) was chosen against centering on each arrow, which lost the corners.
- **Super+arrows** (`ventana-foco`): **labwc's `<default/>` uses them to snap** (that is why at
  first they moved windows): they are overridden. labwc has no focus by direction nor lets one know where
  each window is, so they go with `ForEach`: focus and raise the **snapped** window of that
  side (`tiled="left"`, `"up-left"`, `"down-left"`…) of the current workspace. If on that side there is
  no snapped one (loose windows), plan B with the `<none>` branch: ←/↑ previous window
  (`PreviousWindowImmediate`) and →/↓ next (`NextWindowImmediate`), in Alt+Tab's order and
  without its menu: it is not by real direction, but the key never ends up doing nothing.
- **New windows almost in full screen** (the user's request, 2026-10-03): a region
  `llena` (`<regions>`, x/y 0 % and 100 % × 100 %: the usable area, without the top panel) and a rule
  (`<windowRules>`) that snaps to it **each window when it opens**: it ends up like maximized but with
  the 8 px gap on the four edges and under the panel. The rule is `identifier="*"`, not
  `type="normal"`: XWayland ones without `_NET_WM_WINDOW_TYPE` (xterm) do not count as "normal" and did not
  snap (tested). Afterwards the dialogs and fixed-size ones (`type="dialog"`) and the application finder
  (`xfce4-appfinder`) are **released** (`UnSnap`), and they stay centered. Being a snap,
  Super+Shift+arrows works the same on them. **Super+Shift+Space takes
  each window back to its home position** (the user's request, 2026-10-03): those that can be
  resized, to the `llena` region (almost maximized, 8 px gap); dialogs, fixed-size ones
  and the finder, to the center (`If query type="dialog"` / `identifier="xfce4-appfinder"`). Verified with screenshots: xterm almost in full screen,
  finder centered.
- **Firefox and Steam with only labwc's border** (2026-10-03): both draw their own bar
  (Firefox, CSD with the tabs; Steam, Xwayland with `_MOTIF_WM_HINTS` without decoration) and labwc did not
  give them a frame nor the teal focus border. Per-application rule with **`SetDecorations
  decorations="border" forceSSD="yes"`**: only the border (and the resize area), **without labwc's
  bar**; `forceSSD` makes it apply even if the window asks to decorate itself. Identifiers:
  `firefox` (native Wayland, `MOZ_ENABLE_WAYLAND=1`) and `steam` (Xwayland, `WM_CLASS`
  `"steamwebhelper", "steam"`). **In Firefox, "Barra de título" ("Title Bar") UNCHECKED** (☰ → Más
  herramientas → Personalizar barra de herramientas… / More tools → Customize toolbar…): with it checked Firefox asks the
  server for decoration and, with only the border, it would be left without bar or buttons. **It is the default:** in Firefox
  157.0.1 the default value of `browser.tabs.inTitlebar` is **2** ("automatic"), and in Xfce that gives
  tabs in the title bar (`drawInTitlebar` = true), that is, "Barra de título" unchecked. Checked
  on 2026-10-09 by asking a headless Firefox, with a temporary profile, through Marionette. The
  value is compiled in (it is not in `omni.ja`). Here `prefs.js` does not have it (the default applies). On the
  Legion it is set to 1 (same effect). **In a reinstall nothing has to be done**, unless an
  old profile is restored: to the profiles from before Firefox's migration 135
  (`ProfileDataUpgrader`) without their own value, on desktops that are not GNOME, Firefox sets 0 (title
  bar checked). Then, uncheck it. The user confirmed on 2026-10-09 that it looks fine, without two
  bars. **Before** (until
  2026-10-03) Firefox carried `serverDecoration="yes"` and "Barra de título" checked; with Steam that
  way put **two bars with the buttons repeated** (Steam cannot remove its own), and the
  user preferred the border alone for both. It applies to windows opened afterwards.
- **Exception: Steam's on-screen keyboard** (2026-10-04, found on the Legion; same
  `rc.xml`): it is a Steam window of type `_NET_WM_WINDOW_TYPE_UTILITY` ("Teclado en pantalla de
  Steam Input" — "Steam Input On-Screen Keyboard") and the `llena` region and the forced border fell on it. Rule at the end, by type (it does not
  depend on the language): `<windowRule identifier="steam" type="utility">` with `UnSnap` and
  `SetDecorations decorations="none"`: it comes in with its size, position and look. Applied here and on
  the Legion on 2026-10-04 (`mv` + `kill -HUP $(pgrep -x labwc)`).
- **Alt+Tab like xfwm4** (`cycle_tabwin_mode` 0 + `cycle_preview`): `windowSwitcher` with
  `style="thumbnail"` (grid of thumbnails with the title; the default one is a text
  list), `preview` and `outlines`.
- **Borders:** theme `Orchis-Teal-Dark-Compact`, buttons like xfwm4's `button_layout` `O|SHMC`
  (`menu:shade,iconify,max,close`), 8 px corners, shadows, titles in JetBrainsMono NFM Blocks
  Bold 9 (like xfwm4), menus and popups in Bold 10, Papirus-Dark icons.

**`tema-labwc.sh`** ("labwc theme") (without sudo; the installer runs it): Orchis does not bring a labwc theme, so it
builds it from the xfwm4 one of `~/.themes` (step 10) in `~/.local/share/themes/Orchis-Teal-Dark-Compact/
labwc/` (it does not touch `~/.themes`, which is restored whole from the `.tar.gz`): the buttons' SVGs
renamed as labwc looks for them (`hide`→`iconify`, `maximize`→`max`, `maximize-toggled`→
`max_toggled`, `prelight`→`_hover`) and a `themerc` with the colors and sizes of the `.xpm`: title bar
of 34 px `#2C2C2C` (active) / `#333333` (inactive), 2 px border, white text / white at 50 %.
**The border of the focused window is teal `#4DB6AC`**, like Alt+Tab's outline (the others, gray).
**Alt+Tab and popups with the colors of the bottom panel** (Orchis, `.xfce4-panel.background`):
background `#212121a6` (65 % opaque), text `#ffffffb3`, no border, the selected one with a white veil
`#ffffff1f`; the outline of the real window in teal `#4DB6AC`. **Those corners cannot be
rounded**: labwc 0.20 only has `cornerRadius` (windows) and the one of the buttons' highlight
(checked in `labwc-theme(5)`); labwc would have to be patched and built (discarded).

**Bottom panel:** it always hides, in both sessions (step 13). The "intelligently"
mode cannot work on Wayland: the panel asks where each window is and labwc does not
say it (on Wayland that is private), so it never hid.

**What there is not on Wayland:** screen lock (`xfce4-screensaver` is X11 only), the shortcuts of
`xfce4-keyboard-shortcuts` (they go in `rc.xml`) and the scripts with `xdotool`. **And the Docklike cannot filter by workspace**
("Only show applications on the current workspace" stays checked but does nothing: it shows the
windows of all of them): the window list that labwc gives (`wlr-foreign-toplevel`) does not say which
workspace each one is on, and `libxfce4windowing` (code of `xfw-window-wayland.c` /
`xfw-screen-wayland.c`) only knows it with Xfce's own protocol
(`xfce-foreign-toplevel-management-private-v1`), which labwc does not implement; without it, it returns "no
workspace". It has no fix through configuration (with swayfx, the same). By workspace, what does work is
Alt+Tab, Super+arrows and the panel's workspace indicator (2026-10-03). See *Pendientes*.

**Check** (inside the session): `echo $XDG_SESSION_TYPE` → `wayland`; `pgrep -a labwc` →
`labwc --config-dir ~/.config/xfce4/labwc …`; fastfetch → `labwc 0.20.2 (Wayland)`.

#### Desktop wallpaper on Wayland: patched xfdesktop (2026-10-09; installed and verified)

**The bug:** in Xfce Wayland, choosing a wallpaper in the dialog (right click on the desktop →
Configuración del escritorio / Desktop Settings) **did nothing** since 2026-10-03; on X11 it does work. `xfdesktop`
4.20.2 reads the wallpaper from `/backdrop/screen0/monitor<connector>/workspace<N>/last-image` (here
`monitoreDP-1`), but the dialog (`xfdesktop-settings`) takes the monitor's name from
`gdk_monitor_get_model`, which on Wayland is not the connector, and writes to `monitorUnknown/…` (and to the old
key `monitor0/image-path`), which nobody reads. Checked on 2026-10-09: writing by hand to
`monitoreDP-1/workspace0/last-image` changes the wallpaper instantly. It is upstream's bug
[#350](https://gitlab.xfce.org/xfce/xfdesktop/-/issues/350) (and #413, with labwc). **Meanwhile** the
wallpaper set is `/usr/share/backgrounds/xfce/xfce-cp-dark.svg`, written by hand in that key.

**The fix:** upstream's commit **`ed26b06a`** ("Use XfwMonitor in backdrop settings instead of
GdkMonitor", MR !227 in the `xfce-4.20` branch; in master, !226; it closed #350 on 2026-05-25): the dialog takes
the **connector** from `libxfce4windowing`, the same one `xfdesktop` uses. It asks for `libxfce4windowing` >= 4.20.6
(Void has 4.20.7, with the two functions it uses). Upstream's was chosen and not openSUSE's
(bsc#1247542), which does the same in its own way, because it is the one the next version will bring. **On
2026-10-09 it is not in any published version** (the latest of the series is 4.20.2; it is already in the
`xfce-4.20` branch). When Void brings it, this package is no longer needed: the patch test says so (step 6, *Testing
own patches*), in `update-system` and in `compilar-xfdesktop.sh`, which then does not build.

**The pieces** (`fish/void/xfce-wayland/xfdesktop-fondo/`; in this repository, `common/xfce-wayland/xfdesktop-wallpaper/`):
- `0001-backdrop-settings-xfwmonitor.patch`: commit `ed26b06a` as it is (it applies clean on 4.20.2);
- `compilar-xfdesktop.sh` (without root): Void's template with the patch and **Void's revision + 1**
  (`4.20.2_2`), with `xbps-src` in `~/src/void-packages` (same scheme as gamescope and the Legion's
  portal);
- `xfdesktop-4.20.2_2.x86_64.xbps` (sha256 `6f36c3908bd2ea75e834f268ce8194a58894c95e26f9c181d738d441579446d0`):
  **built on the Legion** on 2026-10-09 and the same for both machines (here it also builds, 5 min
  29 s, but that one is used). Same list of files as Void's; `xfdesktop-settings` carries
  `xfw_screen_get_monitor_from_gdk_monitor` and `xfw_monitor_get_connector`;
- `instalar-xfdesktop-fondo.sh` (root): checks `libxfce4windowing` >= 4.20.6, builds a temporary local
  repository in `/tmp` with the `.xbps` (the path of `Common` has a space, which xbps does not accept as a
  repository), installs it (asks to confirm) and checks the version. It does not touch the chosen wallpaper nor restart
  anything.

**Installation** (in the session, with `Common` mounted):

```bash
# installs xfdesktop 4.20.2_2 (asks for the password and to confirm):
sudo bash "/run/media/isaac/Common/Backups Linux/fish/void/xfce-wayland/xfdesktop-fondo/instalar-xfdesktop-fondo.sh"
# to rebuild (if Void goes up in version or revision; it tests the patch first), without root:
#   bash "<disco>/Backups Linux/fish/void/xfce-wayland/xfdesktop-fondo/compilar-xfdesktop.sh"
#   and copy ~/src/void-packages/hostdir/binpkgs/xfdesktop-*.xbps to that folder; then rm -rf ~/src/void-packages
```

**Check** (in Xfce Wayland, with the wallpaper dialog closed before installing): in an xterm,
`xfconf-query -c xfce4-desktop -m` (it monitors); open the dialog and choose a wallpaper: there must come out
`/backdrop/screen0/monitoreDP-1/workspace0/last-image` (not `monitorUnknown`) and the wallpaper change at
once. `xbps-query -p pkgver xfdesktop` → `xfdesktop-4.20.2_2`. **Verified on 2026-10-09:** installed `xfdesktop-4.20.2_2`;
the dialog wrote `monitoreDP-1/workspace0/last-image` (`xfce-leaves.svg`) and the wallpaper changed at once;
`update-system --resumen` → 5 × OK.

**Updates:** `update-system` watches it (step 6, summary) **testing the patch** against Void's
code (since 2026-10-09; before it assumed "fixed in >= 4.20.3"): OK with the one here while it is still
needed, NOTE with the command to go back to Void's if Void already brings it, WARNING if Void's
replaced it without bringing it or if the patch no longer applies. If a Void update is going to replace it, it says so
before confirming (and whether the new one already brings it).

#### Wallpaper from Thunar on Wayland: patched Thunar (2026-10-09; installed and verified)

**The bug:** in Xfce Wayland, right click on an image → **"Establecer como fondo de pantalla"** ("Set as wallpaper") does not
change the wallpaper. Thunar's wallpaper plugin (`plugins/thunar-wallpaper/twp-provider.c`) names the
monitor with `gdk_monitor_get_model`: on X11 that is the connector (`eDP-1`); on Wayland it is the model
(`Unknown`), and it writes to `/backdrop/screen0/monitorUnknown/workspace0/last-image` (and to the old key
`monitor0/image-path`), which `xfdesktop` does not read. Verified on 2026-10-09 with `Thunar-4.20.9_1`. **No
fix upstream** that day (neither in `thunar-4.20.10`, nor in the `xfce-4.20` branch, nor in `master`).

**The patch (own, written so that it can be sent upstream):**
`0001-wallpaper-use-the-monitor-connector-name.patch`. A new function, `twp_get_monitor_name()`, asks
`libxfce4windowing` for the connector as `xfdesktop` does since its commit `ed26b06a`
(`xfw_screen_get_default` → `xfw_screen_get_monitor_from_gdk_monitor` → `xfw_monitor_get_connector`) and,
if it does not find it, uses what was there before (`gdk_monitor_get_model`). The screen is still chosen the same way: the
one of Thunar's window (`gdk_display_get_monitor_at_window`, with more than one screen). **Also on X11:**
there it gives exactly the same name as before (`libxfce4windowing` takes the X11 connector precisely from
`gdk_monitor_get_model`, commented in its code), so a single path for both, like `xfdesktop`.
`libxfce4windowing` (>= 4.20.6) comes in as an **optional** dependency in `configure.ac`
(`XDT_CHECK_OPTIONAL_PACKAGE`; Thunar 4.20 did not use it) and in the plugin's `Makefile.am`: without it
it builds as before. What does **not** change: on Wayland the active workspace is not known (an
X11-only function) and the one of `single-workspace-number` is used (here, 0).

**Version: 4.20.10, not 4.20.9.** On 2026-10-09 Void's template moved to `Thunar-4.20.10_1` (the
binary package was not yet in the mirror): building 4.20.9 would leave a package that the next
update would replace without the patch. **`Thunar-4.20.10_2`** was built (Void's template + 1);
it also brings upstream's fixes of 4.20.10.

**The pieces** (`fish/void/xfce-wayland/thunar-fondo/`; in this repository, `common/xfce-wayland/thunar-wallpaper/`):
- the patch;
- `compilar-thunar.sh` (without root): `xbps-src` in `~/src/void-packages`, revision + 1; **before building
  it tests the patch** against the code of Void's template (step 6, *Testing own patches*; since
  2026-10-09, before it looked for one line with `grep`): YA_INCLUIDO → it does not build; CONFLICTO → it stops. It adds to the template `xfce4-dev-tools` and company
  (it changes `configure.ac`: the `configure` is regenerated with `xdt-autogen`), `libxfce4windowing-devel` **and**
  `libwnck-devel libXrandr-devel wayland-devel` (its `.pc` asks for them in `Requires.private`; without them
  `configure` reported it as "not found" without failing), and a `post_configure` that fails if `config.h` does not bring
  `HAVE_LIBXFCE4WINDOWING`;
- `Thunar-4.20.10_2.x86_64.xbps` (sha256 `70ccff54505dd70d09f6cdd0d00925c8113a1810843d480da0c351bab060999b`)
  and `Thunar-devel-4.20.10_2.x86_64.xbps` (`17480c9d…`, not needed: it is not installed on either),
  **built on the Legion** (1 min 2 s) and the same for both machines. Same list of files as
  the installed `Thunar`; `thunar-wallpaper-plugin.so` links `libxfce4windowing-0.so.0`; without compiler
  warnings in `twp-provider.c`;
- `instalar-thunar-fondo.sh` (root): like the `xfdesktop` one (checks `libxfce4windowing`, temporary repository
  in `/tmp`, asks to confirm) and at the end checks that the plugin links `libxfce4windowing`.
  **An installer separate from the `xfdesktop` one**, on purpose: each package has its folder, its pace (upstream
  will fix one before the other) and its line in `update-system`; the `xfdesktop` one is already installed.

**Installation** (in the session, with `Common` mounted):

```bash
# installs Thunar 4.20.10_2 (asks for the password and to confirm):
sudo bash "/run/media/isaac/Common/Backups Linux/fish/void/xfce-wayland/thunar-fondo/instalar-thunar-fondo.sh"
# close Thunar (it has the old plugin loaded), as the user:
thunar -q
# to rebuild (if Void goes up in version or revision), without root:
#   bash "<disco>/Backups Linux/fish/void/xfce-wayland/thunar-fondo/compilar-thunar.sh"
#   and copy ~/src/void-packages/hostdir/binpkgs/Thunar-*.xbps to that folder; then rm -rf ~/src/void-packages
```

**Check** (in Xfce Wayland): in an xterm, `xfconf-query -c xfce4-desktop -m`; open Thunar, right
click on an image → "Establecer como fondo de pantalla": there must come out
`/backdrop/screen0/monitoreDP-1/workspace0/last-image` (not `monitorUnknown`) and the wallpaper change at
once (it also keeps writing `monitor0/image-path`, the old format: harmless).
`xbps-query -p pkgver Thunar` → `Thunar-4.20.10_2`. **Verified on 2026-10-09:** installed, after
`thunar -q` the menu wrote `monitoreDP-1/workspace0/last-image` (`xfce-light.svg`) and the wallpaper changed at
once; `update-system --resumen` → 6 × OK.

**Updates:** `update-system` watches it (step 6, summary) **testing the patch** against Void's
code (since 2026-10-09; before it assumed "fixed if Void's plugin links
`libxfce4windowing`"): OK while it is still needed, NOTE with `sudo xbps-install -Sf Thunar && thunar -q`
if Void already brings it, WARNING if it replaced it without bringing it or if the patch no longer applies.

## Troubleshooting

### After switching mode, the screen flickers and the panels look different

Seen on the Legion on 2026-10-04: the Wayland session started without its socket (`ls /run/user/1000`
without `wayland-0`) and everything fell to X11 through Xwayland (`grep -c 'view has no last placement info'
~/.xsession-errors` grows without stopping). Cause: race with elogind when restarting lightdm (step 14,
"Race with elogind when switching mode"). On the spot: reboot. Permanent: `reiniciar-lightdm`
under runit (`instalar-cambio-sin-contrasena.sh`). **If instead the screen stays off**
after switching mode: lightdm did not start again (`cat /run/cambiar-modo.log` without "arrancar
lightdm" ("start lightdm")); from another machine, `ssh -t <machine> sudo sv start lightdm`.

### `Common` does not mount: "wrong fs type, bad option, bad superblock"

Seen on 2026-10-04 after a reboot with `Common` mounted. `sudo dmesg | grep ntfs3` → `volume is
dirty and "force" flag is not set!`: the volume was marked **dirty** (it was not unmounted
cleanly); `ntfs3` does not mount it for writing. The data was fine. In order:

1. **Read it without touching it:** `udisksctl mount -b /dev/sdb4 -o ro` (read-only; check that the
   latest changes are there).
2. **Remove the mark:** `udisksctl unmount -b /dev/sdb4 && sudo ntfsfix -d /dev/sdb4` (that day
   it corrected `$MFTMirr` record 3 and emptied the journal) and mount it normally.
3. **Full check** the next time the Windows on the XS1000 is booted (with `Common`
   unmounted here): Terminal (administrator) → `Get-Volume -FileSystemLabel Common` (letter) →
   `chkdsk D: /f`; power off with **Shift + Apagar** (Shift + Shut down). That day: "sin encontrar problemas" ("found no problems").

So that it does not happen: **unmount `Common` before rebooting or powering off** (`udisksctl unmount -b /dev/sdb4`).

### `xbps-install` installs nothing and asks to update xbps

Step 1: `sudo xbps-install -Syu xbps` and repeat.

### SSH: "Connection reset by peer" right after updating

Old `sshd` in memory after updating OpenSSH. `sudo sv restart sshd` on the machine.

### `sv status` says "access denied" / "unable to change to service directory"

The first is lack of root (`sudo sv status …`). The second is that the service does not exist:
the package did not get installed (it is usually what is in step 1).

### SSH stutters / ping to the router of hundreds of ms

See step 4, *Wi-Fi: NetworkManager with iwd*. Check first that the Wi-Fi is still on
iwd (`pgrep -x iwd` yes, `pgrep -x wpa_supplicant` no) and to which node and with which signal it is
(`iwctl station wlp3s0 show`). Measure with `iw event -t` + `ping -D`: if there are continuous
scans, it is the original problem; if there are none, the isolated peaks are from the environment (step 4,
comparison). **Do not pin the BSSID again** except as a conscious way back.

### The Wi-Fi does not connect / iwd sees no network

**First: `wifi-reparar`** (step 4); it does what is in this list by itself. By hand:

- `iwctl station wlp3s0 get-networks` empty (not even the neighbor networks): iwd's intermittent
  failure. `wifi-vigilante` fixes it by itself in ~1 min; by hand, `sudo sv restart iwd` and then
  `sudo sv restart NetworkManager`.
- `iwctl` sees networks but `nmcli dev wifi list` does not: NetworkManager got out of sync with iwd.
  `sudo sv restart NetworkManager`.
- `nmcli c up @WIFI_SSID@` fails "without a reason": iwd does not know the network. Connect once with
  `iwctl station wlp3s0 connect @WIFI_SSID@` (asks for the password).
- In `/var/log/wifi-vigilante.log`, after an ordered restart (version of 2026-10-09):
  `iwd tiene la estación (aviso de D-Bus a los N s)` is the normal thing. `iwd no avisó de la estación en
  20 s` means that the cap kicked in: NetworkManager started anyway, but it is worth checking whether iwd
  started (`pgrep -x iwd`, `iwctl station wlp3s0 show`). Going back to the previous version of the watcher:
  `sudo cp /etc/sv/wifi-vigilante/run.bak /etc/sv/wifi-vigilante/run.nuevo && sudo mv
  /etc/sv/wifi-vigilante/run.nuevo /etc/sv/wifi-vigilante/run && sudo sv restart wifi-vigilante`
  (if `run.bak` was deleted, it comes from Common's `wifi-reparar.bak`; but `wifi-reparar` will change it
  again for its own: its `.bak` would also be needed).

### It stays on the Lenovo logo and does not enter the session

(Only with Plymouth installed; removed on 2026-10-05.) Step 8, *The Lenovo logo*: log in over SSH (Ctrl+Alt+F2 does not work with the console blocked), `sudo sh diag-vt.sh` and, if needed,
`instalar-plymouth.sh --quitar`. Known cause: something closed Plymouth before lightdm.

### Game Mode gets stuck or a lock screen comes out on top

Step 14, *If it gets stuck*: Ctrl+Alt+F2, log in, `pkill -KILL -x gamescope-wl` and
`sudo sv restart lightdm` (it enters by itself in the autologin mode). To see why:
`~/.local/state/steam-modo-juego.log`, `~/.local/state/steamos-session-select.log` and
`sudo sh diag-lightdm.sh`. If **it asks for a password when switching mode**: check
`sudo -n /usr/local/bin/cambiar-modo-root --puede` ("can") (if it fails, repeat
`instalar-cambio-sin-contrasena.sh`, which validates the `sudoers` rule again). If the
**login screen** comes out, do not enter the direct session from it (*What it cost* 2): choose
"Xfce Session" or the X one "Steam (Modo Juego)".

### When switching mode an old message is seen (e.g. `unix_chkpwd[…]: password check failed`)

Here there is no system log (`/dev/log` does not exist), so what is sent to syslog is written
on text console 7, the same as X and gamescope, and it stays there: it is seen for an instant on each
mode switch. **Look at the process number:** if it is always the same, it is an old leftover (on
2026-10-03, one from the early morning; no program sent it again). Delete it:
`sudo sh -c 'printf "\033[H\033[2J" > /dev/tty7'`. To know who really sends messages:
`sudo sh "<disco>/Backups Linux/fish/void/steam/capturar-avisos.sh"` (temporary runit service
that listens on `/dev/log` and notes time, process, parent and grandparent in `/var/log/capturar-avisos.log`;
`--parar` (stop) removes it). From the session it does not work: elogind closed it when restarting lightdm.

### `ideapad-100.local` does not resolve

`avahi-daemon` is not in `/var/service` or is not running. On the machine that asks,
`nss-mdns` is needed in `nsswitch.conf` (the Legion has it).

### In Xfce Wayland, choosing a wallpaper does nothing

The dialog writes to `monitorUnknown` and `xfdesktop` reads `monitoreDP-1` (step 15, *Desktop wallpaper
on Wayland*). Fix: `instalar-xfdesktop-fondo.sh` (or Void's, if `update-system` says it already brings it). On the spot,
without root: `xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -s
<image>` (`-n -t string` if the key does not exist). If with the patched one it is still the same: `xbps-query -p pkgver
xfdesktop` (did an update replace it? `update-system --resumen` says so).

### In Xfce Wayland, Thunar's "Establecer como fondo de pantalla" ("Set as wallpaper") does nothing

Thunar writes to `monitorUnknown` (step 15, *Wallpaper from Thunar on Wayland*). Fix:
`instalar-thunar-fondo.sh` and `thunar -q`. If with the patched one it is still the same: `xbps-query -p pkgver Thunar`
(did an update replace it? `update-system --resumen`) and that no old Thunar is left open
(`pgrep -a thunar`; `thunar -q`). Meanwhile, `xfdesktop`'s wallpaper dialog does work.

### Known noise in the logs (harmless)

Reviewed on 2026-10-08 (in `~/.xsession-errors`); left like that on purpose. Message → cause → why it is not
touched. The Legion's, in its recipe.

- **`xfce4-pulseaudio-plugin-WARNING … pa_context_connect() failed: Access denied`** (once or twice when
  the session starts) → race with `pipewire-pulse`, which is not ready yet; the plugin retries every
  5 s and connects. Fixing it event-driven would need more pieces than the warning itself.
- **WirePlumber: `optional component 'support.logind' … failed to load`** and `skipping component
  'monitor.bluez.seat-monitoring'` (each session) → `wireplumber-elogind` is missing; the component is
  optional and Bluetooth audio works. **Do not install `wireplumber-elogind`:** it would make
  WirePlumber release the Bluetooth when the seat is not active, and with lightdm's session switches
  (Game Mode ↔ desktop) it could cut the headphones.
- **`xrdb: Can't open display ''`**, `xrdb: No such file or directory` and
  **`dbus-update-activation-environment: error: unable to connect to D-Bus: Unable to autolaunch a
  dbus-daemon without a $DISPLAY for X11`** (Wayland session) → `/etc/lightdm/Xsession` runs before
  labwc and there is no X display yet; the resources are loaded later in Xwayland (labwc's `autostart`, step
  15). Silencing it would require modifying that package file (today it is as `lightdm` brings it: checked on
  2026-10-08 against xbps's sha256, here and on the Legion), and an update would overwrite it.
