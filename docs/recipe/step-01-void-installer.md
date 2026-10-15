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

