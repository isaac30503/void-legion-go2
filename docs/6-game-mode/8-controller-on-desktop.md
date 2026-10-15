# The controller on the desktop

Like SteamOS's desktop mode: **Steam runs in the background** on the desktop (Wayland or X11) and the controller
(InputPlumber's Valve one) drives the desktop with Steam's **"Disposición del escritorio"** ("Desktop Layout"): pointer
with the right trackpad or right stick, clicks with the triggers (right = left click, left = right click), on-screen
keyboard with RT+X. **Game Mode does not need any of this.**

## Install (as the user, with Steam closed)

```bash
D="$B/legion/steam"
mkdir -p ~/.config/autostart ~/.local/share/applications ~/.local/lib/extest
cp "$D/steam-background.desktop" ~/.config/autostart/
cp "$D/steam-extest.desktop" ~/.local/share/applications/steam.desktop
install -m 755 "$D/extest/libextest.so" ~/.local/lib/extest/
K="$HOME/.local/share/Steam/steamapps/common/Steam Controller Configs/@STEAM_ACCOUNT_ID@/config/413080"
mkdir -p "$K" && cp "$D/desktop-layout-controller_steamos_handheld.vdf" "$K/controller_steamos_handheld.vdf"
```

(`@STEAM_ACCOUNT_ID@` is the Steam account's folder number in `~/.local/share/Steam/userdata/`; 413080 is the desktop
layout.)

- **Steam in the background:** `steam-background.desktop` → `steam -steamdeck -silent` with `extest`'s `LD_PRELOAD`;
  `xfce4-session` starts it in both sessions; it closes cleanly on every switch and logout
  ([login and modes](../4-sessions/1-login-and-modes.md)). To stop it, delete the file.
- **`extest`** (`Supreeeme/extest` 1.0.3, MIT): on Wayland Steam moves the pointer with **XTest** through Xwayland,
  which never reaches labwc's pointer (the trackpad selected text in xterm without moving the cursor; a known Steam bug
  on Wayland). `extest`, loaded into Steam with `LD_PRELOAD`, turns those XTest calls into a **`uinput`
  mouse/keyboard** that labwc uses like a real one. 32-bit (Steam's client is). `/dev/uinput` already has an ACL for the
  user (Steam's udev rules): no `input` group needed. (InputPlumber's own `touchpad` target moved the pointer, but
  Steam kept acting through XTest at the same time: discarded.)
- **The trackpad's click:** the desktop template puts the left click on the right trackpad with the activator **"Pulsación
  suave" ("Soft Press")**, which the Legion's touchpad triggers with light touches. The saved layout uses **"Pulsación
  doble" ("Double Press")** (325 ms), and the gyroscope as mouse ([controllers](../3-hardware-support/1-controllers.md)).
  By hand: Steam → **Configuraciones de Steam → Control** (Steam Settings → Controller) → the desktop layout →
  **"Editar disposición"** ("Edit Layout") → right trackpad ("Como mouse" / "As Mouse") → its click → gear → activator.

## Building `extest`

The library comes from the Release; its exact source (`extest-1.0.3-src.tar.gz`, with `Cargo.lock`) is in
`legion/steam/extest/`. To rebuild it (e.g. if a Steam update breaks it):

```bash
sudo xbps-install -Sy gcc-multilib        # links in 32-bit (brings glibc-devel-32bit)
curl -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
sh /tmp/rustup-init.sh -y --profile minimal --no-modify-path    # Rust in ~/.rustup and ~/.cargo
. ~/.cargo/env && rustup target add i686-unknown-linux-gnu
git clone --depth 1 --branch 1.0.3 https://github.com/Supreeeme/extest ~/src/extest   # commit 0d06867
cd ~/src/extest && cargo build --release  # its .cargo/config.toml already targets i686
install -D -m 755 target/i686-unknown-linux-gnu/release/libextest.so ~/.local/lib/extest/libextest.so
```

Rust (~770 MB), `~/src/extest` and `gcc-multilib` are kept on purpose for that (to free the space anyway: `rm -rf ~/.rustup ~/.cargo ~/src/extest`); `void-update` warns if the library
lacks something or the build tools are gone.

## Check

```bash
grep '^N:' /proc/bus/input/devices | grep extest        # extest fake device
pgrep -af 'steam.*-silent'
```

On the desktop: the trackpad moves the pointer and clicks only with a double tap; the right stick moves it; RT+X opens
the keyboard and types.

## Problems

- **The trackpad or right stick do not move the pointer (but select text):** `extest` is not in the running Steam
  (check the `extest fake device` above). Start Steam with its launcher or the autostart (both carry the `LD_PRELOAD`);
  if a Steam update broke it, rebuild it.
- **The trackpad clicks by itself:** the activator went back to "Pulsación suave": set "Pulsación doble", or copy the
  layout again.
- **After closing Steam's on-screen keyboard, the trackpad and sticks stop moving the pointer** (intermittent): Steam
  missed the keyboard's close (`Set OSK active 1` without its `0` in `~/.local/share/Steam/logs/controller_ui.txt`) and
  kept the keyboard's action set. Open and close the keyboard again (RT+X). To capture it if it repeats (read-only,
  event-driven): `bash "$B/legion/diag-steam-keyboard.sh"`, then `--stop`; results in `/tmp/diag-steam-keyboard/`
  (`grep -E 'OSK active|OnFocusWindowChanged' /tmp/diag-steam-keyboard/controller_ui.txt`).
- **Steam's on-screen keyboard comes out huge or with a border:** the `type="utility"` exception is missing in labwc's
  `rc.xml` ([windows](../5-desktop/3-windows-and-shortcuts.md)).
- **Harmless:** `ld.so: … libextest.so … wrong ELF class: ELFCLASS32` in `~/.xsession-errors` (the 32-bit library is
  also offered to Steam's 64-bit processes, which ignore it).
