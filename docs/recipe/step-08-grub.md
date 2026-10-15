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

