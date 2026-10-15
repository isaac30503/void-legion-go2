### Hibernation and brightness on wake (2026-10-04)

**It works without configuring anything else:** 32 GB swap (`nvme0n1p2`) and **`/sys/power/resume` =
`259:2`** (= `nvme0n1p2`), set by dracut's initramfs (`resume=UUID=@LEGION_SWAP_UUID@`; the kernel
line does not carry it); `/sys/power/disk` = `platform`, lockdown `none`. From the session:

```bash
loginctl hibernate        # powers off completely; on power-on (hidden GRUB) it restores the session
```

- **Check that it restored and did not boot anew:** `uptime -s` gives the same time as before (the
  `uptime` does not count the time hibernated). Over SSH, `loginctl` answers `challenge` (it is not the
  active session); from the session, without password.
- **Verified on 2026-10-04, twice** (22:5x and 23:09; boot 22:46:26 in both): session with
  its windows, Wi-Fi with `Power save: off`, Wayland (`wayland-0`), InputPlumber adds the
  controller again by itself (a stray `Failed running device evdev://event2` and right away `Found missing input
  device`), `extest`, Steam in the background and the overdrive; whole controller (user). Without `Common`
  or another NTFS mounted (mounted, hibernating risks the volume).
- **The built-in screen's brightness changed:** at 100 % before, ~32 % (151040/472000) after.
  Writing the same value again did not fix it (`brightness` stayed at 151040; amdgpu's
  `actual_brightness` goes on another scale and is no use to compare it); it was the value that
  was lost. **elogind hook** (`brightness-on-wake.sh`, in `legion/`; `--remove`):
  `/etc/elogind/system-sleep/brightness` (the folder that elogind reads on Void, next to
  `/usr/libexec/elogind/system-sleep/`) saves the brightness of each screen in `pre` (in
  `/run/brightness-before-sleep`: it is memory and travels in the image) and puts it back in `post`, for
  hibernating and suspending. Log: `/run/brightness-on-wake.log`. **Verified on 2026-10-04:**
  `23:09:15 hibernate: brillo repuesto (amdgpu_bl0 472000)` (brightness restored), brightness 472000/472000.

```bash
sudo sh "$B/legion/brightness-on-wake.sh"
```

