## 5–12. X11 desktop

### Root part 1: packages, Papirus teal and Bluetooth

```bash
sudo bash "$B/legion/desktop-1-root.sh"     # log: ~/desktop-1-root.log
```

Deletes the `.new-*` of `/etc`; installs what steps 5, 6, 7 and 9 of the IdeaPad install in a single command
(`fish-shell fzf ntfs-3g curl git ripgrep xdg-utils` + the whole list of step 9: 63 packages on
2026-10-03; plus `xrandr`, for step 13); `papirus-folders -C teal --theme Papirus-Dark`; and enables `bluetoothd`.

**Bluetooth: the Legion does not come with it blocked** (`rfkill`: `ideapad_bluetooth` and `hci0`
unblocked): the IdeaPad's `bluetooth-at-boot.sh` is **not needed**. If one day it comes back
blocked after a reboot, set it up the same as there.

**Name: `Legion-Go-Gen-2`, its hostname** (2026-10-08, approved by the user; same as the IdeaPad,
step 9 of its recipe). From the factory it announced itself as "BlueZ 5.86" (bluez takes it from `systemd-hostnamed`,
which Void does not have). The adapter's **alias** is changed, without root (on 2026-10-08 it also worked over SSH):

```bash
bluetoothctl system-alias Legion-Go-Gen-2      # "Changing Legion-Go-Gen-2 succeeded"
bluetoothctl show | grep Alias                 # Alias: Legion-Go-Gen-2 (Name stays at "BlueZ 5.86")
```

bluez saves it in `/var/lib/bluetooth/` (on the IdeaPad it survives the reboot; here, not checked after
rebooting on 2026-10-08). Alternative with root: `Name = Legion-Go-Gen-2` in `/etc/bluetooth/main.conf`.

**Bluetooth headphones (Skullcandy Method 360 ANC, `@HEADPHONES_BT_MAC@`), 2026-10-03.** With
`libspa-bluetooth` and PipeWire registered in bluez (`bluetoothctl show` lists `Audio Sink`/`Audio
Source`), they connect with the `a2dp-sink` profile. **Trap: they only keep the last pairing properly.**
Paired with the Legion and then with the IdeaPad, on the Legion they "connected" and dropped instantly with
`Failed to connect: org.bluez.Error.Failed br-connection-create-socket`, with no audio output. Also,
if they are connected to the other machine, first they have to be released there (`bluetoothctl disconnect
@HEADPHONES_BT_MAC@`). Fix, with the headphones in pairing mode (light blinking), without root:

```bash
M=@HEADPHONES_BT_MAC@
bluetoothctl remove $M
{ echo "scan on"; sleep 12; echo "scan off"; } | bluetoothctl >/dev/null
bluetoothctl pair $M && bluetoothctl trust $M && bluetoothctl connect $M
pactl set-default-sink "$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')"   # if the sound stays on another output
```

Check: `bluetoothctl info $M` → `Paired/Bonded/Trusted/Connected: yes`; `pactl list cards`
→ `Active Profile: a2dp-sink`. To use them again on the IdeaPad, the same there.

### User part (without root)

```bash
V="$B/common"      # originally: C="<disk>/Backups Linux"; V="$C/fish/void"
# 5. fish from bash (the login shell stays /bin/bash: getent passwd isaac)
mkdir -p ~/.bashrc.d && cp "$V/shell/99-exec-fish.sh" ~/.bashrc.d/
cp ~/.bashrc ~/.bashrc.bak && cat "$V/shell/bashrc-block.sh" >> ~/.bashrc
# 6. functions (and the translations of their messages: docs/i18n.md)
mkdir -p ~/.config/fish/functions ~/.local/bin
bash "$B/install/install-i18n.sh"   # ~/.local/share/void-legion (without it, the messages come out in English)
cp "$V/fish/functions/"{__vl_t,fish_prompt,fish_greeting,disk-ops}.fish ~/.config/fish/functions/
cp "$V/fish/functions/"{install-pkg,remove-pkg,audio-ctrl,audio-priority}.fish ~/.config/fish/functions/   # audio-*: see step 6 of the IdeaPad
cp "$V/ssh-setup/ssh-setup.fish" ~/.config/fish/functions/
cp "$V/ssh-setup/ssh-survey.sh" ~/.config/fish/ && chmod +x ~/.config/fish/ssh-survey.sh
fish -c 'fish_add_path -U ~/.local/bin'
bash "$V/void-update/install-void-update.sh" --no-tray   # void-update + its patch test (without root; see "void-update" below)
# 9. fonts, Orchis, Volantes
mkdir -p ~/.local/share/fonts ~/.themes ~/.local/share/icons
cp "$V/fonts/"*.ttf ~/.local/share/fonts/
cp -r "$V/xterm/jetbrains-blocks" ~/.local/share/fonts/ && chmod +x ~/.local/share/fonts/jetbrains-blocks/regenerate.sh
fc-cache -f ~/.local/share/fonts
tar xzf "$V/xfce/orchis-themes.tar.gz" -C ~/.themes/
tar xzf "$V/xfce/volantes-cursors.tar.gz" -C ~/.local/share/icons/
# 11. xterm and default terminal
X="$V/xterm"; mkdir -p ~/.config/xfce4
cp "$X/Xresources" ~/.Xresources && cp "$X/xterm-papirus.xpm" ~/.local/share/icons/
cp "$X/helpers.rc" ~/.config/xfce4/helpers.rc && cp "$X/xprofile" ~/.xprofile
cp "$X/xdg-terminal-exec" ~/.local/bin/ && chmod +x ~/.local/bin/xdg-terminal-exec
# 12. fastfetch
mkdir -p ~/.config/fastfetch && cp "$V/fastfetch/gen-config.py" ~/.config/fastfetch/ && python3 ~/.config/fastfetch/gen-config.py
```

- **`~/.local/bin` has to exist before `fish_add_path`:** otherwise it returns an error (with
  `set -e` it cut the first time, without a message).
- Check: `fish -c 'functions -q install-pkg disk-ops ssh-setup; and echo OK'` and `void-update --version`;
  `fc-list | grep -ci jetbrains` → 100 (104 after root part 2, which copies the 4 Blocks to
  `/usr/local/share/fonts/`); `fc-match "JetBrainsMono NFM Blocks:charset=23fa" family`
  → `Adwaita Mono`; `ls ~/.themes` → the 6 variants of Orchis.
- **Step 7 (Claude Code):** goes separately, further down.

### void-update: updates, panel icon and automatic checks (2026-10-11)

It replaces the fish function `update-system` (the user's decision, 2026-10-11: the old name is removed),
modeled on CachyOS's **cachy-update** (a fork of *arch-update*), in `common/void-update/`, on both machines.
Installed without root by the block above (`install-void-update.sh`, which also installs the patch test and the
translations, removes `~/.config/fish/functions/update-system.fish` and moves the date of the last update to
`~/.local/state/void-update/last-update`, the one fastfetch shows). After step 13, the panel icon:

```bash
void-update --tray --enable      # starts it now and at every login (~/.config/autostart/void-update-tray.desktop)
```

| | |
|---|---|
| `void-update` | full update: syncs; shows **Void's news** published since the last update (https://voidlinux.org/atom.xml; on 2026-03-10 one asked for a manual step with `linux-firmware`); the **list colored like cachy-update** (the changed part of each version in red → green) with the download size; the warning about packages built here that the update would replace (patch test); **one** confirmation; xbps first, then everything; sshd if OpenSSH changed; Flatpak; orphans except kernels; cache; loose kernels; `.new-*`; LazyVim; **runit services still running old code** (a process with a replaced library or executable, `(deleted)` in `/proc/<pid>/maps`, followed up to its `runsv`): it offers to restart them (`sv restart`; never `lightdm`, `dbus` or the consoles); the **summary** OK / REPAIRED / WARNING (the same checks as before); and if there is a new kernel or glibc, it **asks** whether to reboot (`[y/N]`: it never reboots by itself). A lock prevents two at a time |
| `void-update --check` | looks for updates **without root**: `xbps-install -Mun` fetches the repositories' index into memory (~5–10 s), and `flatpak remote-ls --updates`. Updates the icon and, if the list changed, sends a notification with a "Run void-update" button |
| `void-update --list` · `--news [N]` · `--services` · `--summary` | the pending list (exit 7 if none) · Void's latest news · services with old code · only the summary, without sudo |
| `void-update --tray [--enable\|--disable]` | the icon (Ayatana AppIndicator, already installed: nm-applet needs it) |
| `void-update --gen-config` · `--show-config` · `--edit-config` | `~/.config/void-update/void-update.conf` (interval, notifications, Flatpak, news…; example in `common/void-update/void-update.conf.example`) |

**The icon**, like cachy-update's: **Void's symbol in one color** (white, for the black panel; black with
`tray_icon_style=dark`) with a status badge in its corner: ✓ up to date, ↓ updates available, ··· checking,
! the check failed (2026-10-13, the user's request: the distribution's symbol in black and white, consistent with
the panel; the first version used Papirus' update icons). SVGs in `common/void-update/icons/`, made by its
`generate.py` from `/usr/share/void-artwork/void-logo.svg` (the arcs and the dot, as vectors); the "updates
available" one is also the launcher's and the notification's (`~/.local/share/icons/hicolor/scalable/apps/void-update.svg`). Its menu: "N
updates available" (runs it), submenus *Packages (N)*, *Flatpak (N)* and *All (N)* with the list, last and
next check, **Run void-update**, **Check for updates**, **Exit**; the middle click runs it too (in Ayatana the
left click opens the menu). "Run" opens `void-update.desktop` in a terminal (xterm, as the rest of the
system), which waits for Enter at the end. **Automatic checks:** when the network connects (NetworkManager's
`StateChanged` over D-Bus) if the last one is older than the interval, and every `check_interval_hours`
(6 by default, like cachy-update's timer; 0 = only on connect). The icon reacts to void-update's state file
event-driven (file monitor), never polling it. It does not start in Game Mode (no session autostart there).
**Verified on the IdeaPad on 2026-10-11:** `--check` found 3 updates in 10 s without root; `--summary`
identical to `update-system --resumen` (same lines, in Spanish); the icon shows in the top panel's tray.

### Root part 2: login screen same as the session (step 10)

```bash
sudo bash "$B/legion/desktop-2-root.sh"     # log: ~/desktop-2-root.log
```

The same as step 10 of the IdeaPad (system copies of Orchis, Volantes and the font;
`lightdm-gtk-greeter.conf`; black bar), with one correction: **the greeter's `gtk.css` is copied
with `install -o lightdm -g lightdm -m 644`** and not with `sudo -u lightdm cp`, because `Common`, mounted
by udisks for `isaac`, cannot be read by the user `lightdm` ("Permiso denegado" / "Permission denied"; the same would happen
to the IdeaPad). The script does not overwrite `lightdm-gtk-greeter.conf.bak` if it already exists (on repeating it,
it would save the new configuration on top of the original).

