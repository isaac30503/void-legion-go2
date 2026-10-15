# System

Void up to date, the US international keyboard, SSH and mDNS, and the system settings SteamOS has (kernel
preemption, sysctl, huge pages, real-time audio, earlyoom, gamemode).

## Install

```bash
sudo bash "$B/legion/steps-1-to-3.sh"       # log ~/steps-1-to-3.log; ends with "DONE OK"
sudo reboot
```

**After [Steam](../6-game-mode/1-steam.md)** (it needs its `multilib` repository for `gamescope-32bit`):

```bash
sudo bash "$B/legion/like-steamos.sh"       # with bash; log ~/like-steamos.log (closes Steam cleanly if it is open)
sudo reboot
```

**`steps-1-to-3.sh`:**

1. **xbps first, then everything** (`xbps-install -Syu xbps`; `xbps-install -Syu -y`). If a new OpenSSH comes in,
   SSH connections are cut ("Connection reset by peer") until the reboot: expected.
2. **Keyboard:** `/etc/X11/xorg.conf.d/00-keyboard.conf` with `XkbLayout "us"` and `XkbVariant "intl"` (copy in
   `legion/00-keyboard.conf`) and `KEYMAP=us-acentos` in `/etc/rc.conf` (leaves `rc.conf.bak`). With `intl`,
   `'` + `a` = á and **AltGr+n = ñ**.
3. `openssh avahi nss-mdns` and the services `dbus`, `sshd`, `avahi-daemon`. `xbps-install` prints
   `ERROR: Package 'openssh' already installed.` and goes on: not a failure.

**`like-steamos.sh`** (`--remove` undoes it; the packages stay):

1. `/etc/sysctl.d/30-like-steamos.conf`: `kernel.split_lock_mitigate = 0`, `fs.inotify.max_user_watches` /
   `_instances` 524288 / 1024, `net.core.default_qdisc = fq_codel` (Void loads it at boot,
   `/etc/runit/core-services/08-sysctl.sh`).
2. Transparent huge pages `always`: block `# >>> like-steamos` … `# <<< like-steamos` in `/etc/rc.local`.
3. Packages `rtkit earlyoom gamemode libgamemode-32bit gamescope-32bit`; `/etc/sv/earlyoom/conf` with
   `OPTS="-M 409600,307200 -S 409600,307200 -r 3600"` and `earlyoom` enabled. **`rtkit` is not a runit service:**
   D-Bus starts it on demand (`/usr/share/dbus-1/system-services/org.freedesktop.RealtimeKit1.service`); with both
   they clash (the runit one restarted every second). `gamemoded` is started by D-Bus in the session too.
4. Steam with `-pipewire` (`~/.local/share/applications/steam.desktop`,
   `~/.config/autostart/steam-background.desktop`).
5. `preempt=full` in `GRUB_CMDLINE_LINUX` of `/etc/default/grub` (not in `…_DEFAULT`, which `silent-boot.sh` and
   `grub-hidden.sh` rewrite) and `update-grub`.
6. `/etc/security/limits.d/91-like-steamos.conf`: `isaac - memlock 8192`.

## Check

```bash
uname -r                                   # 6.18.x
pgrep -a avahi-daemon                      # running [Legion-Go-Gen-2.local]
setxkbmap -query                           # us / intl (in the session)
grep -o 'preempt=full' /proc/cmdline
cat /sys/kernel/mm/transparent_hugepage/enabled   # [always]
ulimit -l                                  # 8192
```

PipeWire and WirePlumber run in real time (RR 20, nice −11, like the Deck): `ps -o rtprio,ni,comm -C pipewire,wireplumber`.
A single `rtkit-daemon`, child of D-Bus, not of `runsv`.

## Notes

- The `.new-*` files left in `/etc` (`libc-locales`, `issue`, `passwd`, `rc.conf`) are the packages' templates:
  **not applied** (`passwd.new-*` has no users). `void-update` warns about them.
- **Not done on purpose:** zram or zswap (21 GB of RAM: hardly used), the Deck's PipeWire block size
  (`clock.quantum` 512; touch it only if there are crackles), the Deck's kernel parameters (its chip's) and
  systemd-only pieces.
- After `runit` sees a new service link it takes up to 5 s: `sv status` right away answers
  `unable to open supervise/ok`.
