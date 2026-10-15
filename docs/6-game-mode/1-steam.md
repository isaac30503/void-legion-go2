# Steam

Steam from Void's `nonfree`/`multilib` repositories, with Vulkan for the GPU, MangoHud and gamescope. On the desktop
it is started **with `-steamdeck`** (the same client as Game Mode) and stays in the background
([controller on the desktop](8-controller-on-desktop.md)).

## Install

```bash
sudo sh "$B/common/steam/install-steam.sh"     # --remove undoes it (packages listed in legion/steam/installed-packages.txt)
```

It enables the `nonfree` and `multilib` repositories and installs Steam, gamescope, MangoHud (with
`MangoHud-mangoapp` and `MangoHud-32bit`), the 32-bit pieces of Void's `README.voidlinux`, Vulkan **according to
the GPU** (`/sys/class/drm/card0/device/vendor` `0x1002` → `mesa-vulkan-radeon` and its `-32bit`; here "AMD Radeon
890M Graphics (RADV STRIX1)", Vulkan 1.4), `pipewire-32bit` and `libspa-videoconvert-32bit` (for
[Remote Play](7-remote-play.md)), with an AMD GPU `mesa-vaapi` and `mesa-vaapi-32bit` (hardware video), and the
limits SteamOS has (`nofile 524288`, `vm.max_map_count`).

**Log out and back in** (the `nofile` limit), then **before opening Steam the first time**, the desktop launcher with
`-steamdeck` and `extest`:

```bash
mkdir -p ~/.local/share/applications ~/.local/lib/extest
cp "$B/legion/steam/steam-extest.desktop" ~/.local/share/applications/steam.desktop
install -m 755 "$B/legion/steam/extest/libextest.so" ~/.local/lib/extest/
```

Then open Steam **from the menu** (not with `steam` in a terminal): it updates itself (~500 MB) and you log in.

**Why `-steamdeck` on the desktop:** Steam has two clients, the normal one (branch `''`) and the Steam Deck one
(`steamdeck_stable`, used with `-steamdeck`). Alternating desktop and Game Mode without it, Steam switched branch and
**downloaded and installed the other client every time** (~1 min more to enter Game Mode; in
`~/.local/share/Steam/logs/console-linux.txt`: `Client beta changed from '' to 'steamdeck_stable'`). The argument
rules, not the file `~/.local/share/Steam/package/beta`. Without `-gamepadui`, the desktop keeps its normal interface. The generic
`legion/steam/steam.desktop` (with `-steamdeck`, without `extest`) can be made from the system's:
`sed -E 's#^Exec=/usr/bin/steam( |$)#Exec=/usr/bin/steam -steamdeck\1#' /usr/share/applications/steam.desktop > ~/.local/share/applications/steam.desktop`
(or `cp "$B/legion/steam/steam.desktop" ~/.local/share/applications/`).

## Settings in Steam (by hand, once)

1. **Game Mode → Ajustes → Sistema → "Activar modo desarrollador"** (Settings → System → "Enable Developer Mode");
   on the new **"Desarrollador"** ("Developer") page, **turn off "Habilitar administración de energía para Wi-Fi"**
   ("Enable Wi-Fi Power Management"): otherwise Steam turns the Wi-Fi power saving back on, which breaks SSH
   ([network](../2-base-system/2-network.md)). The page does not exist without developer mode, nor in the desktop's
   Big Picture.
2. **Ajustes → Teclado** (Settings → Keyboard) → inglés (EE. UU.) internacional (English (US) international): the
   keyboard of Steam's interface and its on-screen keyboard (games and xterm get it from the launcher).
3. **VRR:** in Game Mode, with a game open, quick menu (`…`) → Rendimiento (Performance) → **"Habilitar VRR"**
   ("Enable VRR"); Steam saves it ([why](4-steamos-parity.md#fps-limit-and-vrr)).
4. **Microsd library:** add `/mnt/microsd` ([storage](../2-base-system/3-storage.md)).

## xterm as a game

```bash
install -m 755 "$B/common/steam/xterm-steam" ~/.local/bin/
```

In Steam, add xterm as a "juego que no es de Steam" ("non-Steam game") and in *Propiedades → Acceso directo → Destino*
(*Properties → Shortcut → Target*) put `/home/<user>/.local/bin/xterm-steam` (Steam needs the absolute path). The
wrapper removes Steam's `LC_ALL=C` and `LD_PRELOAD`; in Game Mode it loads `.Xresources` and fills the screen. Its
library art: [library art](6-library-art.md). Inside it, fastfetch says `steamcompmgr (X11)` and
`XDG_SESSION_TYPE=x11` (Steam forces it through Xwayland): Game Mode is not X11 (`pgrep Xorg` gives nothing).

## Problems

- **Steam takes ~1 min to enter Game Mode:** the desktop Steam was started without `-steamdeck` (e.g. `steam` from a
  terminal) and it is installing the other client. Always start it from the menu or its launcher.
- **Steam does the full check on start** (`Verifying all executable checksums`): it closed dirty once; it fixes
  itself on the next clean close ([clean shutdown](../4-sessions/1-login-and-modes.md)).
- **Harmless in Steam's logs:** SteamOS pieces that do not exist here (`steamos-select-branch: not found`,
  `timedatectl: not found`, `telemetry`, `atomupd proxy`, `steamos-mandatory-update` /
  `jupiter-initial-firmware-update` (127), `invalid screen reader locale: auto`), `xfce4-notifyd` "cannot open
  display" when entering Game Mode, and on the desktop only `invalid profile: balanced` and `SteamOSManager: daemon
  not present` (steamos-manager's user process runs only in Game Mode, on purpose).
