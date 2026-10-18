# Login and modes

Like SteamOS: **no login screen and no password**. At power-on lightdm logs `isaac` in automatically into **the
last mode used**: **Game Mode** (gamescope + Steam, [game mode](../6-game-mode/2-game-mode.md)), the **desktop**
(Xfce on Wayland, the normal one) or the **X11 desktop** (backup). Switching restarts lightdm into the other
session. **Administration still asks for the password** (`sudo`, packages, `void-update`): the only thing that
runs without it is `switch-mode-root`.

| From | To | How |
|---|---|---|
| Game Mode | Desktop | Steam's power menu → "Cambiar a escritorio" ("Switch to Desktop") |
| Desktop | Game Mode | applications menu → **"Modo Juego"** ("Game Mode") (it closes the desktop at once: save first) |
| Desktop | Wayland ↔ X11 | the launchers "Escritorio Wayland" / "Escritorio X11" |

**Never log in from lightdm's login screen** (it only shows after logging out): its greeter does not die on
lightdm's `SIGTERM`, and ~20 s later it takes the console from gamescope or labwc and lightdm locks the session.
Autologin and mode switches avoid it entirely. The greeter's accessibility bus (at-spi) was what kept it alive:
the Legion starts it without it (`NO_AT_BRIDGE=1` through `lightdm-greeter-wrapper`, below); the IdeaPad has
`at-spi-enabled = false` in `/etc/lightdm/lightdm-gtk-greeter.conf` (`sudo sh "$B/common/steam/greeter-without-atspi.sh"`;
its recipe, step 14).

## Install

After [Steam](../6-game-mode/1-steam.md) and [Game Mode](../6-game-mode/2-game-mode.md), and **before rebooting**
together with [Xfce on Wayland](../5-desktop/1-xfce.md) (otherwise "Switch to Desktop" would go to a session
without labwc):

```bash
sudo sh "$B/common/steam/install-direct-session.sh"          # the Game Mode Wayland session
sudo sh "$B/common/steam/install-passwordless-switch.sh"  # autologin, switch without password, clean Steam shutdown
```

(`--remove` undoes each one; without autologin, the login screen with password comes back.)

**`install-direct-session.sh`:** the session `/usr/share/wayland-sessions/steam-game-mode-direct.desktop` (gamescope on
the screen) and `/usr/local/bin/lightdm-greeter-wrapper` (`NO_AT_BRIDGE=1`, `greeter-wrapper=…` in
`/etc/lightdm/lightdm.conf`).

**`install-passwordless-switch.sh`:**

- **`/etc/xdg/lightdm/lightdm.conf.d/60-steam-mode.conf`:** autologin of `isaac` into `steam-game-mode-direct`,
  `xfce-wayland` or `xfce`. Running the script again keeps the mode in use (the first time: Game Mode). lightdm reads
  that folder **before** `lightdm.conf`, whose `autologin-user`/`autologin-session` lines from the ISO are commented.
- **`/usr/local/bin/switch-mode-root game|desktop|desktop-x11 [--check]`** (root): sets that session and restarts
  lightdm. **`/etc/sudoers.d/zz-switch-mode`**: `isaac` may run only that script without password (checked with
  `visudo -cf`). The `zz` matters: `sudoers.d` is read in order and **the last matching rule wins** (otherwise the
  `wheel` rule, which asks for the password, overrides it).
- **Restarting lightdm without a race with elogind:** a plain `sv restart lightdm` let the new session start while
  elogind was still cleaning the old one, and elogind deleted `/run/user/1000` with the new `wayland-0`: everything
  fell back to X11 (flickering screen, different panels). `switch-mode-root` runs **`sv once mode-switch`**
  (`/etc/sv/mode-switch`, one-shot, with a `down` file), which runs `/usr/local/lib/switch-mode/restart-lightdm <uid>`:
  `sv stop lightdm`, waits **event-driven** (`inotifywait` on elogind's `/run/systemd/users` and `/run/systemd/sessions`) for
  the seat's session to close and, if the user was left with none, for `/run/user/<uid>` to be deleted (caps 10 s
  + 5 s), then `sv start lightdm`. It runs under runit because a process launched from the session dies with it
  (it once stopped lightdm and never started it again). Log `/run/switch-mode.log`.
- **Steam closes cleanly** on every way out, so that its next start does the quick check (`Verifying file sizes
  only`) and not the full one (`Verifying all executable checksums`):
  - **Power-off or reboot** (Steam's menu, `reboot`, `poweroff`, `loginctl`, the power menu, critical battery):
    **`/etc/runit/shutdown.d/05-close-steam.sh`**, run by runit's stage 3 (`/etc/runit/3` loads `shutdown.d/*.sh` in order) **before** `10-sv-stop.sh` stops lightdm; elogind's power-off and reboot go through `/usr/bin/halt` and `/usr/bin/reboot`, which are runit's:
    `steam -shutdown` as its user (`chpst -u`, with the process's own environment) and an event-driven wait
    (`timeout 20 pidwait -x steam`). It leaves **`/run/system-shutting-down`**, and `switch-mode-root` does nothing
    while it exists (otherwise, when Steam ends in Game Mode, the launcher would take it as "Switch to Desktop" and
    change the boot mode). Not with `reboot -f` or a hard power-off. (Void's documented `/etc/rc.shutdown` runs
    after lightdm is stopped: too late.)
  - **Logging out of Xfce** (panel's button, Super+Escape, Ctrl+Alt+Del): `xfce4-session` closes the session
    before asking for the reboot, and Steam died with Xwayland. The wrapper **`/usr/local/bin/xfce4-session`**
    (`/usr/local/bin` comes first in the session's `PATH`) runs the real one and, when it ends, `steam -shutdown`
    and the wait, with the session still alive. Xfce's `RunHook`s do not work for this (xfce4-session 4.20 does not
    wait for them).
  - **Desktop → Game Mode:** `steamos-session-select` closes the desktop's Steam the same way before switching.
  - **Desktop Wayland ↔ X11:** `switch-mode-root` closes Steam first too.

## Check

```bash
cat /etc/xdg/lightdm/lightdm.conf.d/60-steam-mode.conf      # autologin-session=…
sudo -n -l | grep switch-mode                                # (root) NOPASSWD: /usr/local/bin/switch-mode-root
ls -l /var/service/mode-switch /usr/local/bin/xfce4-session /etc/runit/shutdown.d/05-close-steam.sh
ls /run/user/1000 | grep -c wayland-0                        # 2 in the desktop session (wayland-0 and its .lock)
```

After a switch or a reboot with Steam open, `~/.local/share/Steam/logs/` shows `Shutdown` and the next start
`Verifying file sizes only`. Switch times: Game Mode → desktop ~2 s; desktop → Game Mode ~3 s.

## Problems

- **The screen stays off after a switch:** from another machine `ssh -t lego sudo sv start lightdm`, then
  `cat /run/switch-mode.log` and check `ls -l /var/service/mode-switch`.
- **After a switch the screen flickers and the panels look different:** the race with elogind (it deleted
  `/run/user/1000`): reboot, and check that `install-passwordless-switch.sh` is the current one.
- **Steam always does the full verification on start:** check the clean-shutdown pieces (`ls -l
  /usr/local/bin/xfce4-session /etc/runit/shutdown.d/05-close-steam.sh` and `steamos-session-select`). A single
  full check after one dirty close is normal and fixes itself.
- **Stuck:** Ctrl+Alt+F2, log in, `pkill -KILL -x gamescope-wl` (gamescope's process name) and
  `sudo sv restart lightdm` (it logs into the autologin mode). Logs: `~/.local/state/steam-game-mode.log`,
  `~/.local/state/steamos-session-select.log`; lightdm's, with `sudo sh "$B/common/diag/diag-lightdm.sh"`.
- **Old messages on the screen for an instant when switching** (the firmware logo, a `unix_chkpwd` line): leftovers
  in the console's memory (the kernel has `FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER`; without `/dev/log`, syslog writes
  to the console). To see who sends them: `common/diag/capture-syslog.sh` (a temporary runit service).
- **Harmless in logs:** `[libseat] … Could not close device: Unknown object '/org/freedesktop/login1/session/cN'`
  when a session closes (the session no longer exists when the compositor releases its devices).
