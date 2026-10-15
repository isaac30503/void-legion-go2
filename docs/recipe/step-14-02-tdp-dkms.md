### Fine TDP: `lenovo-wmi-*` modules via DKMS (2026-10-04)

`lenovo-wmi-gamezone` and `lenovo-wmi-other` (with `-helpers`, `-events` and `-capdata01`) **are in the
normal 6.18 but Void does not enable them** (`CONFIG_LENOVO_WMI_GAMEZONE`/`_TUNING`). They give the profile
**`custom`** and the power limits in `/sys/class/firmware-attributes/lenovo-wmi-other-0`,
which is what `steamos-manager` uses. No own kernel: a DKMS package with the sources of 6.18.55.

```bash
cp -r "$B/legion/tdp" ~/
sudo bash "$B/legion/tdp/install-tdp.sh"               # remove: --remove
```

- **Sources:** `drivers/platform/x86/lenovo/wmi-*.{c,h}` and `firmware_attributes_class.h` of the
  stable **v6.18.55** (`git.kernel.org`, `plain/…?h=v6.18.55`), **unchanged**, in
  `tdp/lenovo-wmi-tdp/` with a `Kbuild` (the same module names as the kernel) and its
  `dkms.conf` (`BUILD_EXCLUSIVE_KERNEL="^6\.18\."`, `AUTOINSTALL`, destination `/updates`).
- **What it does:** `xbps-install dkms linux6.18-headers`; copies to `/usr/src/lenovo-wmi-tdp-6.18.55`;
  `dkms install`; `modprobe`. At boot they load by themselves (they go by the firmware's WMI GUIDs) and
  DKMS rebuilds them when another 6.18 is installed (hook in `/etc/kernel.d/`). **With a 6.19 they are not
  built** (on purpose): its new sources will have to be brought or check whether Void already enables them.
- **Updates** (2026-10-04): within 6.18, `void-update` installs the new kernel and the
  hook `/etc/kernel.d/post-install/10-dkms` rebuilds the modules by itself (the headers
  `linux6.18-headers` are updated in the same transaction); when deleting old kernels,
  `pre-remove/10-dkms` removes them. **The risk was the series change**: the `linux` metapackage
  (installed) would bring `linux6.19` when Void changes series, the hidden GRUB would boot the
  newest and there there are no modules (on purpose, `BUILD_EXCLUSIVE_KERNEL`). As **6.18 is LTS** and
  Void maintains its LTS (`linux6.1`, `6.6`, `6.12` are still there), **the metapackages are held**:

  ```bash
  sudo xbps-pkgdb -m hold linux linux-headers   # linux6.18 keeps updating; it does not jump series
  xbps-query -H                                 # linux-6.18_1, linux-headers-6.18_1
  # moving to another series, on purpose: sudo xbps-pkgdb -m unhold linux linux-headers (and bring the
  # lenovo-wmi-* sources of that series, or check whether Void already enables them)
  ```

  **Held on 2026-10-04**; that day `void-update` ended with the 9 checks OK
  ("✓ Todo en orden" / "✓ All in order": TDP for 6.18.55_1, kernel held, 6.18 series = the recommended one,
  gamescope, libraries of InputPlumber/`steamos-manager`/`extest`, no `.new-*`, no reboot).
  Also, **the summary of `void-update`** (step 6 of the IdeaPad recipe) checks that the
  module is built for the newest kernel (if it is 6.18.x and missing, it rebuilds it), warns if
  the metapackages are not held and **warns when Void recommends another series** (compares the
  repository's `linux` with the installed one): that way you know when to consider the change.
- **The Go 2 is foreseen in the driver:** DMI `Legion Go 8ASP2` in its `fwbug_list`.
- **Check:** `dkms status` → `installed`; `cat /sys/class/platform-profile/*/{name,choices}` →
  `lenovo-wmi-gamezone` with `low-power balanced performance custom` (the other one is `amd-pmf`, with 3);
  in `…/lenovo-wmi-other-0/attributes/`: `ppt_pl1_spl` 5–35 W, `ppt_pl2_sppt` 5–37 W,
  `ppt_pl3_fppt` 5–45 W (factory values: the maximum). The limits only apply with the profile
  `custom`. The usual `/sys/firmware/acpi/platform_profile` says `custom` when the two
  drivers do not match: it is not an error.
- **Verified on 2026-10-04** (built on the first try, 6.18.55_1).

