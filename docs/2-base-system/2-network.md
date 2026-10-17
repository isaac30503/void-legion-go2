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
ssh-keygen -q -t ed25519 -N "" -C "$USER@$(hostname)" -f ~/.ssh/id_ed25519
cp "$B/legion/ssh-config" ~/.ssh/config && chmod 600 ~/.ssh/config   # Host ideapad, msi and deck
bash "$B/common/ssh-find/install-ssh-find.sh"   # finds every machine by every way (below); also on the IdeaPad
cat ~/.ssh/id_ed25519.pub        # add this line to the IdeaPad's ~/.ssh/authorized_keys
```

On the IdeaPad: `~/.ssh/config` has `Host lego` → `HostName Legion-Go-Gen-2.local`, `User isaac`; after a
reinstall the host key changes: `ssh-keygen -R legion-go-gen-2.local`. To reach the Steam Deck (`Host deck`,
`steamdeck.local`, user `deck`): `ssh-copy-id deck` once (on the Deck, SSH is enabled from its Konsole with
`passwd` and `sudo systemctl enable --now sshd`).

### ssh-find: finding the machines

A single mDNS name was not enough (2026-10-16): mDNS sometimes answered only with the IPv6 link-local address
(`fe80::`, without the interface, which ssh cannot use: `Could not resolve hostname` / `Invalid argument`), the
Wi-Fi mesh sometimes lost IPv4 ARP while IPv6 still answered (`No route to host`), the Legion renames itself with
the dock and the router changes the addresses. **`ssh-find`** (`common/ssh-find/`, without root, the same on both
machines) is the `ProxyCommand` of every machine and finds it by every way **at once**, the first that answers
winning:

1. the last address that worked, unless its MAC is now another machine's;
2. the neighbour table (`ip neigh`) entries with one of the machine's MACs, IPv4 and IPv6 link-local with its
   interface;
3. its names through the system's resolver (mDNS, DNS, `/etc/hosts`), both families; a link-local address without
   interface is tried on every interface;
4. if nothing answered: an IPv6 ping to all the nodes of the link and a sweep of port 22 on the `/24`s fill the
   neighbour table, and everything is tried again, in rounds, **for up to 15 s** (`SSH_FIND_TIMEOUT`): the mesh
   sometimes did not answer at all for a few seconds, and a single round gave up too soon.

It remembers the address that worked and the MAC behind it (`~/.cache/ssh-find/state.json`), so it learns every
interface the machine uses. The machines are in `~/.config/ssh-find/hosts.conf` (created once, with the MACs of
`local.env`; add a section to add a machine and run the installer again); the installer writes a block at the top
of `~/.ssh/config` with `ProxyCommand` and a fixed **`HostKeyAlias`** per machine: whatever address it was found at,
ssh checks the same host key, so a wrong machine at a reused address is refused. It also works for `scp`, `rsync`
and `git`. `ssh-find --list` shows what is known; `ssh-find --where lego` the address it would use;
`SSH_FIND_DEBUG=1 ssh lego` shows every attempt. `install-ssh-find.sh --remove` takes the block out.

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

From the IdeaPad: `ssh lego hostname` (a fraction of a second), `ssh-find --where lego`, and a `ping` of a few ms
(2–14 ms; with power saving, 55–100 ms).

## Problems

`ssh lego` does not resolve or SSH does not get in:

1. **`ssh-find` says it is not found:** the machine is off, or on another network and with an unknown MAC;
   `SSH_FIND_DEBUG=1 ssh lego` shows what it tried. By hand: `ssh -o ProxyCommand=none -o HostName=<IP> lego`.
   With the dock avahi renamed itself (`Legion-Go-Gen-3.local`, which `ssh-find` also tries); prevented by
   `avahi-wifi-only.sh`.
2. **It does not even answer `ping` until the Legion transmits:** Wi-Fi power saving is on
   (`iw dev wlp193s0 get power_save` → `on`): `wifi-no-powersave.sh` and Steam's switch.
3. **The Wi-Fi shows as `wlan0`, "unmanaged":** on the spot,
   `sudo udevadm trigger --action=add --subsystem-match=net`; prevented by `udev-net`.
4. **After a reinstall:** on the IdeaPad, `ssh-keygen -R legion-go-gen-2.local`.
