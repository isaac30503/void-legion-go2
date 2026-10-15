### Power button: press = suspend, held ~3 s = power menu, in both modes, like the Deck (2026-10-14)

The user's request: the Steam Deck's power button (a short press suspends, held opens the power menu) in Game Mode
and on the desktop. **What the Deck does** (read on it, SteamOS 3.8.28): logind ignores the key
(`HandlePowerKey=ignore`); in Game Mode `steamos-powerbuttond` (Valve, C, a user service started with the gamescope
session) reads the button and sends `steam -ifrunning steam://shortpowerpress` or, if still held after 1 s
(`alarm(1)`), `steam://longpowerpress`; its devices are marked by udev (`STEAMOS_POWER_BUTTON`, `TAG+="uaccess"`).
On its desktop, KDE: `PowerButtonAction=1` (suspend), no long press.

**What the Legion Go 2 sends** (captured on 2026-10-14, read-only, the last time with the lines printed live and a
stopwatch): the firmware tells the two presses apart by itself, at **~3 s**:
- **released before ~3 s:** the ACPI `Power Button` gives `KEY_POWER` pressed and released in the same millisecond,
  **when the button is released**;
- **held ~3 s:** the embedded controller types **Super+F16** on the internal keyboard (`AT Translated Set 2
  keyboard`, scancodes `0xdb`/`0x67`; Void's hwdb already maps `0x67` to F16, the same as Valve's for 83N0/83N1)
  **while it is still held**, and no `KEY_POWER` at all.
So each event is one action and nothing is timed here (the ~3 s is the firmware's; the Deck's 1 s cannot be had).
Holding much longer, the firmware powers off at once (happened on 2026-10-14). **How it was misread first** (kept,
so as not to repeat it): the first captures did not show when the button was released, `KEY_POWER` looked like
"at every press" and F16 like "~3–5.5 s after it" (it was the time since an earlier short press), so the order
was turned around for a while (press = menu, held = suspend); the stopwatch capture settled it.

**Before (careful):** elogind's default is `HandlePowerKey=poweroff`. On the desktop xfce4-power-manager blocks
it (inhibitor `handle-power-key`), but in **Game Mode one press powered the Legion off** (2026-10-14).

`common/power-button/`, installed with `sudo sh "$B/common/power-button/install-power-button.sh"` (and then
`sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen`, whose launcher starts it):
- **`/usr/local/bin/power-button --mode game|desktop`** (Python, standard library; not C: the user's decision, no
  build step, the same speed here, ~10 MB of memory and 0 % CPU at rest). Event-driven, no timers: it sleeps in
  `poll()` on the marked devices, a pidfd of its session's process (it ends with it) and a `timerfd` with
  `TFD_TIMER_CANCEL_ON_SET`, which the kernel cancels on every resume (`timerfd_resume()`): presses in the 2 s after
  waking up are ignored (the waking press would suspend it again). Game Mode: press → `steam://shortpowerpress`
  (Steam suspends), held → `steam://longpowerpress` (Steam's power menu); desktop: press → `loginctl suspend`,
  held → `xfce4-session-logout` (shut down, restart, suspend, hibernate, log out). One per user
  (the newest session's). Log: `~/.local/state/power-button.log`.
- **`/etc/udev/rules.d/70-power-button.rules`**: `POWER_BUTTON=1` and `uaccess` for the ACPI `Power Button` and, on
  83N0/83N1 only, the internal keyboard (the embedded controller's: no other keys come through it).
- **`/etc/elogind/logind.conf.d/50-power-button.conf`**: `HandlePowerKey=ignore`, `HandlePowerKeyLongPress=ignore`
  (reloaded with `SIGHUP`, no session touched; check: `busctl get-property org.freedesktop.login1
  /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey` → `s "ignore"`).
- **`/etc/xdg/autostart/power-button.desktop`**: the desktop's (X11 and Wayland). Game Mode: its launcher, only if
  the program is installed.
- xfce4-power-manager: `power-button-action` = 0 (nothing), in `legion/xfce/` (in the X11 session it would act too).

