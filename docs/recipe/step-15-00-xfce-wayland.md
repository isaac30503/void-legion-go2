## 15. Xfce on Wayland (labwc) (2026-10-03)

**It is installed before the first boot into Game Mode:** `install-passwordless-switch.sh`
makes "Cambiar a escritorio" ("Switch to Desktop") go to `xfce-wayland`, and without labwc that session does not start (you
would be left without a desktop). `sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"` (the folder
`common/xfce-wayland/` copied to `~`). **labwc's keyboard now comes from `00-keyboard.conf`**
(`XKB_DEFAULT_LAYOUT=us` + `XKB_DEFAULT_VARIANT=intl` here; on the IdeaPad, `latam` and the file
the same as before, checked). **Firefox and Steam with only labwc's border** (`SetDecorations
border forceSSD`; in Firefox, "Barra de título" ("Title Bar") unchecked): detail in step 15 of the IdeaPad.
**Verified:** Game Mode's "Cambiar a escritorio" enters Xfce Wayland (labwc 0.20.2).

