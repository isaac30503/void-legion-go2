### Remote Play (Remote Play Together) in Game Mode: 32-bit PipeWire and VA-API (2026-10-07)

**Symptom:** from the desktop it worked; from Game Mode, the guest only saw **Steam's waiting
screen** (diamond background) and "La entrada está temporalmente desactivada mientras el host está
ocupado" ("Input is temporarily disabled while the host is busy"). Diagnosis in `~/.local/share/Steam/logs/streaming_log.txt`, in three steps:

1. `CDesktopCapturePipeWire: Failed to create PipeWire main loop` when the stream starts (it also shows
   on the desktop, where Steam captures in another way; in gamescope it depends on PipeWire). **Steam's
   client is 32-bit** and there was `libpipewire-32bit` but not its modules: `/usr/lib32/spa-0.2/` did not exist
   (`support/libspa-support.so`). They come with **`pipewire-32bit`**.
2. With that: `PipeWire stream state changed to connecting` → `Could not connect receiving stream` (the
   `gamescope` node did exist, `Video/Source`, in the same PipeWire) and `Capture method set to Desktop
   Placeholder` (the waiting screen). **`libspa-videoconvert-32bit`** was missing (the 64-bit one was there).
   Also the hardware encoder did not load (`libva: Trying to open
   /usr/lib32/dri/radeonsi_drv_video.so` → `va_openDriver() returns -1`; it fell back to x264 on the CPU):
   **`mesa-vaapi-32bit`** was missing. And not even the 64-bit **`mesa-vaapi`** was there (no hardware video
   decoding in any program; SteamOS ships it).
3. With everything: **`Capture method set to Desktop PipeWire NV12 DMABUF + VAAPI H264`** (gamescope's direct image
   through PipeWire, without copies, and encoded by the GPU). The occasional jumps to `Desktop
   Placeholder` while Steam's menu has the focus are the "host busy" notice, not failures.

```bash
sudo xbps-install -S pipewire-32bit libspa-videoconvert-32bit mesa-vaapi-32bit mesa-vaapi
# leave Game Mode and come back (Steam loads the modules on start)
```

**`install-steam.sh` (common) installs them since 2026-10-07:** `pipewire-32bit` and
`libspa-videoconvert-32bit` always; `mesa-vaapi` and `mesa-vaapi-32bit` only with an AMD GPU (on Intel it does not
install VA-API: on the IdeaPad, HD 5500, `intel-media-driver` works, iHD driver 26.3.5, verified with
`vainfo` on 2026-10-09; it is installed by `ideapad-al-dia.sh --video`). On this Legion they were installed by hand, so they are not in
`legion/steam/installed-packages.txt` (its `--remove` does not remove them). **Verified by the user**
(2026-10-07, Nuclear Throne with a guest): the stream loads and you can play. In the log: it starts at
22:48:17 (`Streaming started`), a few seconds alternating with `Desktop Placeholder` while Steam's menu
had the focus, and from 22:48:25 `Desktop PipeWire NV12 DMABUF + VAAPI H264` continuously until
the end (22:55:58, where a last `Desktop Placeholder` shows when the stream closes: it is normal).

