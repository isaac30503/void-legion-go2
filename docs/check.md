# Check the whole system

After a reinstall (or to audit it), layer by layer. Each line shows the expected value; the page of each piece explains
it. Without root unless it says `sudo`. Then `void-update`: its summary must end with "✓ Todo en orden" / "All in
order".

```bash
# 1. platform and boot
uname -r                                   # 6.18.x
xbps-query -H                              # linux-6.18_1 and linux-headers-6.18_1 (held)
for d in /mnt/home /mnt/steamos-home; do test -e $d && echo "!! $d sigue"; done   # nothing (the live's folders, removed)

# 2. base system
sudo sv status sshd avahi-daemon bluetoothd   # all three in "run"
setxkbmap -query                           # us / intl (in the session)
sysctl kernel.split_lock_mitigate net.core.default_qdisc   # 0 / fq_codel
cat /sys/kernel/mm/transparent_hugepage/enabled   # [always]
grep -o preempt=full /proc/cmdline; ulimit -l   # preempt=full · 8192
ps -eLo cls,rtprio,comm | grep data-loop   # RR 20 (real-time audio)
test -e /var/service/rtkit && echo "!! /var/service/rtkit existe"; pgrep -x rtkit-daemon | xargs -r -I{} ps -o ppid= -p {} | xargs -r ps -o args= -p   # only "runit" (D-Bus started it), never "runsv rtkit"
iw dev wlp193s0 get power_save             # Power save: off
ssh ideapad hostname                       # ideapad-100
cat /var/log/udev-net/current              # empty, or "… not processed by udev: repeating the announcement" if it had to act
findmnt /mnt/microsd                       # /dev/mmcblk0p1 ext4 rw,noatime

# 3. hardware
sudo sv status inputplumber steamos-manager udev-net   # all three in "run"
ls /sys/bus/hid/devices/ | grep 28DE       # 0003:28DE:12FB… (InputPlumber's Valve controller)
grep -c 'Failed to hide' /var/log/inputplumber/current   # does not grow when the service restarts
inputplumber device 0 capabilities | tr ',' '\n' | grep -iE 'gyro|accel'   # Gamepad:Gyro and Gamepad:Accelerometer
sh "$B/legion/diag-gyro.sh"                # turning the console: rotation from hundreds to ~1500
dkms status                                # lenovo-wmi-tdp/6.18.55 …: installed
ls /sys/class/firmware-attributes/lenovo-wmi-other-0/attributes   # ppt_pl1_spl ppt_pl2_sppt ppt_pl3_fppt
cat /sys/module/amdgpu/parameters/ppfeaturemask   # 0xfff7ffff (overdrive)
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey   # s "ignore"
pgrep -af power-button                     # one, with --mode game or --mode desktop
ls -l /etc/elogind/system-sleep/brightness     # after sleeping: cat /run/brightness-on-wake.log
rfkill                                     # bluetooth unblocked
bluetoothctl show | grep Alias             # Alias: Legion-Go-Gen-2
ls ~/.config/wireplumber/wireplumber.conf.d/; wpctl settings | grep -A5 'Id: node.restore-default-targets' | grep Value   # 51-audio-priority.conf · Value: false

# 4. sessions
ls -l /usr/local/bin/xfce4-session /etc/runit/shutdown.d/05-close-steam.sh   # clean Steam shutdown
grep -c -e 'sv once' -e 'steam -shutdown' /usr/local/bin/switch-mode-root   # 4
ls -l /var/service/mode-switch; ls /etc/sv/mode-switch   # → /etc/sv/mode-switch · down run
cat /run/switch-mode.log                   # after a switch: how long it waited for elogind
ls /run/user/1000 | grep -c wayland-0       # 2 in Xfce Wayland

# 5. desktop
xrandr --listactivemonitors                # eDP-1 / DP-1 (Wayland, through Xwayland); eDP / DisplayPort-0 on X11
pgrep -af new-windows                      # only in the X11 session
grep -c 'type="utility"' ~/.config/xfce4/labwc/rc.xml   # 1 (Steam's keyboard)
grep -c 'identifier="screen-share"' ~/.config/xfce4/labwc/rc.xml   # 1 (the chooser on top)
grep -c xwaylandPersistence ~/.config/xfce4/labwc/rc.xml   # 1
grep -c '<raiseOnFocus>no' ~/.config/xfce4/labwc/rc.xml; xfconf-query -c xfwm4 -p /general/raise_on_focus   # 1 and false
cat ~/.local/state/wallpaper-watcher.log   # "vigilando 2 pantallas" and, after a change, "xfdesktop --reload"
xbps-query -p pkgver xfdesktop             # xfdesktop-4.20.2_2 (or Void's, if void-update says it already has the fix)
xbps-query -p pkgver Thunar                # Thunar-4.20.10_2

# 6. game mode
grep -E "mode:|cursor:" ~/.local/state/steam-game-mode.log | tail -2   # direct screen (DRM) / volantes_cursors
grep -a 'mode: direct screen' ~/.local/state/steam-game-mode.log | tail -1   # …; refresh rates 48,144
grep -c ENABLE_GAMESCOPE_WSI /usr/local/bin/steam-game-mode   # 1
getcap /usr/bin/gamescope                  # cap_sys_nice=eip
DISPLAY=:0 xprop -root GAMESCOPE_VRR_ENABLED   # = 1 in Game Mode with "Habilitar VRR"
grep -c '^\[gpu_performance\]' /usr/share/steamos-manager/devices/legion-go-series.toml; cat /sys/class/drm/card*/device/power_dpm_force_performance_level   # 1 · auto
sha256sum /usr/lib/steamos-manager         # cc464424414289025056eaa2ee38976aa36b6d3dc662340ebd427e4600d1586c (patched)
sha256sum -c /usr/local/share/steamos-manager-void/sha256   # both OK
cat /usr/local/share/steamos-manager-void/package           # steamos-manager-v26.4.1-void-2
xbps-query -m | grep -c '^speech-dispatcher-[0-9]'   # 1
xbps-query -m | grep -cE '^(glib-devel|eudev-libudev-devel|speech-dispatcher-devel|clang|pkg-config)-[0-9]'   # 5 (kept on purpose)
sudo sv status decky                       # run
xbps-query -p pkgver hidapi                # hidapi-… (Decky's Colores)
readlink /usr/bin/systemctl; systemctl is-system-running   # /usr/local/lib/systemd-compat/systemctl · offline (systemd-compat)
sudo systemctl is-active inputplumber.service plugin_loader.service   # active · active
head -1 /etc/sv/decky/log/run; sudo tail -1 /var/log/decky/current   # svlogd · a line of Decky
for p in pipewire-32bit libspa-videoconvert-32bit mesa-vaapi-32bit mesa-vaapi; do xbps-query -p pkgver $p; done   # the four (Remote Play)
grep "Capture method set" ~/.local/share/Steam/logs/streaming_log.txt | grep -v Placeholder | tail -1   # after a stream: Desktop PipeWire NV12 DMABUF + VAAPI H264
ls ~/.config/autostart/steam-background.desktop && pgrep -af 'steam.*-silent'   # Steam in the background
grep '^N:' /proc/bus/input/devices | grep extest   # extest fake device (with Steam on the desktop)
grep -E "Shutdown|Verifying" ~/.local/share/Steam/logs/bootstrap_log.txt | tail -3   # "file sizes only"

# 7. apps
grep chooser_cmd ~/.config/xdg-desktop-portal-wlr/config; command -v grim fuzzel   # the screen-share chooser
grep -c XDPW_PERSIST_MODE ~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service   # 2
grep '^RULES' ~/.local/bin/screen-share    # {"steam": "screen"}
xbps-query -p pkgver,repository xdg-desktop-portal-wlr   # 0.8.4_2 … hostdir/binpkgs
xbps-query -p pkgver,repository gamescope   # 3.16.30_2 … hostdir/binpkgs
ls /usr/local/lib/xdg-desktop-portal-gamescope*   # the portal and its wrapper
grep Exec /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.gamescope.service   # …-gamescope-void

# 8. maintenance
ls ~/.local/bin/patch-still-needed ~/.local/share/void-update/patches   # Thunar gamescope steamos-manager xdg-desktop-portal-wlr xfdesktop
void-update --version; ls ~/.config/autostart/void-update-tray.desktop; pgrep -af void-update-tray   # the icon running
void-update --list | tail -3               # pending updates, or "System is up to date"
claude --version
```
