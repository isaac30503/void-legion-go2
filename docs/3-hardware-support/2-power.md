# Power: TDP, GPU clock, power button, suspend and hibernation

## Fine TDP: `lenovo-wmi-*` via DKMS

`lenovo-wmi-gamezone` and `lenovo-wmi-other` (with `-helpers`, `-events` and `-capdata01`) are in Linux 6.18 but
**Void does not enable them** (`CONFIG_LENOVO_WMI_GAMEZONE`/`_TUNING`). They give the **`custom`** profile and the
power limits in `/sys/class/firmware-attributes/lenovo-wmi-other-0`, which Steam uses through
[steamos-manager](../6-game-mode/3-steamos-manager.md). No own kernel: a DKMS package with the sources of 6.18.55.

```bash
sudo bash "$B/legion/tdp/install-tdp.sh"               # --remove undoes it
```

- **Sources:** `drivers/platform/x86/lenovo/wmi-*.{c,h}` and `firmware_attributes_class.h` of stable **v6.18.55**
  (git.kernel.org), **unchanged**, in `legion/tdp/lenovo-wmi-tdp/` with a `Kbuild` and its `dkms.conf`
  (`BUILD_EXCLUSIVE_KERNEL="^6\.18\."`, `AUTOINSTALL`, destination `/updates`). GPL-2.0, credited in
  [THIRD_PARTY.md](../../THIRD_PARTY.md).
- `xbps-install dkms linux6.18-headers`, copy to `/usr/src/lenovo-wmi-tdp-6.18.55`, `dkms install`, `modprobe`.
  They load at boot by themselves (by the firmware's WMI GUIDs; the Go 2 is in the driver's DMI list).
- **Updates:** within 6.18 the hook `/etc/kernel.d/post-install/10-dkms` rebuilds them when a new kernel comes in
  (and `pre-remove/10-dkms` removes them with old kernels). **They are not built for 6.19** (on purpose): that is
  why the `linux` and `linux-headers` metapackages are held ([boot](../1-platform/3-boot.md)). 6.18 is LTS and
  Void keeps its LTS series. `void-update` rebuilds the module if it is missing for the newest 6.18, and warns if
  the hold is gone or **when Void recommends another series** (the moment to bring that series' sources, or
  check whether Void enables them, and `sudo xbps-pkgdb -m unhold linux linux-headers`).

**Check:** `dkms status` → `installed`; `cat /sys/class/platform-profile/*/{name,choices}` → `lenovo-wmi-gamezone`
with `low-power balanced performance custom` (the other one is `amd-pmf`). If the module does not build for a new 6.18 kernel, the error is in `/var/lib/dkms/lenovo-wmi-tdp/*/build/make.log`; in `…/lenovo-wmi-other-0/attributes/`:
`ppt_pl1_spl` 5–35 W, `ppt_pl2_sppt` 5–37 W, `ppt_pl3_fppt` 5–45 W. The limits apply only with the profile
`custom`; `/sys/firmware/acpi/platform_profile` then says `custom` too (not an error).

## Manual GPU clock: overdrive

Without bit `0x4000` of `amdgpu.ppfeaturemask` (factory `0xfff7bfff`), writing a clock to `pp_od_clk_voltage`
gives `Invalid argument`, and Steam's "Reloj de GPU manual" ("Manual GPU Clock") does nothing.

```bash
sudo sh "$B/legion/gpu-overdrive.sh" && sudo reboot      # --remove undoes it
```

It writes `/etc/modprobe.d/amdgpu-overdrive.conf` (`options amdgpu ppfeaturemask=0xfff7ffff`; not in GRUB, whose
line `silent-boot.sh` rewrites) and rebuilds with `dracut` the initramfs of every installed kernel. The kernel
becomes *tainted* ("Overdrive is enabled" in `dmesg`): only a warning.

**Check:** `cat /sys/module/amdgpu/parameters/ppfeaturemask` → `0xfff7ffff`;
`cat /sys/class/drm/card*/device/power_dpm_force_performance_level` → `auto` (`manual` only while Steam's manual
clock is on; then `OD_SCLK` shows the chosen clock, e.g. 2900/2900).

**GPU power profile: not available** with this kernel (amdgpu has no `pp_power_profile_mode` for this GPU, SMU
14.0.0; neither does Valve's kernel): steamos-manager's installer removes that option, so Steam does not show it.

## Power button

Like the Steam Deck: **a short press suspends; held ~3 s, the power menu opens**, in Game Mode (Steam's menu) and
on the desktop (Xfce's logout dialog).

```bash
sudo sh "$B/common/power-button/install-power-button.sh"   # --remove undoes it
```

Then log out and back in (or reboot) so that each session starts it. Game Mode starts it from its launcher (the
launcher looks for it every time).

- **How the Legion Go 2 reports the button** (captured with every input device open): a press released before
  ~3 s gives, **on release**, `KEY_POWER` pressed+released at once on the ACPI `Power Button`; held ~3 s, the
  embedded controller types **Super+F16** on the internal keyboard (`AT Translated Set 2 keyboard`, scancodes
  `0xdb`/`0x67`; Void's hwdb already maps `0x67` to F16, like Valve's), **while still held**, and no `KEY_POWER`.
  The firmware decides the ~3 s; the Deck's 1 s is not possible.
- **`/usr/local/bin/power-button --mode game|desktop`** (Python, standard library; ~10 MB, 0 % CPU at rest).
  Event-driven: it sleeps in `poll()` on the marked devices, a pidfd of its session's process (it ends with it)
  and a `timerfd` with `TFD_TIMER_CANCEL_ON_SET`, which the kernel cancels on every resume: presses in the 2 s
  after waking up are ignored. Game Mode: press → `steam://shortpowerpress` (Steam suspends), held →
  `steam://longpowerpress` (Steam's power menu), as SteamOS's `steamos-powerbuttond`; without Steam, a press
  suspends. Desktop: press → `loginctl suspend`, held → `xfce4-session-logout`. One per user (the newest
  session's). Log: `~/.local/state/power-button.log`.
- **`/etc/udev/rules.d/70-power-button.rules`:** `POWER_BUTTON=1` and `uaccess` for the ACPI `Power Button` and,
  on 83N0/83N1 only, the internal keyboard (it carries no other keys).
- **`/etc/elogind/logind.conf.d/50-power-button.conf`:** `HandlePowerKey=ignore`, `HandlePowerKeyLongPress=ignore`.
  **Without it, elogind's default powers the Legion off at the first press** (on the desktop xfce4-power-manager
  blocks it; in Game Mode nothing does).
- **`/etc/xdg/autostart/power-button.desktop`:** the desktop's (X11 and Wayland).
- xfce4-power-manager's own `power-button-action` = 0 (nothing), in the Xfce configuration
  (`legion/xfce/`), so the X11 session does not act twice.

**Check:**

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey   # s "ignore"
pgrep -af power-button                     # one, with --mode game or --mode desktop
tail ~/.local/state/power-button.log       # "press: suspend", "held: menu", "resumed …"
```

**Let go as soon as the menu shows:** held much longer (several seconds more), the firmware powers off at once.

## Suspend, hibernation and brightness on wake

Suspend is `s2idle` (the only one this firmware offers; it drains some battery: ≈ 2 %/h, ≈ 1.5 W, measured
unplugged). **Hibernation works with nothing else to configure:** 32 GB swap (`nvme0n1p2`) and
`/sys/power/resume` = `259:2`, set by dracut's initramfs (`resume=UUID=@LEGION_SWAP_UUID@`); `/sys/power/disk` =
`platform`, lockdown `none`. From the session: `loginctl hibernate` (over SSH `loginctl` answers `challenge`:
it is not the active session). It restored the session, the Wi-Fi without power saving, InputPlumber (it adds
the controller back by itself) and Steam.

**Check that it restored and did not boot anew:** `uptime -s` shows the same time as before.

**Brightness on wake:** after hibernating, the built-in screen came back with another brightness (100 % → ~32 %).

```bash
sudo sh "$B/legion/brightness-on-wake.sh"      # --remove undoes it
```

elogind hook `/etc/elogind/system-sleep/brightness` (the folder elogind reads on Void, next to
`/usr/libexec/elogind/system-sleep/`): saves each screen's brightness before sleeping (`pre`, in
`/run/brightness-before-sleep`, which travels in the hibernation image) and sets it again after (`post`), for
hibernate and suspend. Log: `/run/brightness-on-wake.log` (e.g. `hibernate: brillo repuesto (amdgpu_bl0 472000)`).

**Before hibernating, unmount any NTFS** (the XS1000): hibernating with it mounted risks the volume.
