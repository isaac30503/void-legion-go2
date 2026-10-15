# Remote Play in Game Mode

Steam's Remote Play (Together) from Game Mode captures gamescope's image through PipeWire and encodes it on the GPU.
**Steam's client is 32-bit**, so it needs PipeWire's 32-bit modules and VA-API:

```bash
sudo xbps-install -S pipewire-32bit libspa-videoconvert-32bit mesa-vaapi-32bit mesa-vaapi
```

`install-steam.sh` already installs them (`pipewire-32bit` and `libspa-videoconvert-32bit` always; `mesa-vaapi` and
`mesa-vaapi-32bit` with an AMD GPU). After installing them by hand: leave Game Mode and come back (Steam loads the
modules on start).

**Check** in `~/.local/share/Steam/logs/streaming_log.txt` during a stream:
`Capture method set to Desktop PipeWire NV12 DMABUF + VAAPI H264` (gamescope's image without copies, encoded by the
GPU). Short jumps to `Desktop Placeholder` while Steam's menu has the focus are the "host busy" notice, not a failure.

**Problem — the guest only sees Steam's waiting screen** ("La entrada está temporalmente desactivada mientras el host
está ocupado" / "Input is temporarily disabled while the host is busy"), in the same log:

- `Failed to create PipeWire main loop` → `pipewire-32bit` missing (`/usr/lib32/spa-0.2/` does not exist);
- `Could not connect receiving stream` → `libspa-videoconvert-32bit` missing;
- `Desktop Placeholder` all the time → one of the two;
- `libva: … /usr/lib32/dri/radeonsi_drv_video.so` → `va_openDriver() returns -1` → `mesa-vaapi-32bit` missing (it falls
  back to x264 on the CPU).
