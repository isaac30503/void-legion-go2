## 2–3. System up to date, keyboard and SSH (one script)

```bash
sudo bash "$B/legion/steps-1-to-3.sh"       # log: ~/steps-1-to-3.log
sudo reboot                       # when it ends with "DONE OK"
```

It does what steps 1–3 of the IdeaPad do, with these differences:

1. **xbps first and then everything** (`xbps-install -Syu xbps`; `xbps-install -Syu -y`). The mirror
   was already summithq (the installer sets it if it is chosen). 2026-10-03: from 6.12.11 to **6.18.55**.
   If it brings a new OpenSSH, **SSH connections are cut** ("Connection reset by peer") until
   the reboot: that is expected.
2. **US international keyboard**: `/etc/X11/xorg.conf.d/00-keyboard.conf` with `XkbLayout "us"` and
   `XkbVariant "intl"` (backed up in `legion/00-keyboard.conf`), and `KEYMAP=us-acentos` in
   `/etc/rc.conf` (leaves `rc.conf.bak`; the installer had set `KEYMAP=en`, which does not exist).
   With `intl`, `'` + `a` = á and **AltGr+n = ñ**.
3. `openssh avahi nss-mdns` and the services `dbus`, `sshd`, `avahi-daemon`. **`xbps-install`
   prints `ERROR: Package 'openssh' already installed.` and continues**: it is not a failure, it installs the
   rest. **Do not query `sv status` right after creating the link:** runit takes up to 5 s to
   see the service and answers `unable to open supervise/ok`; with `set -e` that cut the script
   (it happened the first time; the backed-up script no longer does it).

After the reboot, check: `uname -r` (6.18.x), `pgrep -a avahi-daemon` (`running
[Legion-Go-Gen-2.local]`), `setxkbmap -query` in the session (`us` / `intl`) and from the IdeaPad
`ssh lego hostname`. 4 `.new-*` remain in `/etc` (`libc-locales`, `issue`, `passwd`, `rc.conf`),
the same as on the IdeaPad: **they are not applied** (`passwd.new-*` has no users). Step 5
deletes them.

**Network name with the dock (2026-10-04): avahi only over Wi-Fi.** With the dock, the Legion
has two networks at once (Wi-Fi `wlp193s0`, 192.168.0.x, and the dock's `enp196s0f3u1u1`,
192.168.1.x); avahi heard its own announcement over the other one, thought the name was taken and **renamed itself to
`Legion-Go-Gen-3.local`** (adds 1 to the final number of the name): `ssh lego` stopped
resolving. `sudo sh "$B/legion/avahi-wifi-only.sh"` (in `legion/`; `--remove` undoes it) puts
`allow-interfaces=wlp193s0` in the `[server]` section of `/etc/avahi/avahi-daemon.conf` (leaves `.bak`)
and restarts avahi. The Wi-Fi is always there, with dock or without it (and the IdeaPad is on that network); the name
of the dock's interface depends on the adapter. **Trade-off:** with only cable and the Wi-Fi off
there is no `.local` name. Check: `pgrep -a avahi-daemon` → `running [Legion-Go-Gen-2.local]`;
from the IdeaPad, `getent hosts Legion-Go-Gen-2.local`. **Verified on 2026-10-04.**

**Wi-Fi without power saving (2026-10-04).** From the factory the MT7922 runs with `Power save: on`
(`iw dev wlp193s0 get power_save`): the radio went to sleep and **did not answer ARP or mDNS until the
Legion itself transmitted**, so SSH did not get in in either direction and `Legion-Go-Gen-2.local` did not
resolve (from the IdeaPad, the Legion's IP showed `INCOMPLETE` in `ip neigh` and port 22 did not
answer; a `ping` from the Legion fixed it instantly). `sudo sh "$B/legion/wifi-no-powersave.sh"` (in
`legion/`; `--remove` undoes it) writes `/etc/NetworkManager/conf.d/wifi-no-powersave.conf`
(`[connection]` `wifi.powersave = 2`, for all Wi-Fi connections) and turns it off right away with `iw … set
power_save off`, without reconnecting. Check: `iw dev wlp193s0 get power_save` → `Power save: off`
(also after rebooting); from the IdeaPad, `ping` to the Legion of a few ms. **Verified on
2026-10-04:** 25 pings of 2–14 ms (average 5.8; with power saving, 55–100 ms).
**The engine is still wpa_supplicant** (NetworkManager's factory one), not iwd as on the
IdeaPad: the switch to iwd there fixed wpa_supplicant's continuous scans with the
RTL8723BE, and here it does not happen (0 scans in 30 s with `iw event`, 5 GHz and strong signal). Switch to
iwd only if those symptoms appear.

**Network interfaces that udev skips at boot: `udev-net` (2026-10-04).** After a reboot the
Wi-Fi came out as **`wlan0`** (not renamed to `wlp193s0`) and NetworkManager had it **"unmanaged"**
(`nmcli -f GENERAL.REASON d show wlan0` → *The device is unmanaged because the link is
not initialized by udev*); with no network on the IdeaPad, `Legion-Go-Gen-2.local` did not resolve. **Cause (Void's,
not the Legion's):** udev starts in stage 1 (`/etc/runit/core-services/02-udev.sh`) and the
stage-2 `udevd` service (`/etc/sv/udevd/run`: `udevadm control --exit` and `exec udevd`)
replaces it; **whatever the kernel announces in that gap is lost**. In `dmesg`, three `udevd …
starting` (0.6 s initramfs, 3.8 s stage 1, **5.4 s** stage 2) and the MT7922 creating its interface on
finishing loading the firmware (~4.3 s): it fell in the gap (no `n<ifindex>` entry in
`/run/udev/data`). It had been fine for days: it is a race, and the boot changed pace that day
(`lenovo-wmi-*` modules, overdrive). **Fix on the spot:** `sudo udevadm trigger --action=add
--subsystem-match=net` (`wlp193s0` comes back and connects). **Permanent fix:** `sudo sh "$B/legion/udev-net.sh"` (in
`legion/`; `--remove`): runit service **`udev-net`** which, with `udevd` already running
(`sv check udevd` + `udevadm settle -t 30`), repeats to udev the announcement of every interface with no entry in
`/run/udev/data` and stays in `pause`. The `run` of `udevd` belongs to the package: it is not touched. Log in
`/var/log/udev-net/current`, **only if it had to act**. **Installed on 2026-10-04 and it already
acted** in a real boot that same day (see *Pending*, "Watch"). The IdeaPad has the same
gap: also installed there on 2026-10-04 (its step 4).

