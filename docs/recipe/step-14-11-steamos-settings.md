### SteamOS settings: compared live with a Steam Deck (2026-10-05)

**How it was compared:** a Steam Deck LCD at home (`ssh deck`, SteamOS 3.8.16, kernel
6.16.12-valve24.5; access set up in the Claude context) and the Legion, both running, reading
the same on both (read-only): kernel and its line, `sysctl`, huge pages, swap, CPU, disk
scheduler, mounts, limits, modules, background processes, audio priority, global environment and
versions. For Game Mode, SteamOS's session (the Deck's `/usr/lib/steamos/gamescope-session`,
**identical** to that of this Legion's SteamOS saved in the rescue,
`gamescope-session-valve-original`) against our launcher. What differed and was applied:

| What | Deck (SteamOS) | Legion before | Where it is applied |
|---|---|---|---|
| `kernel.split_lock_mitigate` | 0 (`/usr/lib/sysctl.d/30-splitlock.conf`) | 1 | `like-steamos.sh` |
| `fs.inotify.max_user_watches` / `_instances` | 524288 / 1024 (`10-arch.conf`) | 175875 / 128 | `like-steamos.sh` |
| `net.core.default_qdisc` | `fq_codel` (systemd's `50-default.conf`) | `pfifo_fast` | `like-steamos.sh` |
| Transparent huge pages | `always` | `madvise` | `like-steamos.sh` (`/etc/rc.local`) |
| Audio (PipeWire, WirePlumber) | real time, RR 20, nice −11 (`rtkit`) | normal | `like-steamos.sh` (`rtkit` installed; D-Bus starts it) |
| `earlyoom` | running, `-M/-S 409600,307200 -r 3600` | no | `like-steamos.sh` |
| `gamemoded` | running | no | `like-steamos.sh` (`gamemode`, `libgamemode-32bit`) |
| 32-bit gamescope Vulkan layer | yes | no (`gamescope-32bit`) | `like-steamos.sh` and `install-steam.sh` |
| Steam with `-pipewire` | always (`/usr/bin/steam-jupiter`) | no | `like-steamos.sh` (desktop), `install-game-mode.sh` (Game Mode) |
| Kernel preemption | `CONFIG_PREEMPT=y` (full) | voluntary (`PREEMPT_DYNAMIC`) | `like-steamos.sh`: `preempt=full` |
| `memlock` | 8 MiB (systemd) | 1 MiB (`10-gcr-memlock.conf` of the `gcr` package) | `like-steamos.sh` |
| `ENABLE_GAMESCOPE_WSI=1` (gamescope's Vulkan layer in games) | yes | no | `install-game-mode.sh` |
| `GAMESCOPE_LIMITER_FILE` (Steam's FPS limiter) | yes | no | `install-game-mode.sh` |
| `STEAM_USE_DYNAMIC_VRS` + `RADV_FORCE_VRS_CONFIG_FILE` ("1x1") | yes | no | `install-game-mode.sh` (AMD GPU only) |
| `STEAM_DISPLAY_REFRESH_LIMITS` (screen range for Steam) | 40,60 (LCD) | nothing | `install-game-mode.sh`: 48,144 on the Legion Go 2 (DMI `83N0`/`83N1`) |

```bash
sudo bash "$B/legion/like-steamos.sh"               # with bash; if Steam is open, it closes it cleanly
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen
sudo reboot
# undo: sudo bash "$B/legion/like-steamos.sh" --remove   (the packages stay)
```

- **`like-steamos.sh`** ("like SteamOS"; in `legion/`; log `~/like-steamos.log`), in order:
  1. `/etc/sysctl.d/30-like-steamos.conf` (the table's four keys) and `sysctl -p`. Void
     loads it at boot (`/etc/runit/core-services/08-sysctl.sh` goes through `/etc/sysctl.d/*.conf`).
     The `fq_codel` queue applies to interfaces created afterwards; the Wi-Fi shows `noqueue`
     (its driver carries its own queue): it mostly affects the dock's network.
  2. Block `# >>> like-steamos` … `# <<< like-steamos` in `/etc/rc.local` with `echo always >
     /sys/kernel/mm/transparent_hugepage/enabled` (and applies it right away).
  3. Installs what is missing of `rtkit earlyoom gamemode libgamemode-32bit gamescope-32bit` (74
     packages with their 32-bit dependencies on 2026-10-05), `/etc/sv/earlyoom/conf` with
     `OPTS="-M 409600,307200 -S 409600,307200 -r 3600"` and enables `earlyoom` in runit. **`rtkit` does not go
     in runit** (2026-10-08): D-Bus starts it on demand when PipeWire asks for it
     (`/usr/share/dbus-1/system-services/org.freedesktop.RealtimeKit1.service`); with both they clashed
     (see *Watch*). If it finds `/var/service/rtkit` (installation from before 2026-10-08), it does
     `sv down rtkit` and removes the link; `--remove` also removes it if present (**verified after
     rebooting on 2026-10-08**, on both machines: see *Watch*). `gamemoded` is not a
     service: D-Bus starts it in the session when a game asks for it. The
     packages create the user `rtkit` and the groups `rtkit` and `gamemode` (2026-10-05); `isaac` is not
     in `gamemode`, same as `deck` on the Deck: it is not needed.
  4. `-pipewire` in `~/.local/share/applications/steam.desktop` and
     `~/.config/autostart/steam-background.desktop` (with `sed`, as the user; Common's copies
     `steam-extest.desktop` and `steam-background.desktop` already carry it).
  5. `preempt=full` in `GRUB_CMDLINE_LINUX` of `/etc/default/grub` (creates it if not there) and
     `update-grub`. **Not in `GRUB_CMDLINE_LINUX_DEFAULT`**: that one is rewritten entirely by
     `silent-boot.sh` and `grub-hidden.sh` (checked: they only touch that one).
  6. `/etc/security/limits.d/91-like-steamos.conf`: `isaac - memlock 8192` (the user's rules
     over `gcr`'s `@users`).
  - **Steam open:** the desktop one starts by itself in the background, so asking to close it was
    no use (the first time the script refused and did nothing). Now it closes it itself, like
    `05-close-steam.sh`: `steam -shutdown` with the process's own environment and `pidwait` (30 s).
- **`install-game-mode.sh`** (common, `common/steam/`): in the direct-screen branch,
  `ENABLE_GAMESCOPE_WSI=1`, `GAMESCOPE_LIMITER_FILE` and, if the GPU is AMD (`vendor` `0x1002`),
  `STEAM_USE_DYNAMIC_VRS=1` with its file `RADV_FORCE_VRS_CONFIG_FILE` (`1x1` = no reduction;
  Steam changes it from Performance). The files in `/tmp`, like SteamOS: games read them
  from inside Steam's container (pressure-vessel). And Steam with `-pipewire`. The 64-
  bit layer already came with the `gamescope` package (`VkLayer_FROG_gamescope_wsi.x86_64.json`, enabled
  with `ENABLE_GAMESCOPE_WSI=1` and disabled with `DISABLE_GAMESCOPE_WSI=1`).
- **Verified on 2026-10-05** after rebooting (20:58): the four `sysctl` keys, huge pages
  `always`, `rtkit` and `earlyoom` running, **PipeWire and WirePlumber in real time (RR 20, nice
  −11, same as the Deck)**, the five packages, and the desktop Steam with `-steamdeck -pipewire
  -silent`. **`preempt=full` and `memlock` verified the same day** after the second pass and another
  reboot (21:08): `preempt=full` in `/proc/cmdline`; `Max locked memory` 8388608 bytes in the
  graphical session (`/proc/<labwc pid>/limits`) and `ulimit -l` 8192 over SSH. **Game Mode verified
  the same day** (21:15–21:27) with Borderlands 3 and the Deck in its Game Mode next to it:
  - Steam with the same arguments as on the Deck (`-steamos3 -steampal -steamdeck -gamepadui
    -pipewire`) and its same gamescope variables plus the three new ones; in the game's process
    (`Borderlands3.exe`, `/proc/<pid>/environ`): `ENABLE_GAMESCOPE_WSI=1`, `GAMESCOPE_LIMITER_FILE`,
    `RADV_FORCE_VRS_CONFIG_FILE`, `STEAM_USE_DYNAMIC_VRS=1` (and `DXVK_HDR=1`), and **the layer loaded**
    (`/run/host/usr/lib/libVkLayer_FROG_gamescope_wsi_x86_64.so` in `/proc/<pid>/maps`).
  - **FPS limit at 30:** in `~/.local/share/Steam/logs/console-linux.txt`, `[Gamescope WSI]
    Swapchain received new refresh cycle: 33.33ms` (the game's layer applies it). Gamescope:
    screen at 120 Hz (`GAMESCOPE_DISPLAY_REFRESH_RATE_FEEDBACK`), VRR supported and off.
  - **Half-rate shading** (Performance): the `RADV_FORCE_VRS_CONFIG_FILE` file went from
    `1x1` to `2x2` when enabling it (RADV reads it live).
- **FPS limit at half without VRR (2026-10-05, found and solved with VRR).** With the layer already
  active, Steam's limit gave half: 30 → 15 and 60 → 30 in MangoHud, with the game without its own limit
  or with 60 (the game's own limit did work). Without the layer (`DISABLE_GAMESCOPE_WSI=1`),
  the limit did nothing: **before these settings the FPS limit did not work on the Legion**.
  - **Cause: the screen modes that gamescope fabricates.** The panel (EDID) only has one
    native mode, **1920×1200 at 144 Hz** (clock 380.16 MHz). gamescope recognizes the screen (`Got known
    display: lenovo_legiongo2_oled`, script `lenovo.legiongo2.oled.lua`, from gamescope 3.16.30; the
    Deck's, 3.16.23, does not have it) and for the other frequencies (48–144) it **fabricates** modes by stretching the
    vertical blanking time with the same clock. Steam sets the screen to a multiple of the limit that
    fits in the range (its help text says so: "ajustará automáticamente la frecuencia de
    actualización de la pantalla a un múltiplo de la frecuencia de fotogramas" — "will automatically adjust
    the display refresh rate to a multiple of the frame rate"). The user's test,
    limit → screen → result: **36 → 144 Hz → 36 ✓; 48 → 144 Hz → 48 ✓; 40 → 120 Hz → 20 ✗;
    50 → 100 Hz → 25 ✗** (32 → 128 Hz gave ~30, unexplained). With the fabricated modes one
    of every two refreshes is lost. Before `STEAM_DISPLAY_REFRESH_LIMITS` the screen stayed fixed in the
    fabricated 120 Hz mode and **all** the limits came out at half.
  - **Why the fabricated modes fail: not found out.** Unchecked suspicions: the amdgpu
    patches of Valve's kernel (with which that script was made), the panel's self-refresh (PSR;
    live test: `echo 1 > /sys/kernel/debug/dri/0000:c2:00.0/eDP-1/disallow_edp_enter_psr`,
    with debugfs mounted) or `amdgpu.freesync_video=1`. Not tested: with VRR it is not needed.
  - **`STEAM_DISPLAY_REFRESH_LIMITS=48,144`** in the launcher (only `83N0`/`83N1`, by DMI; like
    SteamOS with the Deck: 40,60 the LCD, 45,90 the OLED): Steam knows the range and governs the frequency
    (`GAMESCOPE_DYNAMIC_REFRESH`); without a limit it goes back to the native 144 Hz. The flicker when changing
    the limit is the mode change (it already happened before).
  - **Fix: VRR** (Rendimiento (Performance) → **"Habilitar VRR"** ("Enable VRR"); the screen supports it,
    `GAMESCOPE_VRR_CAPABLE` = 1). With VRR gamescope stays in the native 144 Hz mode and the screen
    refreshes when each frame arrives: the limit comes out exact (verified by the user on
    2026-10-05: `GAMESCOPE_VRR_ENABLED` = 1, screen 144 Hz, limit 40 → `refresh cycle: 25.00ms`).
    Steam saves the setting. Without VRR, use limits that divide 144 (36, 48, 72). **No flicker or
    brightness changes with VRR** on the OLED (user, 2026-10-05): **it stays like this** (the user's decision).
  - **Why VRR works** (explanation): without VRR the screen refreshes at a fixed pace and, to
    limit to 40, Steam sets it to 120 Hz and the layer shows a frame every 3 refreshes; as the
    panel only knows 144 Hz, gamescope fabricates the 120 mode by lengthening the pause between refreshes, and with
    that mode the refreshes arrive at half pace: 3 refreshes take twice as long and 20 come out. With VRR
    no mode is fabricated: the panel stays in its native 144 Hz mode but waits for each frame
    and refreshes when it arrives; Steam only spaces the frames (25 ms at 40 FPS) and does not count
    refreshes, so there is no half. Inside, VRR also lengthens the pause, but the
    driver does it refresh by refresh its own way (which works here), not with a complete mode change with
    the fixed pause (which is what fails).
  - **Limit inside the game or with Steam?** In consumption, the same: in both cases the GPU and the CPU
    stop making frames that are not going to be shown. Differences:

    | | Game's limit | Steam's limit (gamescope layer) |
    |---|---|---|
    | Consumption | same | same |
    | Input delay | lower if the game's limiter is good (it waits *before* reading the controls) | may add some (Steam's help warns: "mayor retraso de entrada" / "higher input latency") |
    | Regularity | depends on the game (some stutter) | very regular, the same in all |
    | Convenience | setting in each game | one control in the quick menu |

    **Recommendation:** by default Steam's, with VRR. In games where response matters
    (shooters, fighting), if the controls feel heavy, the game's with Steam's off.
    **Do not set both with different values** (they fight and stutter): if both are used, the game's
    somewhat above Steam's (e.g. 45 and 40) or disabled. In Borderlands 3 the game's
    limit works fine (user, 2026-10-05).
  - That day Steam set **Proton 11.0** for Borderlands 3 (on 2026-10-04, 9.0-2RC).
  - In Steam's log there are `[Gamescope WSI]` lines also from 2026-10-04, before enabling it:
    in some case it already loaded; from now on, always in Game Mode.
  - **Differences that remain with the Deck, on purpose:** here `--adaptive-sync` (the screen has
    VRR); there `-w 1280 -h 800`, the `steam` cursor and what belongs to its hardware or to systemd (see below), and
    the statistics pipe `-T` / `GAMESCOPE_STATS` (not copied: it is not known what Steam uses from it).
- **What was seen and NOT copied:**
  - **zram** (the Deck: zstd, half the RAM, priority 100): discarded by the user; with 21 GB
    of RAM it would hardly be used. Nor **zswap** (the Deck's kernel enables it, but there zram rules).
  - **PipeWire block size** (Deck: `clock.quantum` 512, minimum 256, maximum 8192, in
    `/etc/pipewire/pipewire.conf.d/context-properties.conf`; Legion: 1024/32/2048 from the factory):
    tuned to the Deck's sound; touch it only if there are crackles.
  - The Deck's kernel line (`amd_iommu=off`, `ttm.pages_min=2097152`,
    `amdgpu.sched_hw_submission=4`, `amdgpu.lockup_timeout`…): its chip's.
  - What systemd or SteamOS pieces require: `STEAM_LAUNCH_WRAPPER_SCOPE` (a cgroup per game),
    `STEAM_ALLOW_DRIVE_UNMOUNT/ADOPT` (format/unmount from Steam), `steamos-cfs-debugfs-tunings`
    (disabled on the Deck too; they are settings of the old scheduler, CFS).
  - The Deck's hardware: `STEAM_ENABLE_FAN_CONTROL`, `STEAM_ENABLE_STATUS_LED_BRIGHTNESS`,
    `jupiter-fan-control`. (`STEAM_DISPLAY_REFRESH_LIMITS` also belongs to its screen, but it **was
    applied** with the Legion's range, 48,144: see the table and "FPS limit at half".) `STEAM_ENABLE_CEC` (HDMI-CEC with dock)
    and `WINEDLLOVERRIDES=dxgi=n` (it goes with a Valve Mesa patch).
  - **Wi-Fi power saving:** the Deck has it on; here it was turned off on purpose (steps 2–3).
  - `sched_ext`: disabled on the Deck; Void's kernel does not have it.
- **It was already the same or better:** `vm.max_map_count`, `amd-pstate-epp` with `balance_performance`,
  `ntsync` (`/dev/ntsync` open to all), swappiness and disk writeback, `nofile`
  (524288 here; 1024/524288 on the Deck), and **newer versions on the Legion**: Mesa 26.2.4
  (Deck 26.0.0-devel) and gamescope 3.16.30 (Deck 3.16.23.4).

