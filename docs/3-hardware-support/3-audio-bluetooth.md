# Audio and Bluetooth

PipeWire with WirePlumber (from the ISO), in **real time** like SteamOS (`rtkit`, [system](../2-base-system/1-system.md)),
Bluetooth audio through `libspa-bluetooth`, a fixed order of preferred devices, and two terminal tools:
`audio-ctrl` (volume and device) and `audio-priority` (the order).

## Install

`bluetoothd` is enabled by `desktop-1-root.sh` ([desktop](../5-desktop/1-xfce.md)); the two fish functions are
copied by the desktop's user part. The Legion does not come with Bluetooth blocked (`rfkill`: `ideapad_bluetooth`
and `hci0` unblocked). The IdeaPad does (its firmware keeps the block across reboots): there,
`sudo sh "$B/common/bluetooth/bluetooth-at-boot.sh"` adds `rfkill unblock bluetooth` to `/etc/rc.local` (its recipe, step 9).

**Bluetooth name** (it announces itself as "BlueZ 5.86" from the factory: bluez takes the name from
`systemd-hostnamed`, which Void does not have). Without root:

```bash
bluetoothctl system-alias Legion-Go-Gen-2      # "Changing Legion-Go-Gen-2 succeeded"
bluetoothctl show | grep Alias                 # Alias: Legion-Go-Gen-2
```

bluez keeps it in `/var/lib/bluetooth/`. (With root, instead: `Name = Legion-Go-Gen-2` in `/etc/bluetooth/main.conf`.)

**Pairing** (headphones, the 8BitDo Retro 87 Keyboard X and Retro R8 Mouse), each in pairing mode, without root:

```bash
M=@HEADPHONES_BT_MAC@
bluetoothctl remove $M
{ echo "scan on"; sleep 12; echo "scan off"; } | bluetoothctl >/dev/null
bluetoothctl pair $M && bluetoothctl trust $M && bluetoothctl connect $M
pactl set-default-sink "$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')"   # if the sound stays on another output
```

(Or from blueman.) Paired devices: `bluetoothctl devices`.

**Order of the audio devices**, from most to least preferred: **outputs** Bluetooth headphones (Skullcandy Method
360 ANC) → speakers (`pci-0000_c2_00.6`) → monitor's HDMI (MAG 276CF) → UGREEN CM581; **inputs** UGREEN CM581
microphone → internal microphone → headphones. In a terminal of the session (not over SSH; it applies from the
next session):

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp "$B/legion/wireplumber/51-audio-priority.conf" ~/.config/wireplumber/wireplumber.conf.d/
wpctl settings -s node.restore-default-targets false     # let the priority rule
```

The copy from `"$B"` carries the real serial number and MAC from `local.env`. If a device changes, its name
(`node.name`, with the USB serial or the MAC) no longer matches: choose the order again with `audio-priority`.

## The tools

- **`audio-ctrl`:** choose output or input and the device (`fzf`; directly if there is only one), switch the card's
  profile if it is internal or "off", and set the volume with a bar (← → in steps of 5, ↓ to type the number,
  Enter confirms, `q`/Ctrl+C leaves it as it was). Uses `pactl`.
- **`audio-priority`:** choose output or input and mark the devices with Tab, **from lowest to highest** priority
  (connected ones and those saved before). Writes `~/.config/wireplumber/wireplumber.conf.d/51-audio-priority.conf`
  (`priority.session`/`priority.driver` 5000, 6000…), sets `node.restore-default-targets false` and restarts
  WirePlumber without systemd (`pkill` + `pidwait` + `setsid -f wireplumber`; PipeWire runs with `SIGTERM`
  blocked and WirePlumber inherits it, so after 3 s it uses `SIGKILL`). **Run it in a terminal of the session**,
  not over SSH (the new WirePlumber would lack the session bus).

## Check

`bluetoothctl info $M` → `Paired/Bonded/Trusted/Connected: yes`; `pactl list cards` → `Active Profile: a2dp-sink`;
`bluetoothctl show` lists `Audio Sink`/`Audio Source` (PipeWire is registered in bluez).

## Problems

- **Bluetooth headphones "connect" and drop at once** (`Failed to connect: org.bluez.Error.Failed
  br-connection-create-socket`, no audio): they only keep their **last** pairing well (they were paired with the
  IdeaPad afterwards). If they are connected to the other machine, release them there first
  (`bluetoothctl disconnect @HEADPHONES_BT_MAC@`), then the pairing block above with the headphones in pairing mode.
- **A hung `audio-priority`** of an old version: `pkill -KILL -x wireplumber` from another terminal.

## Known noise (harmless)

- `xfce4-pulseaudio-plugin-WARNING … pa_context_connect() failed: Access denied` once or twice at login: a race
  with `pipewire-pulse`; the plugin retries every 5 s and connects.
- WirePlumber's `optional component 'support.logind' … failed to load` and `skipping component
  'monitor.bluez.seat-monitoring'`: `wireplumber-elogind` is missing, on purpose. **Do not install it:** it makes
  WirePlumber release Bluetooth when the seat is not active, and the Game Mode ↔ desktop switches could cut the
  headphones.
- If PipeWire is restarted with the session open, Firefox loses its audio until the page is reloaded.
