# Hardware

| | |
|---|---|
| Device | Lenovo Legion Go 2, `83N0` (fastfetch: "Legion Go 8ASP2"); BIOS `RRCN16WW` |
| CPU / GPU | AMD Ryzen Z2 Extreme (6+10 cores, 16 threads) / Radeon 890M (`gfx1150`) |
| RAM | 32 GB: 21 GB for the system, **10 GB reserved for the GPU** |
| Internal disk | SK Hynix `HFS001TEM4X182N`, 1 TB NVMe (`nvme0n1`) |
| Screen | Samsung `SDC 4301`, 1920×1200 at 144 Hz, 8.8", landscape (comes out upright on its own) |
| Wi-Fi / Bluetooth | MediaTek MT7922 (`mt7921e`) / `hci0` of the same chip |
| Sound | Realtek ALC257 + ACP coprocessor (`snd_acp_pci`, SOF) |
| microSD | `mmcblk0p1`, 953 GB **ext4**: the Steam library, mounted at **`/mnt/microsd`** ([storage](../2-base-system/3-storage.md)) |
| Keyboard | **US international** (`us` + `intl`, dead keys) |

**External monitor:** a 27" MSI (1920×1080) to the left of the Legion's screen (x = 1920); the panels are on
the monitor. Output names: X11 `DisplayPort-0` and `eDP`; Wayland (labwc) and gamescope `DP-1` and `eDP-1`.
Scale **1× (96 DPI)** (on X11 the DPI is one for both screens).

**What Void's own kernel (6.18) handles without anything extra:** screen, Wi-Fi (5 GHz, Wi-Fi 6), Bluetooth,
speakers, battery, `platform_profile` (`low-power`/`balanced`/`performance`), the controllers (`xpad`) and the
gyroscope/accelerometer (`amd_sfh`). What needs this repository: the controllers as a Valve controller
([InputPlumber](../3-hardware-support/1-controllers.md)) and the fine TDP
([`lenovo-wmi-*` via DKMS](../3-hardware-support/2-power.md)).
