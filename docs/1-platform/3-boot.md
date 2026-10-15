# Boot

From the firmware logo straight to the session: **hidden GRUB** (0 s) booting the newest kernel, a **silent
boot**, no Plymouth. GRUB also carries an entry for the **Windows on the external Kingston XS1000** and the
themed menu "void-xterm", both unseen while GRUB is hidden. The kernel is **held in the 6.18 series** (the fine
TDP modules are built for it).

**When:** after the login screen ([desktop, root part 2](../5-desktop/2-look-and-feel.md)), because the theme uses
the copy of the font it installs. With the XS1000 connected.

## Install

```bash
sudo bash "$B/legion/grub-root.sh"       # Windows entry, removes the ISO's kernel, silent boot, theme; log ~/grub-root.log
sudo sh "$B/legion/grub-hidden.sh"       # hidden GRUB (0 s)
sudo xbps-pkgdb -m hold linux linux-headers   # the kernel does not jump off the 6.18 series
udisksctl unmount -b /dev/sda4           # the XS1000's NTFS partition, before rebooting
sudo reboot
```

What `grub-root.sh` does, in order:

1. Mounts the XS1000's EFI (`sda1`, `SYSTEM`, UUID `@XS1000_EFI_UUID@`) **read-only** and checks that
   `\EFI\Microsoft\Boot\bootmgfw.efi` is there; if not, no Windows entry.
2. Writes the entry in `/boot/grub/custom.cfg` (loaded by `41_custom`, so it survives `grub-mkconfig`; leaves
   `custom.cfg.bak` if there was one):

   ```
   menuentry "Windows (disco externo Kingston XS1000)" {
       insmod part_gpt
       insmod fat
       insmod chain
       search --no-floppy --fs-uuid --set=root @XS1000_EFI_UUID@
       chainloader /EFI/Microsoft/Boot/bootmgfw.efi
   }
   ```

   The Legion's firmware sees the XS1000 (directly on the USB-C and through the dock), so a plain `chainloader`
   is enough.
3. Removes the live ISO's kernel (`vkpurge rm 6.12.11_1`). The `linux6.12` series stays as the **fallback
   kernel**: it shows as orphan and `void-update` keeps it on purpose.
4. **Silent boot** with `common/boot/silent-boot.sh`. Kernel line: `quiet loglevel=3 rd.udev.log_level=3
   udev.log_level=3 vt.global_cursor_default=0`; `/etc/modules-load.d/dm-raid.conf` (left by the installer) is
   disabled.
5. **"void-xterm" theme** (`common/grub-theme/install-theme.sh`; installs `python3-Pillow` and `fonttools`): it
   reads the panel's resolution (`/sys/class/drm/card*-eDP-*/modes`) into `GRUB_GFXMODE` (`1920x1200,auto`) and
   `build.py` scales everything by height/768, with the machine name under the logo. The hooks of
   `/etc/kernel.d/` redraw it when the kernels change. Preview without installing:
   `THEME_SCREEN=1920x1200 THEME_HOST=name python3 build.py folder "Entry 1" … --preview preview.png`.

`grub-hidden.sh` sets in `/etc/default/grub` (leaves `.bak`): `GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden`
(boots the first entry, always the newest kernel); `GRUB_TERMINAL_OUTPUT=console` and
`GRUB_GFXPAYLOAD_LINUX=keep` (GRUB does not change the video mode, so the firmware logo does not blink); and
removes `amdgpu.seamless=1` if it is there.

## Check

- `/boot/grub/grub.cfg` has `set timeout_style=hidden` and `set timeout=0`; at power-on, from the firmware logo
  straight to the system.
- `xbps-query -H` lists `linux` and `linux-headers` (held).

## Rules

- **Nothing writes to the firmware**: `MODIFY_EFI_ENTRIES=0` in `/etc/default/efibootmgr-kernel-hook` (the default).
- **Before booting the XS1000's Windows, unmount its partition** in Linux; shut that Windows down with
  **Shift + Apagar** (Shift + Shut down), or Fast Startup leaves the NTFS hibernated and Linux does not mount it.
- **No Plymouth** (`common/boot/install-plymouth.sh` is not used): it was tried, and every screen handover
  (amdgpu, Plymouth, gamescope) blinked; without it the boot is cleaner and faster.

## Problems

- **The XS1000's Windows or the fallback kernel is needed:** with GRUB hidden there is no menu. Windows: the
  Legion's **firmware boot menu**. Fallback kernel: `sudo sh "$B/legion/grub-hidden.sh" --remove` (menu with the
  theme, 5 s; from a live if the system does not boot), and `grub-hidden.sh` again afterwards.
- **The XS1000 does not mount** (`wrong fs type…`, `volume is dirty`): it was left dirty. Read it with
  `udisksctl mount -b /dev/sda4 -o ro`; fix it unmounted with `sudo ntfsfix -d /dev/sda4`, and `chkdsk D: /f` in
  its Windows.

## Undo

`sudo rm /boot/grub/custom.cfg`, `sudo sh "$B/common/boot/silent-boot.sh" --remove`,
`sudo bash /usr/local/share/grub-theme/install-theme.sh --remove`, `sudo sh "$B/legion/grub-hidden.sh" --remove`.
If Plymouth is ever on a system: `sudo sh "$B/common/boot/install-plymouth.sh" --remove`,
`sudo xbps-remove plymouth plymouth-data`, `sudo rm -r /etc/plymouth` (the removal leaves `/etc/plymouth/plymouthd.conf`), remove `splash` and test parameters from
`GRUB_CMDLINE_LINUX_DEFAULT`, `sudo dracut --force --regenerate-all` (check: `sudo lsinitrd /boot/initramfs-<version>.img | grep plymouthd` gives nothing).
