# Network and SSH

Wi-Fi (NetworkManager with its default engine, wpa_supplicant) that always answers, a stable mDNS name
(`Legion-Go-Gen-2.local`) and SSH in both directions with the IdeaPad (and to the Steam Deck).

## Install

```bash
sudo sh "$B/legion/avahi-wifi-only.sh"     # mDNS only over the Wi-Fi
sudo sh "$B/legion/wifi-no-powersave.sh"   # Wi-Fi without power saving
sudo sh "$B/legion/udev-net.sh"            # gives back to udev the interfaces it misses at boot
```

Then SSH, on the Legion (without root):

```bash
ssh-keygen -q -t ed25519 -N "" -C "isaac@Legion-Go-Gen-2" -f ~/.ssh/id_ed25519
cp "$B/legion/ssh-config" ~/.ssh/config && chmod 600 ~/.ssh/config   # Host ideapad, msi and deck
cat ~/.ssh/id_ed25519.pub        # add this line to the IdeaPad's ~/.ssh/authorized_keys
```

On the IdeaPad: `~/.ssh/config` has `Host lego` → `HostName Legion-Go-Gen-2.local`, `User isaac`; after a
reinstall the host key changes: `ssh-keygen -R Legion-Go-Gen-2.local`. To reach the Steam Deck (`Host deck`,
`steamdeck.local`, user `deck`): `ssh-copy-id deck` once (on the Deck, SSH is enabled from its Konsole with
`passwd` and `sudo systemctl enable --now sshd`).

**What each script does** (each has `--remove`):

- **`avahi-wifi-only.sh`:** `allow-interfaces=wlp193s0` in `[server]` of `/etc/avahi/avahi-daemon.conf` (leaves
  `.bak`). With the dock the Legion is on two networks (Wi-Fi `wlp193s0`, 192.168.0.x, and the dock's
  `enp196s0f3u1u1`, 192.168.1.x); avahi heard its own announcement on the other one and renamed itself to
  `Legion-Go-Gen-3.local`. Trade-off: with cable only and the Wi-Fi off, there is no `.local` name.
- **`wifi-no-powersave.sh`:** `/etc/NetworkManager/conf.d/wifi-no-powersave.conf` (`[connection]`
  `wifi.powersave = 2`) and `iw … set power_save off` at once. With the MT7922's factory power saving the radio
  slept and did not answer ARP or mDNS until the Legion itself transmitted: SSH did not get in either way.
  Steam has its own switch for this (turned off in [Steam's settings](../6-game-mode/1-steam.md)).
- **`udev-net.sh`:** runit service **`udev-net`**. Void's udev runs in stage 1 (`/etc/runit/core-services/02-udev.sh`) and is replaced by
  the stage-2 `udevd` service (`/etc/sv/udevd/run`: `udevadm control --exit`, then `exec udevd`); what the kernel announces in that gap is lost, and the MT7922 sometimes creates its
  interface then: it came up as `wlan0`, "unmanaged". With `udevd` running (`sv check udevd` +
  `udevadm settle -t 30`) the service repeats the announcement of every interface with no entry in
  `/run/udev/data`, then stays paused. Log `/var/log/udev-net/current`, only when it had to act.

The Wi-Fi engine stays wpa_supplicant (no continuous scans here, unlike the IdeaPad's RTL8723BE, which needed
iwd); switch to iwd only if those symptoms appear.

## Check

```bash
pgrep -a avahi-daemon                      # running [Legion-Go-Gen-2.local]
iw dev wlp193s0 get power_save             # Power save: off (also after rebooting)
ssh ideapad hostname                       # ideapad-100
```

From the IdeaPad: `getent hosts Legion-Go-Gen-2.local`, `ssh lego hostname`, and a `ping` of a few ms (2–14 ms;
with power saving, 55–100 ms).

## Problems

`ssh lego` does not resolve or SSH does not get in:

1. **With the dock:** avahi renamed itself (`Legion-Go-Gen-3.local`). Prevented by `avahi-wifi-only.sh`;
   meanwhile, by IP: `ssh -o HostName=<IP> -o HostKeyAlias=legion-go-gen-2.local lego`.
2. **It does not even answer `ping` until the Legion transmits:** Wi-Fi power saving is on
   (`iw dev wlp193s0 get power_save` → `on`): `wifi-no-powersave.sh` and Steam's switch.
3. **The Wi-Fi shows as `wlan0`, "unmanaged":** on the spot,
   `sudo udevadm trigger --action=add --subsystem-match=net`; prevented by `udev-net`.
4. **After a reinstall:** on the IdeaPad, `ssh-keygen -R Legion-Go-Gen-2.local`.
