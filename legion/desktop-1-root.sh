#!/bin/bash
# X11 desktop on the Legion, root part (docs/5-desktop/1-xfce.md).
# Previous (Spanish) name: escritorio-1-root.sh.
#   sudo bash legion/desktop-1-root.sh        log: ~/desktop-1-root.log
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
exec > >(tee -a "$TARGET_HOME/desktop-1-root.log") 2>&1
t "=== %s start" "$(date)"
t "--- .new-* of /etc (templates; the good one is the current one)"
rm -v /etc/*.new-* /etc/default/*.new-* 2>/dev/null || true
t "--- packages"
xbps-install -Sy fish-shell fzf ntfs-3g curl git ripgrep xdg-utils \
  xterm xrdb xprop xdotool librsvg-utils ImageMagick fastfetch \
  xfce4-docklike-plugin xfce4-clipman-plugin papirus-icon-theme papirus-folders \
  sassc gtk-engine-murrine xfce4-screensaver xfce4-screenshooter btop blueman \
  adwaita-fonts twemoji noto-fonts-ttf libspa-bluetooth wl-clipboard \
  xrandr     # per-monitor windows (docs/5-desktop/3-windows-and-shortcuts.md); added after the installation of 2026-10-03
t "--- Papirus-Dark with teal folders"
papirus-folders -C teal --theme Papirus-Dark
readlink /usr/share/icons/Papirus-Dark/48x48/places/folder.svg
t "--- Bluetooth"
ln -sf /etc/sv/bluetoothd /var/service/
# (without waiting for it to start: runit does not notify; it is checked at the end, "Verification")
rfkill
t "=== %s DONE OK" "$(date)"
