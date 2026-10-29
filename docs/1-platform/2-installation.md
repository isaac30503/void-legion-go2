# Installation

Void Linux from its live ISO onto the whole internal disk. Everything else in this repository goes on top.

## Install

1. **Live:** `void-live-x86_64-20250202-xfce.iso` (booted from a USB with Ventoy). Over SSH, if wanted: on the
   live `sudo sv up sshd` (user `anon`, password `voidlinux`, the ISO's public default) and `ip a` for the IP.
2. **Nothing of the internal disk mounted** (trap 1, below). Then `sudo void-installer`:

| Setting | Value |
|---|---|
| Keyboard | `us-acentos` |
| Source | **Local** (copies the live: Xfce + lightdm) |
| Hostname | **`Legion-Go-Gen-2`** (`ssh lego` and mDNS use it) |
| Locale / Timezone | `es_MX.UTF-8` / `America/Mexico_City` |
| User | `isaac` (in `wheel`; the installer adds `audio video kvm floppy cdrom optical users xbuilder`). Add to `network` (`sudo usermod -aG network isaac`) so gamescope/Steam can manage Wi-Fi connections via polkit without an interactive desktop agent. |
| Bootloader | **`/dev/nvme0n1`** |
| Partitions (`cfdisk`, `gpt`) | delete all the old ones and create: `p1` 500M *EFI System* · `p2` **32G** *Linux swap* · `p3` the rest (921.4G) *Linux filesystem* |
| Filesystems | `p1` vfat → `/boot/efi` · `p2` swap · `p3` **btrfs** → `/` (no subvolumes; `/home` is a folder) |

The 32 GB swap (= the RAM) is what makes [hibernation](../3-hardware-support/2-power.md) possible (the only
suspend is `s2idle`, which drains the battery).

3. **When it finishes:** the installer leaves `NetworkManager`, `lightdm`, `dbus`, `polkitd`, `chronyd`, `udevd`,
   the `agetty` and `sshd` enabled, and writes its own firmware entry. **From here on, nothing writes to the
   firmware.** Take `polkitd` out of runit at the first boot, `sudo rm /var/service/polkitd`: D-Bus starts it on demand
   (`org.freedesktop.PolicyKit1.service`), and with both, whichever loses the race at boot is relaunched by `runsv`
   once a second (seen on the IdeaPad on 2026-10-23; on both machines since 2026-10-24, as `rtkit` since 2026-10-08).
   **Check:** `ps -o pid,ppid,args -C polkitd` → one `polkitd`, PPID 1. If something was mounted under `/mnt` in the live (e.g. the old `/home`), the installer copied those
   empty folders: check that they are empty and not mounted, then remove them:

   ```bash
   ls -A /mnt/home /mnt/steamos-home; findmnt /mnt/home /mnt/steamos-home   # nothing
   sudo rmdir /mnt/home /mnt/steamos-home
   ```

4. **Let the IdeaPad in over SSH** (no mDNS yet: by IP), on the Legion:

   ```bash
   mkdir -p ~/.ssh && ssh isaac@<IdeaPad IP> cat .ssh/id_ed25519.pub >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
   ```

## Traps

- **Trap 1 — a partition still mounted.** If an old partition is mounted (e.g. the previous system's `/home`,
  `p8`), `cfdisk` cannot delete it, the kernel does not load the new table and swap and btrfs do not fit. Close
  whatever has files open there (it was Firefox), then:

  ```bash
  sudo umount -A /dev/nvme0n1p8 && sudo partx -u /dev/nvme0n1; lsblk /dev/nvme0n1
  ```

- **Trap 2 — `void-installer` remembers old assignments** in `/tmp/.void-installer.conf` (readable by everyone,
  **with the passwords in plain text**; gone when the live powers off). An assignment to a partition that no longer
  exists still shows in *Filesystems*. Remove it before *Install*:

  ```bash
  sudo sed -i "/^MOUNTPOINT \/dev\/nvme0n1p8 /d" /tmp/.void-installer.conf
  grep ^MOUNTPOINT /tmp/.void-installer.conf     # only p1, p2 and p3
  ```

To keep data of a previous system before wiping, mount its partition read-only and without touching its journal:
`sudo mkdir -p /mnt/steamos-home && sudo mount -o ro,noload /dev/nvme0n1p8 /mnt/steamos-home`.
