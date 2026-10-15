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

