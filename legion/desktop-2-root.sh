#!/bin/bash
# X11 desktop on the Legion, root part 2: login screen the same as the session (docs/5-desktop/2-look-and-feel.md).
# Previous (Spanish) name: escritorio-2-root.sh.
#   sudo bash legion/desktop-2-root.sh        log: ~/desktop-2-root.log
# Needs the user part first (the block of docs/5-desktop/1-xfce.md) (Orchis in ~/.themes, Volantes and the Blocks font in ~).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
H=$TARGET_HOME
exec > >(tee -a "$H/desktop-2-root.log") 2>&1
X="$REPO_ROOT/common/xfce"
t "=== %s start" "$(date)"
cp -r "$H/.themes/Orchis-Teal-Dark-Compact" /usr/share/themes/
cp -r "$H/.local/share/icons/volantes_cursors" /usr/share/icons/
mkdir -p /usr/local/share/fonts/jetbrains-blocks
cp "$H/.local/share/fonts/jetbrains-blocks/"*.ttf /usr/local/share/fonts/jetbrains-blocks/
fc-cache -f /usr/local/share/fonts/jetbrains-blocks
[ -e /etc/lightdm/lightdm-gtk-greeter.conf.bak ] || cp /etc/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf.bak
cp "$X/lightdm-gtk-greeter.conf" /etc/lightdm/
sudo -u lightdm mkdir -p /var/lib/lightdm/.config/gtk-3.0
install -o lightdm -g lightdm -m 644 "$X/lightdm-gtk.css" /var/lib/lightdm/.config/gtk-3.0/gtk.css   # root reads the clone; lightdm may not
t "--- check"
HOME=/nonexistent fc-match "JetBrainsMono NFM Blocks:bold"
cat /etc/lightdm/lightdm-gtk-greeter.conf
t "=== %s DONE OK" "$(date)"
