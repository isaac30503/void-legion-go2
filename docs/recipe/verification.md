## Verification

```bash
uname -r                                   # 6.18.x
sudo sv status sshd avahi-daemon bluetoothd   # all three in "run"
rfkill                                     # bluetooth unblocked
setxkbmap -query                           # us / intl (in the X11 session; on Wayland Xwayland says it: ~/.config/xfce4/labwc/environment rules)
xrandr --listactivemonitors                # X11: eDP and, with the monitor, DisplayPort-0; Wayland (through Xwayland): eDP-1 / DP-1
pgrep -af new-windows                  # the watcher, only in the X11 session (on Wayland it exits right away: labwc does it)
ssh ideapad hostname                       # ideapad-100
iw dev wlp193s0 get power_save             # Power save: off
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey   # s "ignore" (power-button)
pgrep -af power-button                     # one, with --mode game or --mode desktop; log ~/.local/state/power-button.log
sudo sv status decky                       # run (Decky Loader)
xbps-query -p pkgver hidapi                # hidapi-0.14.0_1 (Decky's Colores plugin, step 14)
cat ~/.local/state/wallpaper-watcher.log     # in Xfce Wayland: "watching 2 screens" and, after a change, "xfdesktop --reload"
xbps-query -p pkgver xfdesktop             # xfdesktop-4.20.2_2 (patched, step 15: wallpaper on Wayland) or Void's if void-update says it already has it
ls ~/.local/bin/patch-still-needed ~/.local/share/void-update/patches   # patch test: Thunar gamescope steamos-manager xdg-desktop-portal-wlr xfdesktop
void-update --version; ls ~/.config/autostart/void-update-tray.desktop; pgrep -af void-update-tray   # void-update 1.0.0 · the icon running
void-update --list | tail -3                 # the pending updates (rootless), or "System is up to date" ("El sistema está al día")
xbps-query -p pkgver Thunar                # Thunar-4.20.10_2 (patched, step 15: wallpaper from Thunar on Wayland)
grep -E "mode:|cursor:" ~/.local/state/steam-game-mode.log | tail -2   # direct screen (DRM) / volantes_cursors
sudo sv status inputplumber steamos-manager udev-net   # all three in "run"
ls /sys/bus/hid/devices/ | grep 28DE       # 0003:28DE:12FB… (InputPlumber's Valve controller)
grep -c 'Failed to hide' /var/log/inputplumber/current   # does not grow when restarting the service (18, all from 2026-10-04, before the fix)
dkms status                                # lenovo-wmi-tdp/6.18.55 …: installed
ls /sys/class/firmware-attributes/lenovo-wmi-other-0/attributes   # ppt_pl1_spl ppt_pl2_sppt ppt_pl3_fppt
cat /sys/module/amdgpu/parameters/ppfeaturemask   # 0xfff7ffff (overdrive, step 14)
grep -c '^\[gpu_performance\]' /usr/share/steamos-manager/devices/legion-go-series.toml; cat /sys/class/drm/card*/device/power_dpm_force_performance_level   # 1 · auto (manual only with the manual clock enabled in Steam)
sha256sum /usr/lib/steamos-manager         # cc464424414289025056eaa2ee38976aa36b6d3dc662340ebd427e4600d1586c (with the set_clocks patch)
sha256sum -c /usr/local/share/steamos-manager-void/sha256   # /usr/lib/steamos-manager: OK · /usr/bin/steamosctl: OK (the installer's reference)
cat /usr/local/share/steamos-manager-void/paquete           # steamos-manager-v26.4.1-void-2 (written by the installer; void-update --summary shows it)
xbps-query -m | grep -c '^speech-dispatcher-[0-9]'   # 1 (marked manual: steamos-manager's libspeechd; without the [0-9] it would also count speech-dispatcher-devel)
xbps-query -m | grep -cE '^(glib-devel|eudev-libudev-devel|speech-dispatcher-devel|clang|pkg-config)-[0-9]'   # 5 (steamos-manager's build dependencies, kept on purpose)
bluetoothctl show | grep Alias             # Alias: Legion-Go-Gen-2 (step 5–12)
for d in /mnt/home /mnt/steamos-home; do test -e $d && echo "!! $d sigue"; done   # nothing (the live's folders, deleted; step 0) ("sigue" = "still there")
cat /var/log/udev-net/current              # empty or "… not processed by udev: repeating the announcement" if it had to act
ls -l /usr/local/bin/xfce4-session /etc/runit/shutdown.d/05-close-steam.sh   # clean shutdown of Steam
grep -c -e 'sv once' -e 'steam -shutdown' /usr/local/bin/switch-mode-root   # 4 (no race; closes Steam)
ls -l /var/service/mode-switch; ls /etc/sv/mode-switch   # → /etc/sv/mode-switch · down run
ls /run/user/1000 | grep -c wayland-0       # 2 in Xfce Wayland (if missing: race with elogind, step 14)
grep -c 'type="utility"' ~/.config/xfce4/labwc/rc.xml   # 1 (Steam's keyboard, step 15)
grep -c 'identifier="screen-share"' ~/.config/xfce4/labwc/rc.xml   # 1 (chooser always on top, step 15)
grep -c xwaylandPersistence ~/.config/xfce4/labwc/rc.xml   # 1 (Xwayland always alive, step 15)
grep -c '<raiseOnFocus>no' ~/.config/xfce4/labwc/rc.xml; xfconf-query -c xfwm4 -p /general/raise_on_focus   # 1 and false (raise on click, step 15)
grep chooser_cmd ~/.config/xdg-desktop-portal-wlr/config; command -v grim fuzzel   # screen-share chooser (step 14, Portals)
grep -c XDPW_PERSIST_MODE ~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service   # 2: comment + Exec (no second question)
grep '^RULES' ~/.local/bin/screen-share   # {"steam": "screen"}
xbps-query -p pkgver,repository xdg-desktop-portal-wlr   # 0.8.4_2 … hostdir/binpkgs (window patch; step 14)
xbps-query -p pkgver,repository gamescope   # 3.16.30_2 … hostdir/binpkgs (with the patch; step 14)
ls /usr/local/lib/xdg-desktop-portal-gamescope*   # gamescope's portal and its wrapper (step 14)
grep Exec /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.gamescope.service   # …-gamescope-void (the wrapper)
getcap /usr/bin/gamescope                  # cap_sys_nice=eip
for p in pipewire-32bit libspa-videoconvert-32bit mesa-vaapi-32bit mesa-vaapi; do xbps-query -p pkgver $p; done   # the four versions: Remote Play in Game Mode (step 14)
grep "Capture method set" ~/.local/share/Steam/logs/streaming_log.txt | grep -v Placeholder | tail -1   # after a stream: Desktop PipeWire NV12 DMABUF + VAAPI H264 (Placeholder = Steam's menu or end)
ls ~/.config/wireplumber/wireplumber.conf.d/; wpctl settings | grep -A5 'Id: node.restore-default-targets' | grep Value   # 51-audio-priority.conf · Value: false [Saved: false] (point K.12)
ls ~/.config/autostart/steam-background.desktop && pgrep -af 'steam.*-silent'   # Steam in the background
grep -E "Shutdown|Verifying" ~/.local/share/Steam/logs/bootstrap_log.txt | tail -3   # "file sizes only"
grep '^N:' /proc/bus/input/devices | grep extest   # extest fake device (with Steam on the desktop)
inputplumber device 0 capabilities | tr ',' '\n' | grep -iE 'gyro|accel'   # Gamepad:Gyro and Gamepad:Accelerometer
sh "$B/legion/diag-gyro.sh"   # turning the console: rotation from hundreds to ~1500 (to Steam)
cat /run/switch-mode.log                  # after a mode switch: how long it waited for elogind
ls -l /etc/elogind/system-sleep/brightness     # brightness hook; after sleeping: cat /run/brightness-on-wake.log
xbps-query -H                              # linux-6.18_1 and linux-headers-6.18_1 (held)
findmnt /mnt/microsd                       # /dev/mmcblk0p1 ext4 rw,noatime (microSD, mounted at boot)
sysctl kernel.split_lock_mitigate net.core.default_qdisc   # 0 / fq_codel (SteamOS settings)
cat /sys/kernel/mm/transparent_hugepage/enabled   # [always]
ps -eLo cls,rtprio,comm | grep data-loop   # RR 20 (real-time audio, rtkit)
test -e /var/service/rtkit && echo "!! /var/service/rtkit existe"; pgrep -x rtkit-daemon | xargs -r -I{} ps -o ppid= -p {} | xargs -r ps -o args= -p   # only "runit" (D-Bus started it), never "runsv rtkit" ("existe" = "exists")
grep -o preempt=full /proc/cmdline; ulimit -l   # preempt=full · 8192
grep -c ENABLE_GAMESCOPE_WSI /usr/local/bin/steam-game-mode   # 1
grep -a 'mode: direct screen' ~/.local/state/steam-game-mode.log | tail -1   # …; refresh rates 48,144
DISPLAY=:0 xprop -root GAMESCOPE_VRR_ENABLED   # = 1 in Game Mode with "Habilitar VRR" ("Enable VRR") (exact FPS limit)
```

> **In this repository:** `install/verify.sh` runs the commands of this block that need no root and
> prints each one with its expected value next to it; the `sudo` ones are listed for the user to run.

And an `void-update`: its final summary must say "✓ Todo en orden" ("✓ All in order").

Verified on 2026-10-03: kernel 6.18.55, avahi announcing `Legion-Go-Gen-2.local`, `ssh lego` and
`ssh ideapad` by name, keyboard `us`/`intl`, session with Orchis, Papirus-Dark teal, Volantes,
JetBrainsMono NFM Blocks, fastfetch with the Legion's real data (screenshot reviewed) and the
per-monitor window shortcuts. **On 2026-10-04**, after rebooting: Wi-Fi as `wlp193s0` with
`Power save: off`, InputPlumber without warnings when hiding and a single controller in Steam, overdrive active and
the two `steamos-manager` processes.

### Verified (what was in *Pending*)

- **Game Mode: Windows game verified** (2026-10-04): **Borderlands 3** (appid 397540) with
  **Proton 9.0-2RC** (Steam chose it: `compat_log.txt` → `Mapping AppID 397540 to tool
  "proton-9.0-2RC"`) and **without launch options** (without the `PROTON_USE_WINED3D=1` that
  the IdeaPad needs: here the GPU works for DXVK), with the body's gyroscope working.
  **Xfce Wayland:** both screens, fine since 2026-10-04 (`wallpaper-watcher`); the
  "Modo Juego" (Game Mode) launcher from the desktop, verified by the user on 2026-10-04.
- **InputPlumber** (step 14): the buttons work in Game Mode (2026-10-04); the gyroscope
  in a game was missing (the sensor's raw values do not match its declared scale: check that
  the rotation goes at the right speed) → **body's gyroscope solved on the desktop on
  2026-10-04** (unblocking + ×100 scale, see step 14); correct axes and **it works in
  games** (Borderlands 3, 2026-10-04) (`diag-gyro.sh` to see what Steam receives). **Detached controllers: they work** (verified by the user on
  2026-10-04; the Legion still sees them as `17ef:61eb` "Legion Controller" and InputPlumber the same).
- **Suspend** (`s2idle`) **verified on 2026-10-04** from Game Mode (power button
  to wake): `/sys/power/suspend_stats` → `success=1`, `fail=0`, `last_hw_sleep` ≈ 6 s
  (real hardware sleep); on wake, Wi-Fi connected with `Power save: off`, whole controller and
  InputPlumber fine. **Long suspend** on 2026-10-04: several hours, **plugged in and charging**,
  without incidents according to the user (the statistics of `/sys/power/suspend_stats` are lost on
  reboot: no record was left).
- **Hibernation: verified on 2026-10-04** (see "Hibernation", step 14). Nothing pending.
- **Battery drain in suspend, unplugged: measured on 2026-10-05.** Suspended from Game
  Mode at 22:14 with 54 %, woken at 22:44 with 53 % (`BAT0/capacity`), unplugged
  (`status: Discharging`). `/sys/power/suspend_stats`: `success` 1, `fail` 0, **`last_hw_sleep`
  1794764923 µs = 29.9 min of real hardware sleep** (`s2idle`; without half wakeups).
  **≈ 2 % per hour ≈ 1.5 W** with the 78.3 Wh battery (`energy_full` 78310000; factory 74 Wh):
  suspended it lasts about two days. `capacity` goes in integers (1 % = between almost 0 and almost 2 %): for an
  exact figure, compare `energy_now` (µWh) before and after.
- **953 GB microSD (ext4)**: from the SteamOS days (Steam library?). Not mounted or
  touched; decide what to do with it. → **Solved on 2026-10-05:** it was SteamOS's Steam library;
  always mounted at boot on `/mnt/microsd` (step 14, "microSD"), verified.
- **GPU always on auto** (step 14, steamos-manager): verified on 2026-10-08 after rebooting
  (00:48): level `auto`, factory `ppfeaturemask` (`0xfff7bfff`), no new `manual GPU clock` in
  `/var/log/steamos-manager/current` after Game Mode (183, the last at 00:42, before the change),
  and TDP and Performance profiles working in Steam (checked by the user). **Undone the
  same day:** the manual clock and the overdrive were brought back (step 14, steamos-manager).

