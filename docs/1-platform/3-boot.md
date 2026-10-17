# Boot

From the firmware logo straight to the session: **hidden GRUB** (0 s) booting the newest kernel, a **silent
boot** and a **loading animation** (Plymouth) until the session, the same family of animations as Game Mode's
loading screen. GRUB also carries an entry for the **Windows on the external Kingston XS1000** and the
themed menu "void-xterm", both unseen while GRUB is hidden. The kernel is **held in the 6.18 series** (the fine
TDP modules are built for it).

**When:** after the login screen ([desktop, root part 2](../5-desktop/2-look-and-feel.md)), because the theme uses
the copy of the font it installs. With the XS1000 connected.

## Install

```bash
sudo bash "$B/legion/grub-root.sh"       # Windows entry, removes the ISO's kernel, silent boot, theme; log ~/grub-root.log
sudo sh "$B/legion/grub-hidden.sh"       # hidden GRUB (0 s)
sudo xbps-pkgdb -m hold linux linux-headers   # the kernel does not jump off the 6.18 series
sudo sh "$B/common/boot/install-plymouth.sh"   # the animations (below): Void B, and Steam B while Steam loads
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

### The loading animations

![The six animations: Steam A, B, C (top) and Void A, B, C (bottom)](../../common/boot/plymouth-void/preview.png)

`install-plymouth.sh` draws them with `plymouth-void/generate.py` at the panel's height (`/sys/class/drm/card*-eDP-*/modes`),
all from vectors, so they are sharp on any screen:

| Option | Animation | Firmware logo | Frames |
|---|---|---|---|
| `--steam-a` | Steam's mechanism moving inside a blue circle, below the logo | yes | 124 (a cycle ~4.1 s) |
| `--steam-b` | that circle, large (28 % of the height) and centred | no | 124 |
| `--steam-c` | the whole mechanism in a blue rectangle with STEAM at the bottom left | no | 124 |
| `--void-a` | Void's symbol spinning below the logo | yes | 54 (a turn ~1.8 s) |
| `--void-b` (default) | that symbol, large and centred | no | 54 |
| `--void-c` | Void's logo with its letters, the arcs spinning behind them | no | 54 |

`--loading-steam-a` … `--loading-void-c` chooses **Game Mode's loading screen** (`steam-loading`,
[Game Mode](../6-game-mode/2-game-mode.md)), one of the six (its frames in `/usr/local/share/steam-loading/`);
`--loading-same` shows the same one as the boot. **Without options it is "B with B"**, `--void-b --loading-steam-b`,
what both machines use. Running it again with other options changes them. It installs `plymouth` and `plymouth-data` (and `librsvg-utils`, `python3-Pillow`,
`void-artwork` if missing) and:

1. Generates the theme in `/usr/share/plymouth/themes/` (`bgrt-steam`, `steam-grande`, `steam-mecanismo`, `bgrt-void`,
   `void-simbolo` or `void-logo`) and sets it, with `DeviceScale=1` **after** `Theme=` in `plymouthd.conf` (the frames
   are already at their size; dracut only reads the first key of `[Daemon]`).
2. Adds `splash` to the kernel line; `silent-boot.sh` then puts **`loglevel=2`**: with 3 the kernel's `pr_crit`
   messages (amdgpu's `Overdrive is enabled…`, from [steamos-manager](../6-game-mode/4-steamos-parity.md)'s
   `ppfeaturemask`) took the screen at 2 s, before Plymouth, and left text before and after the animation.
3. Removes `agetty-tty1` (its `vhangup()` would take console 1 from Plymouth); consoles 2–6 keep their login.
4. Writes `/etc/runit/shutdown.d/07-plymouth.sh` (after `05-close-steam.sh`): at shutdown and reboot it stops lightdm
   and clears the console, so the screen goes black **without runit's "leave stage" lines**. The animation at shutdown
   is opt-in (`--shutdown-animation`): **on the Legion it freezes** after a few frames (Plymouth 22.02 draws into the
   scanout buffer, amdgpu refuses its `DirtyFB` and the panel's power saving, PSR/Replay, already on after the session,
   repeats the last image); drawing through `/dev/fb0` instead left the screen black.
5. Rebuilds the initramfs of every kernel and the GRUB menu.

`--debug` adds Plymouth's trace to the kernel line, to `/run/plymouth-trace.log` (with `stream:`; with `file:` alone,
Plymouth 22.02 also writes the trace **on the screen**). Preview of one animation without installing:
`python3 plymouth-void/generate.py folder void-b 1200 --preview 1920 1200 out.png`.

`grub-hidden.sh` sets in `/etc/default/grub` (leaves `.bak`): `GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden`
(boots the first entry, always the newest kernel); `GRUB_TERMINAL_OUTPUT=console` and
`GRUB_GFXPAYLOAD_LINUX=keep` (GRUB does not change the video mode, so the firmware logo does not blink); and
removes `amdgpu.seamless=1` if it is there.

## Check

- `/boot/grub/grub.cfg` has `set timeout_style=hidden` and `set timeout=0`; at power-on, from the firmware logo
  straight to the system.
- `xbps-query -H` lists `linux` and `linux-headers` (held).
- `plymouth-set-default-theme` gives the chosen theme; `grep CMDLINE_LINUX_DEFAULT /etc/default/grub` ends in
  `vt.global_cursor_default=0 splash`, with `loglevel=2`; `sudo lsinitrd /boot/initramfs-<version>.img | grep plymouthd`
  finds it; `/etc/runit/shutdown.d/07-plymouth.sh` exists. At power-on: firmware logo, the animation, the session,
  with no text; at shutdown, black with no text.

## Rules

- **Nothing writes to the firmware**: `MODIFY_EFI_ENTRIES=0` in `/etc/default/efibootmgr-kernel-hook` (the default).
- **Before booting the XS1000's Windows, unmount its partition** in Linux; shut that Windows down with
  **Shift + Apagar** (Shift + Shut down), or Fast Startup leaves the NTFS hibernated and Linux does not mount it.
- **Never close Plymouth before lightdm** (e.g. in `/etc/sv/lightdm/conf`): on 2026-10-02 it left the machine stuck on
  the logo. lightdm closes it by itself.
- Every screen handover (firmware, Plymouth, gamescope) can blink: a short black between the animation and Steam is
  expected (gamescope sets the panel to 144 Hz); it was the reason for going without Plymouth from 2026-10-04 to
  2026-10-16.

## Problems

- **Stuck on the logo at power-on:** over SSH, `sudo plymouth quit; sudo sv restart lightdm`; then find the cause
  (`--debug`) or remove it (Undo).
- **Text before or after the animation:** the kernel line lost `loglevel=2` or kept `plymouth.debug=file:` alone
  (run `install-plymouth.sh` again), or a new `pr_crit` message (`sudo dmesg --level=emerg,alert,crit`).
- **On an external 4K screen the animation looks small:** the frames are made for the panel's height and Plymouth
  draws them pixel for pixel (sharp, smaller); Game Mode's loading screen too.

- **The XS1000's Windows or the fallback kernel is needed:** with GRUB hidden there is no menu. Windows: the
  Legion's **firmware boot menu**. Fallback kernel: `sudo sh "$B/legion/grub-hidden.sh" --remove` (menu with the
  theme, 5 s; from a live if the system does not boot), and `grub-hidden.sh` again afterwards.
- **The XS1000 does not mount** (`wrong fs type…`, `volume is dirty`): it was left dirty. Read it with
  `udisksctl mount -b /dev/sda4 -o ro`; fix it unmounted with `sudo ntfsfix -d /dev/sda4`, and `chkdsk D: /f` in
  its Windows.

## Undo

`sudo rm /boot/grub/custom.cfg`, `sudo sh "$B/common/boot/silent-boot.sh" --remove`,
`sudo bash /usr/local/share/grub-theme/install-theme.sh --remove`, `sudo sh "$B/legion/grub-hidden.sh" --remove`.
Plymouth: `sudo sh "$B/common/boot/install-plymouth.sh" --remove` (themes, hook, loading screen, `splash`, console 1;
then the initramfs and the menu are rebuilt); to remove the package too, `sudo xbps-remove plymouth plymouth-data`,
`sudo rm -r /etc/plymouth` (the removal leaves `/etc/plymouth/plymouthd.conf`) and `sudo dracut --force --regenerate-all`
(check: `sudo lsinitrd /boot/initramfs-<version>.img | grep plymouthd` gives nothing).
