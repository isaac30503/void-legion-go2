### steamos-manager: TDP, profiles and GPU clock from Steam (2026-10-04)

Valve's service with which Steam handles **Rendimiento** (Performance) (the `…` menu). The Go 2 has an official
profile (`/usr/share/steamos-manager/devices/legion-go-series.toml`: `83N0`/`83N1` →
`legion_go_2`): TDP through `lenovo-wmi-other-0` (profile `custom`), profiles of
`lenovo-wmi-gamezone`, GPU level and manual clock through `amdgpu` (`[gpu_performance]`), and it sets
in InputPlumber `deck-uhid, keyboard, mouse`. **It needs the modules of the previous section.** Binary v26.4.1
**with an own patch** (`set_clocks`, below; since 2026-10-08), built here with
`build-steamos-manager.sh`; everything in `common/steam/steamos-manager/`, with the official tarball without
patch (the one from the Void container, IdeaPad recipe, step 14) to go back.

```bash
cp -r "$B/common/steam/steamos-manager" ~/steam/
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"   # remove: --remove
sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen # the launcher starts the user one
sudo sh "$B/legion/gpu-overdrive.sh" && sudo reboot                     # manual GPU clock (below)
```

- **Two processes, as in SteamOS:** the **root** one (`steamos-manager -r`, system bus) is the
  runit service **`steamos-manager`** (log `/var/log/steamos-manager/current`); the
  **user** one (session bus: Steam talks to it) is started by the Game Mode launcher
  (`install-game-mode.sh`, since 2026-10-04: only if `/usr/lib/steamos-manager` exists; its
  log goes to `steam-game-mode.log`). On the desktop it does not run: Performance belongs to Game Mode.
- **The installer** (`xbps-install` of `speech-dispatcher` and `glib` if missing) copies the tree of
  `make install` **without** systemd units, sddm setting or D-Bus activation files
  (`Exec=/bin/false` + `SystemdService`), with a list in `/usr/local/share/steamos-manager-void/manifest`
  (used by `--remove`), removes `[gpu_power_profile]` from the profiles if `pp_power_profile_mode` is missing
  (below), and reloads D-Bus. The rest of `legion-go-series.toml` stays as it comes. In the same folder
  it records, on every installation (since 2026-10-08), the **reference that `void-update` reads**: `sha256`
  (output of `sha256sum /usr/lib/steamos-manager /usr/bin/steamosctl` as they were installed; it is
  checked by `sha256sum -c`) and `package` (the tarball's name without `.tar.gz`, e.g.
  `steamos-manager-v26.4.1-void-2`: with it `void-update` says whether it is the patched one or the official one).
  `--remove` deletes the whole folder.
- **It needs `tracefs`**, which Void does not mount: without it, it crashed on start with `Error: No such file or
  directory (os error 2)` after "Starting SLS log receiver" (its `ftrace` creates
  `/sys/kernel/tracing/instances/…`). It was found by `diag-steamos-manager.sh` (in the foreground with
  `RUST_LOG=debug`: without tracefs exit 1; with it, 124 = running). The `run` mounts it
  (`mountpoint -q /sys/kernel/tracing || mount -t tracefs nodev /sys/kernel/tracing`).
- **GPU power profile: impossible with this kernel.** It reads `device/pp_power_profile_mode`,
  which the normal amdgpu **does not provide** on this GPU (SMU 14.0.0: its table in 6.18.55 has no
  `get_power_profile_mode`; **neither does Valve's**: checked on 2026-10-04 in the source of
  `linux-neptune-618-6.18.50.valve2`, SteamOS's on this Legion, where only
  `smu_v14_0_2` has it, from the RDNA 4 dedicated graphics cards; nor in Linux 7.3-rc5). The installer removes `[gpu_power_profile]` from
  the profiles if the file does not exist: Steam does not show the option and there are no errors (a `WARN
  Can't add GpuPowerProfile1 interface` remains, expected).
- **Manual GPU clock: overdrive** (`gpu-overdrive.sh`, in `legion/`; `--remove`).
  Without bit `0x4000` of `amdgpu.ppfeaturemask` (factory `0xfff7bfff`), writing to
  `pp_od_clk_voltage` gives `Invalid argument`. It goes in **`/etc/modprobe.d/amdgpu-overdrive.conf`**
  (`options amdgpu ppfeaturemask=0xfff7ffff`), not in GRUB (`silent-boot.sh` rewrites the whole
  kernel line), and the script rebuilds with `dracut` the initramfs **of all installed
  kernels** (it copies it inside; new kernels already bring it when installed; until 2026-10-08,
  only that of the running kernel). The kernel becomes *tainted* ("Overdrive is enabled" in `dmesg`): only a
  warning. With "Reloj de GPU manual" ("Manual GPU Clock") enabled in Steam it works (verified on 2026-10-04 at 2900 MHz,
  below).
- **With the manual clock disabled, the official steamos-manager fills the log with `Error setting
  manual GPU clock: Invalid argument`** (harmless: the GPU stays at `auto`; **the patch removes it**,
  next point). Steam reapplies its performance
  profile many times per session and always sends the saved clock (`manual gpu clock enabled: 0`
  + `manual gpu clock hz: 2900` in `steamui_steamos.txt`); steamos-manager 26.4.1 writes it to
  `pp_od_clk_voltage` even if the level is `auto` (`AmdgpuPerformanceLevelDriver::set_clocks`:
  *Only used when GPU Performance Level is manual, but write whenever called*) and **this GPU's SMU 14
  only accepts a fixed clock in `manual` mode** (`smu_v14_0_od_edit_dpm_table`: *Only allowed in
  manual mode*). Hundreds show up per session (179 until 2026-10-08; not 1–3 at start, as was believed
  at first). Removing `[gpu_performance]` removes them, but also the manual clock: do not do it.
- **Patch `0001-gpu-set_clocks-only-in-manual.patch`** ("set_clocks only in manual") (2026-10-08, approved by the user): at the
  start of `AmdgpuPerformanceLevelDriver::set_clocks` (`steamos-manager/src/gpu.rs`) it reads the level
  and, if it is not `manual`, it writes nothing (`debug!`, which with `RUST_LOG=info` does not show) and returns OK. **Nothing
  is lost:** outside `manual` the driver rejected that clock anyway. It assumes that Steam,
  when enabling "Reloj de GPU manual" ("Manual GPU Clock"), sets the level to `manual` **before** sending the clock: in
  `steamui_steamos.txt` it always writes `Set manual gpu clock enabled` before `hz`, but with the clock
  enabled **too** (confirmed on 2026-10-08, below: the clock is applied immediately). It adjusts
  two tests (`test_set_amdgpu_gpu_clocks`: with `auto` it does not write, with `manual` it does;
  `manager/root.rs` `manual_gpu_clock`: sets `manual` before). The process that writes is the **root** one
  (the user one only passes `SetManualGpuClock` over D-Bus): restarting the service is enough.
- **How it is built** (without root, on this machine; 1 min 30 s): dependencies `sudo xbps-install -S
  glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config` (plus `git`, `make` and the Rust
  of rustup in `~/.cargo/bin`, `extest`'s; on 2026-10-08, Rust 1.99.0), and then

  ```bash
  bash "$B/common/steam/steamos-manager/build-steamos-manager.sh" /tmp
  ```

  Before anything it **tests the patch** against that tag (`patch-still-needed git`, since
  2026-10-09; YA_INCLUIDO (ALREADY_INCLUDED) → it does not build; CONFLICTO (CONFLICT) → it stops; on 2026-10-09, HACE_FALTA (STILL_NEEDED) on v26.4.1, commit
  `a0d399defebd`, the same that the script checks). `void-update` also looks at the latest upstream
  tag and, if it is new, tests the patch against it (NOTA (NOTE) on its line).
  It clones the tag `v26.4.1` in `~/src/steamos-manager` (checks commit `a0d399d`), applies the
  `0*.patch` of its folder, `make build`, `make test` inside `dbus-run-session` (two tests, the
  `job` one and the `ftrace` one, need a session bus: over SSH they fail without it, also without the patch),
  `make install DESTDIR=…` and packs `/tmp/steamos-manager-v26.4.1-void-2.tar.gz` (owner `root`), which
  is copied by hand to the Common folder. It checks `ldd`, `steamosctl --version` and that the list of
  files, permissions and owners is that of the official tarball; when done it deletes `~/src/steamos-manager`.
  **Result of 2026-10-08:** 248 of 248 tests fine; same 62 entries as the official tarball (only
  the two binaries change); `ldd` without `not found` (here and on the IdeaPad); `steamosctl --version` =
  `steamos-manager 26.4.1`; binary `/usr/lib/steamos-manager` with sha256 `cc464424…1586c`, **identical
  bit for bit** in two consecutive builds (the official one installed until now: `a4b222d7…5faf6`).
  **The build dependencies are kept on purpose** (the user's decision, 2026-10-08: they are
  needed to rebuild steamos-manager with `build-steamos-manager.sh` after an update, and that
  script stops if any is missing). Cost: 34 packages, **≈ 470 MB** installed (with `libllvm21`, which
  only clang uses; Mesa uses `libllvm22`), which `void-update` updates with the rest. They are only
  steamos-manager's: `extest` uses rustup's Rust and `gcc-multilib`, and gamescope and the wlroots portal are
  built with `xbps-src`, which installs their dependencies inside its own environment
  (`binary-bootstrap`, in `~/src/void-packages`), not in the system. To remove them one day (before,
  `speech-dispatcher` marked as manual, below): `sudo xbps-remove -R glib-devel eudev-libudev-devel
  speech-dispatcher-devel clang pkg-config` (`xbps-remove -Rn …` shows the list first). The crates
  cache stays in `~/.cargo/registry` (from 24 to 151 MB).
  **`speech-dispatcher`, marked as manually installed** (recommended): `sudo xbps-pkgdb -m manual
  speech-dispatcher`. It provides `libspeechd`, which steamos-manager needs (the binary does not come from xbps, so
  xbps does not know). `install-steamos-manager.sh` only installs it if missing, and with the ISO's `orca`
  it is already there, as an automatic dependency. Today it is held by `orca` and `speech-dispatcher-devel`; if one day
  both were removed (or an `xbps-remove -R` dragged it along), steamos-manager would stop starting. That is why
  the command also goes in list J. `strace` (from the InputPlumber diagnosis) is still installed:
  pending the user's decision (*Pending → To do*).
- **Installing the patch on the already installed Legion** (2026-10-08): `install-steamos-manager.sh` already uses
  `steamos-manager-v26.4.1-void-2.tar.gz` (to go back to the official one, change `TAR` to the one without `-2` and
  repeat it). It is installed with `sudo sh /tmp/instalar-steamos-manager-parche.sh` (run by the user;
  copies of the installer and of the tarball in `/tmp/sm-parche`, without Common): it checks the tarball's sha256,
  calls the installer, which reinstalls and restarts the service, and shows the binary's sha256 and `sv
  status`. The user process keeps the old binary in memory until leaving and entering
  Game Mode again (or rebooting): it is not needed for the fix, but that way both run the same.
  **Verified on 2026-10-08** (below).
- **Why it does not happen on the Steam Deck:** the Deck does not carry a Z1 (that one is the ROG Ally's and the Legion Go
  1's), but an APU of Valve's own, **Van Gogh** ("Aerith" in the LCD, "Sephiroth" in the OLED; SMU
  11.5), whose driver accepts writing the clock (`OD_SCLK`) at any level. The Legion Go 2 carries the
  **Z2 Extreme** (Strix Point, SMU 14.0.0), and there `smu_v14_0_od_edit_dpm_table` rejects it outside
  `manual`. steamos-manager is designed for the Deck and always writes the clock, and Steam resends the
  saved value on every performance update: hence the errors.
- *History (2026-10-08):* the manual clock and the overdrive **were removed due to a misunderstanding** (it
  was approved believing that it was no use here; it was: 2900 MHz in `manual` on 2026-10-04).
  `install-steamos-manager.sh` removed `[gpu_performance]` from `legion-go-series.toml` and
  `gpu-overdrive.sh --remove` deleted the `.conf`; verified after rebooting (00:48): GPU at `auto`,
  `ppfeaturemask` `0xfff7bfff`, no new error, and TDP and profiles working (checked by the
  user: they do not depend on `[gpu_performance]`). The same day **they were brought back**: the installer again
  leaves the profile as it comes (except `[gpu_power_profile]`) and `gpu-overdrive.sh` is applied again.
  On the already installed Legion, with `sudo sh /tmp/legion-gpu-manual.sh` (run by the user; it adds
  `[gpu_performance]` in its original place if missing, runs `/tmp/gpu-overdrive.sh` and restarts
  `steamos-manager`) and rebooting. **Verified on 2026-10-08, already with the patch** (below).
- **Wi-Fi power saving: Steam asks for it.** Here it broke SSH (steps 2–3). In Game Mode:
  **Ajustes → Sistema → "Activar modo desarrollador"** (Settings → System → "Enable Developer Mode"), and on the new page **"Desarrollador"** ("Developer"),
  **turn off "Habilitar administración de energía para Wi-Fi"** ("Enable Wi-Fi Power Management") (texts of
  `steamui_latam-json.js`: `Settings_System_EnableDeveloperMode`, `Settings_Developer_WifiPowersave`).
  The "Desarrollador" page does not exist without developer mode, nor in the desktop's Big Picture.
- **Remaining noise:** `SetWifiBackend … Wi-Fi backend not found in config` every time Steam
  starts (it asks to set the Wi-Fi engine and steamos-manager only knows how to do it with systemd: it does not touch
  NetworkManager, which is what we want), and warnings from `org.freedesktop.systemd1`. **Do not "fix it"
  by creating `99-valve-wifi-backend.conf`** (Troubleshooting, *Known noise in the logs*).
- **Check:** `sudo sv status steamos-manager` → `run`; in Game Mode, `pgrep -a -f
  '^/usr/lib/steamos-manager'` → the two processes; `cat /sys/module/amdgpu/parameters/ppfeaturemask`
  → `0xfff7ffff` (overdrive); `grep -c '^\[gpu_performance\]'
  /usr/share/steamos-manager/devices/legion-go-series.toml` → `1`; `cat
  /sys/class/drm/card*/device/power_dpm_force_performance_level` → `auto` (`manual` only with "Reloj de
  GPU manual" ("Manual GPU Clock") enabled in Steam); `sha256sum /usr/lib/steamos-manager` → `cc464424…1586c` (with the
  patch); with the manual clock disabled, `grep -c 'Error setting manual GPU clock'
  /var/log/steamos-manager/current` does not grow after entering Game Mode; `iw dev wlp193s0 get
  power_save` → `off`.
- **Verified on 2026-10-04** in Game Mode: power profiles (the power button's LED
  changes color with each one: it is Lenovo's firmware), TDP limit (`ppt_pl1_spl` following
  Steam) and manual clock at 2900 MHz (`power_dpm_force_performance_level` = `manual`, `OD_SCLK`
  2900/2900, `freq1_input` = 2900 MHz; removed and brought back on 2026-10-08, above); Wi-Fi `off` with Steam's setting disabled.
  **InputPlumber in Game Mode: all the buttons** (Steam's button test).
- **`set_clocks` patch and manual clock brought back: verified on 2026-10-08** (after `sudo sh
  /tmp/instalar-steamos-manager-parche.sh` and rebooting at 01:28): `sha256sum /usr/lib/steamos-manager`
  = `cc464424…1586c`; with the manual clock **disabled**, Steam still sends `enabled: 0` / `hz: 2900`
  (01:28:48, 01:29:48, 01:31:48) and **no new `Error setting manual GPU clock`** (the counter
  stayed at 185, the last one at 01:10, before the patch); **enabled at 2000 MHz** (01:30:32): level
  `manual`, `OD_SCLK` 2000/2000 and `pp_dpm_sclk` at 2000\*; **disabled** (01:31:25): back to
  `auto`. Steam sends first `enabled` and then `hz` (`steamui_steamos.txt`). Checked again, without
  root, at the boot of 20:45 (with Game Mode used): sha256 the same, counter at 185 (the last one,
  `2026-10-08_07:10` UTC = 01:10), `ppfeaturemask` `0xfff7ffff`, `[gpu_performance]` present and level
  `auto`.

