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
> recipe uses, see [`docs/reference/`](../reference/)). `voidlinux` is the public default password of the Void
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

