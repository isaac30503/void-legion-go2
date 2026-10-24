# Storage

The internal disk is the installation's ([installation](../1-platform/2-installation.md)). Two more:

- **microSD** (`mmcblk0p1`, ext4, UUID `@MICROSD_UUID@`): a **Steam library** and emulator files, mounted by the
  system at boot at **`/mnt/microsd`**, before any session, so it is there in Game Mode too.
- **External Kingston XS1000 SSD:** an NTFS partition (`/dev/sda4`) and a Windows that boots from the firmware
  ([boot](../1-platform/3-boot.md)). Mounted only by hand, from the graphical session.

## IdeaPad only: BFQ on the internal disk

```bash
sudo sh "$B/common/disk/ideapad-bfq.sh"     # --remove: back to mq-deadline
```

The IdeaPad's internal disk is mechanical (WD10JPCX). BFQ shares it between processes and favours the interactive
ones; with `mq-deadline` a big read or write could stall the desktop. The rule
(`/etc/udev/rules.d/60-ideapad-ioscheduler.rules`) asks for `rotational=1` **and** `DRIVERS=="ahci"` (the internal
SATA controller): the XS1000 by USB also says `rotational=1` and BFQ only costs CPU on an SSD (corrected on
2026-10-09). Not `ENV{ID_BUS}`: `60-persistent-storage.rules` sets it, after this file. **Check:**
`cat /sys/block/sda/queue/scheduler` → `[bfq]`; the XS1000 → `[mq-deadline]`. `noatime` and the other tweaks of
that day are in the IdeaPad's recipe in Common, step 16.

## microSD

With **Steam closed** (it rewrites its library list on exit; the script refuses if it is open):

```bash
sudo sh "$B/legion/microsd-at-boot.sh"     # --remove undoes it
```

- **`/etc/fstab`** (leaves `fstab.bak`): `UUID=@MICROSD_UUID@ /mnt/microsd ext4 defaults,noatime,nofail,x-gvfs-show 0 0`.
  **`nofail` is essential:** on Void a failed `mount -a` at boot opens the emergency console
  (`/etc/runit/core-services/03-filesystems.sh`); with it, the system boots without the card. `x-gvfs-show`: it
  shows in Thunar.
- If the desktop had mounted it at `/run/media/isaac/<UUID>`, it moves it to `/mnt/microsd` and changes that path
  in Steam's two `libraryfolders.vdf` (`~/.local/share/Steam/config/` and `…/steamapps/`).
- **On a fresh system** Steam does not know it yet: in Steam, add a library choosing `/mnt/microsd` (Steam reads
  the card's own `libraryfolder.vdf` and finds the games already there).

**Check:** `findmnt /mnt/microsd` → `/dev/mmcblk0p1 ext4 rw,noatime`; in
`~/.local/share/Steam/logs/content_log.txt`, `Mounted library folder "/mnt/microsd"`.

**Problem — the microSD games show as not installed:** `findmnt /mnt/microsd`; if it is not mounted (is the card
in?), `sudo mount /mnt/microsd` and close and open Steam. Steam must have that path:
`grep '"path"' ~/.local/share/Steam/config/libraryfolders.vdf`. If it shows another path, run
`microsd-at-boot.sh` again with Steam closed.

## XS1000

Unmount it before rebooting, hibernating or booting its Windows. If it does not mount (`wrong fs type…`,
`volume is dirty`), see [boot, problems](../1-platform/3-boot.md#problems).
