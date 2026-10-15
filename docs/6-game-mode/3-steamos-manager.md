# steamos-manager: Performance from Steam

Valve's service through which Steam's **Rendimiento** (Performance) menu sets the **TDP**, the **power profiles**
and the **manual GPU clock**. The Go 2 has an official profile (`/usr/share/steamos-manager/devices/
legion-go-series.toml`: `83N0`/`83N1` → `legion_go_2`): TDP through `lenovo-wmi-other-0` (profile `custom`),
profiles through `lenovo-wmi-gamezone`, GPU level and clock through `amdgpu` (`[gpu_performance]`), and InputPlumber
targets `deck-uhid, keyboard, mouse`. It needs the [TDP modules and the overdrive](../3-hardware-support/2-power.md).
Binary **v26.4.1 with our patch** (`set_clocks`, below), built here.

## Install

```bash
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"   # --remove undoes it
sudo xbps-pkgdb -m manual speech-dispatcher
```

The tarball (`steamos-manager-v26.4.1-void-2.tar.gz`) comes from the Release; `…-void.tar.gz` is the official one
without the patch (to go back: change `TAR` in the installer to it).

- **Two processes, as on SteamOS:** the **root** one (`steamos-manager -r`, system bus) is the runit service
  **`steamos-manager`** (log `/var/log/steamos-manager/current`); the **user** one (session bus: Steam talks to it)
  is started by the Game Mode launcher if `/usr/lib/steamos-manager` exists. Not on the desktop: Performance belongs to
  Game Mode.
- The installer (`xbps-install` of `speech-dispatcher` and `glib` if missing) copies the `make install` tree
  **without** systemd units, sddm settings or D-Bus activation files, with a list in
  `/usr/local/share/steamos-manager-void/manifest` (for `--remove`); removes `[gpu_power_profile]` when amdgpu has no
  `pp_power_profile_mode` (this GPU: Steam then does not show the option); reloads D-Bus; and records what
  `void-update` checks: `sha256` (of `/usr/lib/steamos-manager` and `/usr/bin/steamosctl`) and `package` (e.g.
  `steamos-manager-v26.4.1-void-2`).
- **It needs `tracefs`**, which Void does not mount (without it, it exits with `No such file or directory` after
  "Starting SLS log receiver"): its `run` mounts it.
- **`speech-dispatcher` as manual:** it provides `libspeechd`, which the binary needs; xbps does not know it (the
  binary is not a package), so marking it manual keeps an `xbps-remove -R` of something else from taking it.
- **Steam's "Reloj de GPU manual" ("Manual GPU Clock") needs the overdrive** (`ppfeaturemask`); verified at 2900 MHz.

## The `set_clocks` patch

Steam resends the saved GPU clock many times per session, also with the manual clock **off**, and steamos-manager
26.4.1 writes it to `pp_od_clk_voltage` at any level; this GPU's SMU 14 only accepts it in `manual`, so the log
filled with `Error setting manual GPU clock: Invalid argument` (hundreds per session, harmless). The patch
(`0001-gpu-set_clocks-only-in-manual.patch`, in `AmdgpuPerformanceLevelDriver::set_clocks`) writes nothing unless the
level is `manual` (nothing is lost: the driver rejected it anyway). Steam sets `manual` before sending the clock. (The
Steam Deck's own APU accepts the clock at any level, which is why SteamOS does not need this.) Removing
`[gpu_performance]` would silence it too but lose the manual clock: **do not**.

**Build it** (without root, ~1 min 30 s; the build dependencies are kept installed on purpose, `void-update` updates
them):

```bash
sudo xbps-install -S glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config   # plus git, make and rustup's Rust (~/.cargo/bin)
bash "$B/common/steam/steamos-manager/build-steamos-manager.sh" /tmp
```

It **tests the patch first** against the tag (does not build if already included, stops on conflict), clones
`v26.4.1` (commit `a0d399d`), applies the patches, `make build`, `make test` inside `dbus-run-session` (248 of 248),
`make install DESTDIR=…`, and packs `/tmp/steamos-manager-v26.4.1-void-2.tar.gz` (owner `root`), checking `ldd`,
`steamosctl --version` and that the file list matches the official tarball's; then deletes `~/src/steamos-manager`.
The binary is reproducible: sha256 `cc464424…1586c` in two builds. To remove the build dependencies one day:
`sudo xbps-remove -R glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config` (`-Rn` lists first).
`void-update` also watches upstream's latest tag and tests the patch against it.

## Check

```bash
sudo sv status steamos-manager                         # run
pgrep -a -f '^/usr/lib/steamos-manager'                # in Game Mode: two processes
sha256sum /usr/lib/steamos-manager                     # cc464424…1586c (the patched one)
grep -c '^\[gpu_performance\]' /usr/share/steamos-manager/devices/legion-go-series.toml   # 1
```

In Game Mode: the power profiles change (the power button's LED changes color with each one: Lenovo's firmware),
`ppt_pl1_spl` follows Steam's TDP, and with the manual clock on, `power_dpm_force_performance_level` = `manual` and
`OD_SCLK` at the chosen clock; with it off, `grep -c 'Error setting manual GPU clock' /var/log/steamos-manager/current`
does not grow.

## Problems

**No "Rendimiento" (Performance) or nothing changes:**

1. `sudo sv status steamos-manager` → `run`; if it crashes, `sudo sh "$B/common/steam/steamos-manager/diag-steamos-manager.sh"`
   runs it in the foreground with `RUST_LOG=debug`.
2. `dkms status` → `installed` for the running kernel (another series has no modules: boot 6.18).
3. Manual-clock errors with the clock **off**: not the patched binary (sha256 above): run the installer again.
   With it **on**, or no "Reloj de GPU manual": `cat /sys/module/amdgpu/parameters/ppfeaturemask` → `0xfff7ffff`
   (otherwise the overdrive) and `[gpu_performance]` present (otherwise the installer again).

**Harmless in its log:** `SetWifiBackend … Wi-Fi backend not found in config` every time Steam starts — **do not
create `/etc/NetworkManager/conf.d/99-valve-wifi-backend.conf` to silence it**: steamos-manager would try to switch
to iwd (not used here) and the Wi-Fi would break after a reboot; warnings about `org.freedesktop.systemd1` (no systemd
here); `Can't query initial InputPlumber devices: … ServiceUnknown` (it starts before InputPlumber is on D-Bus; the
controller works); a `task … panicked … all branches are disabled` at power-off (it loses InputPlumber at the same
second); `WARN Can't add GpuPowerProfile1 interface` (expected without the GPU power profile).
