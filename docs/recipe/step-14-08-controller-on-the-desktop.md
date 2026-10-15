### Controller on the desktop: Steam in the background, `extest` and the desktop layout (2026-10-04)

Like SteamOS's desktop mode: Steam runs in the background on the desktop (Xfce Wayland or
X11) and the controller (InputPlumber's Valve one) handles the desktop with Steam's **"Disposición del
escritorio"** ("Desktop Layout") (pointer with the right trackpad or the right joystick, clicks with the
triggers, on-screen keyboard with RT+X…). Three pieces, all user ones:

```bash
D="$B/legion/steam"
mkdir -p ~/.config/autostart ~/.local/share/applications ~/.local/lib/extest
cp "$D/steam-background.desktop" ~/.config/autostart/
rm -f ~/.config/autostart/steam-segundo-plano.desktop   # the old Spanish name, if it is there (otherwise Steam starts twice)
cp "$D/steam-extest.desktop" ~/.local/share/applications/steam.desktop
install -m 755 "$D/extest/libextest.so" ~/.local/lib/extest/   # or build it (below)
# the desktop layout (with Steam CLOSED):
cp "$D/desktop-layout-controller_steamos_handheld.vdf" \
   "$HOME/.local/share/Steam/steamapps/common/Steam Controller Configs/<account id>/config/413080/controller_steamos_handheld.vdf"
```

- **Steam in the background:** `~/.config/autostart/steam-background.desktop` → `steam -steamdeck
  -silent` (`-steamdeck`: the same client as Game Mode; `-silent`: without a window), with
  `extest`'s `LD_PRELOAD` in front. `xfce4-session` starts it in both sessions. It closes cleanly
  on logout (`xfce4-session` wrapper), when going to Game Mode (`steamos-session-select`) and when
  switching Wayland/X11 (`switch-mode-root`). Remove: delete the file.
- **The pointer did not move on Wayland:** Steam moves the mouse with **XTest**
  (`XTestFakeRelativeMotionEvent`) through Xwayland, which does not pass it to labwc's pointer: an invisible
  pointer acted only on the X windows (the trackpad **selected text in xterm** without moving
  the cursor; the right joystick, the same) and no `uinput` mouse was created. Known bug of
  Steam on Wayland (`steam-for-linux` #10814, #6615, #13185 on Hyprland). On SteamOS's X11 it does not
  show.
- **Tested and discarded:** InputPlumber's `touchpad` target (live, `SetTargetDevices
  deck-uhid,keyboard,mouse,touchpad` over D-Bus) moves the real pointer, but Steam kept
  acting at the same time through XTest (stray clicks and selections); it was put back to `deck-uhid, keyboard,
  mouse` (what `steamos-manager` sets).
- **`extest`** (GitHub `Supreeeme/extest`, the piece that Bazzite and similar ship; on CachyOS with
  Hyprland the desktop controller worked like this): a library loaded into Steam with
  `LD_PRELOAD`, it intercepts its XTest calls and creates a **`uinput` mouse/keyboard** (`extest fake
  device`), which labwc uses like a real one. It is not in Void and has no compiled release; **32-
  bit** (Steam's client is). Built like this on 2026-10-04 (copy of the exact source,
  `extest-1.0.3-src.tar.gz` with its `Cargo.lock`, and of the library in `legion/steam/extest/`):

  ```bash
  sudo xbps-install -Sy gcc-multilib        # link in 32-bit (brings glibc-devel-32bit)
  curl -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
  sh /tmp/rustup-init.sh -y --profile minimal --no-modify-path    # Rust in ~/.rustup and ~/.cargo
  . ~/.cargo/env && rustup target add i686-unknown-linux-gnu
  git clone --depth 1 --branch 1.0.3 https://github.com/Supreeeme/extest ~/src/extest   # commit 0d06867
  cd ~/src/extest && cargo build --release  # its .cargo/config.toml already points to i686
  install -D -m 755 target/i686-unknown-linux-gnu/release/libextest.so ~/.local/lib/extest/libextest.so
  ```

  Rust takes ~770 MB (`~/.rustup`, `~/.cargo`) and `~/src/extest` 78 MB: they can be deleted after
  building (`rm -rf ~/.rustup ~/.cargo ~/src/extest`). **Permissions:** `/dev/uinput` already has the ACL
  `user:isaac:rw` (Steam's rules): the `input` group that its README asks for is not needed. The
  `ld.so: … wrong ELF class: ELFCLASS32` in `~/.xsession-errors` are normal (the 32-bit library
  is also offered to the 64-bit processes Steam launches, which ignore it). The desktop
  Steam also carries the `LD_PRELOAD` (`steam-extest.desktop` → `~/.local/share/applications/
  steam.desktop`; the generic `steam.desktop` of that folder, without it, is the IdeaPad's). **Game
  Mode does not need it** (gamescope accepts XTest).
- **Ghost clicks from the trackpad:** the factory template (`~/.local/share/Steam/controller_base/
  desktop_neptune.vdf`) puts on the right trackpad (`absolute_mouse` mode) the left click with the
  activator **`Soft_Press` ("Pulsación suave" / "Soft Press")**, and the Legion's touchpad gave it with light touches. In
  the controller's "Calibración y configuración avanzada" ("Calibration & Advanced Settings") **there are no trackpad settings** (only joysticks,
  gyroscope and haptic response: no click pressure for the virtual controller). The
  activator was changed to **"Pulsación doble"** ("Double Press") (`Double_Press`; "Duración de doble toque" ("Double Tap Duration") 325 ms, in the
  settings of "Como mouse" ("As Mouse")): Steam → **Configuraciones de Steam → Control** (Steam Settings → Controller) → current layout of
  the buttons "… Desktop - Desktop Configuration" → **"Editar disposición"** ("Edit Layout") → right trackpad
  ("Como mouse") → its click action (left mouse click) → gear → activator. Other possible
  activators: "Presionado normal" ("Regular Press") (full press) or "Ninguna - Eliminar activador" ("None - Remove Activator").
  The triggers, from the factory: **right = left click, left = right click** (`Full_Press`).
  Steam saved it in `Steam Controller Configs/@STEAM_ACCOUNT_ID@/config/413080/
  controller_steamos_handheld.vdf` (413080 = the desktop layout; copy in Common).
- **Check:** `grep '^N:' /proc/bus/input/devices | grep extest` → `extest fake device`; `pgrep
  -af 'steam.*-silent'`; on the desktop, the trackpad moves the pointer and only clicks with a double
  tap, the right joystick moves the pointer, RT+X opens the keyboard and types. **Verified by the
  user on 2026-10-04.**

