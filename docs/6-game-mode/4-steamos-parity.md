# SteamOS parity

The Legion was compared **live with a Steam Deck** (SteamOS 3.8, read-only on both: kernel and its line, `sysctl`,
huge pages, swap, CPU, disk scheduler, limits, modules, background processes, audio priority, environment,
versions) and with SteamOS's own `gamescope-session` (`/usr/lib/steamos/gamescope-session` on the Deck). What differed and was applied:

| What | Deck (SteamOS) | Where it is applied |
|---|---|---|
| `kernel.split_lock_mitigate` | 0 | `like-steamos.sh` ([system](../2-base-system/1-system.md)) |
| `fs.inotify.max_user_watches` / `_instances` | 524288 / 1024 | `like-steamos.sh` |
| `net.core.default_qdisc` | `fq_codel` | `like-steamos.sh` |
| Transparent huge pages | `always` | `like-steamos.sh` |
| PipeWire and WirePlumber | real time (RR 20, nice −11) | `like-steamos.sh` (`rtkit`, started by D-Bus) |
| `earlyoom`, `gamemoded` | running | `like-steamos.sh` |
| Kernel preemption | full | `like-steamos.sh` (`preempt=full`) |
| `memlock` | 8 MiB | `like-steamos.sh` |
| 32-bit gamescope Vulkan layer | yes | `like-steamos.sh`, `install-steam.sh` (`gamescope-32bit`) |
| Steam with `-pipewire` | always | `like-steamos.sh` (desktop), `install-game-mode.sh` (Game Mode) |
| `ENABLE_GAMESCOPE_WSI=1` (gamescope's layer in games) | yes | `install-game-mode.sh` |
| `GAMESCOPE_LIMITER_FILE` (Steam's FPS limiter) | yes | `install-game-mode.sh` |
| `STEAM_USE_DYNAMIC_VRS=1` + `RADV_FORCE_VRS_CONFIG_FILE` (`1x1`) | yes | `install-game-mode.sh` (AMD GPU only) |
| `STEAM_DISPLAY_REFRESH_LIMITS` | 40,60 (LCD) | `install-game-mode.sh`: **48,144** on the Legion Go 2 (DMI `83N0`/`83N1`) |

The limiter and VRS files live in `/tmp`, like SteamOS: games read them from inside Steam's container. **Different on
purpose:** here `--adaptive-sync` (the screen has VRR); the Deck's `-w 1280 -h 800`, its `steam` cursor, its hardware's
variables (fan, LED, CEC), its kernel line, zram, its PipeWire block size and the systemd-only pieces are not copied;
the Wi-Fi power saving is off here. Already the same or better: `vm.max_map_count`, `amd-pstate-epp`, `ntsync`,
swappiness, `nofile`, and newer Mesa and gamescope than the Deck.

**Check** (in a running game's process, `/proc/<pid>/environ`): `ENABLE_GAMESCOPE_WSI=1`, `GAMESCOPE_LIMITER_FILE`,
`RADV_FORCE_VRS_CONFIG_FILE`, `STEAM_USE_DYNAMIC_VRS=1`, and the layer loaded
(`libVkLayer_FROG_gamescope_wsi_x86_64.so` in `/proc/<pid>/maps`). With an FPS limit set, Steam's
`console-linux.txt` shows `[Gamescope WSI] Swapchain received new refresh cycle: …ms`.

## FPS limit and VRR

**Turn on "Habilitar VRR"** ("Enable VRR") in Performance ([Steam's settings](1-steam.md)). Without VRR, Steam's FPS
limit gives **half** (30 → 15, 60 → 30): the panel has only one native mode (1920×1200 at **144 Hz**); for other
rates gamescope fabricates modes (stretching the vertical blanking), Steam sets the screen to a multiple of the limit,
and with those fabricated modes every other refresh is lost (40 → 120 Hz → 20 FPS; 36 or 48 → 144 Hz → fine). With VRR
the panel stays at its native 144 Hz and waits for each frame: the limit is exact (40 → `refresh cycle: 25.00ms`). No
flicker or brightness change with VRR on this OLED. Without VRR, use limits that divide 144 (36, 48, 72).

**Game's limiter or Steam's?** The same power use. Steam's is very regular and one control for all games, but may add
some input latency; a game's good limiter can respond better. Default: Steam's, with VRR; in shooters or fighting
games, if the controls feel heavy, the game's with Steam's off. **Never both with different values** (they fight and
stutter).

## Problems

- **A game looks or runs worse:** first suspect, gamescope's Vulkan layer: in that game's launch options,
  `DISABLE_GAMESCOPE_WSI=1 %command%`. For the whole system: `sudo bash "$B/legion/like-steamos.sh" --remove` and reboot.
- **Launch options need `%command%`:** without it, Steam passes what was written to the game as arguments.
