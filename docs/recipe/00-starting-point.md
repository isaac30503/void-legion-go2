## Starting point

| | |
|---|---|
| Device | Legion Go 2, `83N0` (fastfetch: "Legion Go 8ASP2"); BIOS `RRCN16WW` |
| CPU / GPU | AMD Ryzen Z2 Extreme (6+10 cores, 16 threads) / Radeon 890M (`gfx1150`) |
| RAM | 32 GB physical: 21 GB for the system, **10 GB reserved for the GPU** |
| Internal disk | SK Hynix `HFS001TEM4X182N`, 1 TB NVMe (`nvme0n1`) |
| Screen | Samsung `SDC 4301`, **1920×1200 at 144 Hz, 8.8", landscape from the factory** (comes out upright on its own) |
| Wi-Fi / Bluetooth | MediaTek MT7922 (`mt7921e`) / `hci0` of the same chip |
| Sound | Realtek ALC257 + ACP coprocessor (`snd_acp_pci`, SOF) |
| microSD | `mmcblk0p1`, 953 GB **ext4**, from the SteamOS days: its **Steam library** and emulator games; always mounted at **`/mnt/microsd`** (step 14, "microSD") |
| Keyboard | **US international** (`us` + `intl`, with dead keys), not `latam` like the IdeaPad |

It is used with an **external 27" monitor** (MSI, 1920×1080) to the left of the Legion's screen
(x = 1920): the desktop (panels) is on the monitor. Output names: on X11 `DisplayPort-0` and
`eDP`; on Wayland (labwc, the normal session) and in gamescope, `DP-1` and `eDP-1`. Scale **1×
(96 DPI)**, the user's decision (2026-10-03): on X11 the DPI is a single one for both screens.

