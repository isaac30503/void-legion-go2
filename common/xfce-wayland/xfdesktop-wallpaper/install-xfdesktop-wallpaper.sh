#!/bin/bash
# Installs the patched xfdesktop (wallpaper dialog on Wayland; see build-xfdesktop.sh) from the .xbps
# of this folder, with a temporary local repository (a path with a space, like Common's, is not
# accepted by xbps as a repository). ROOT: sudo bash common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh
# docs/5-desktop/4-wallpaper.md. It does not touch the wallpaper configuration
# (xfconf) or restart anything: after installing, close and open the wallpaper dialog again.
# Going back (Void's, without the patch): nothing needs to be touched; when Void publishes xfdesktop
#   >= 4.20.3 (or a revision higher than this one), void-update replaces it and that one already has the fix.
#   Downgrading by hand to Void's before that is not tested. (Since 2026-10-09 void-update tests the patch
#   against Void's code instead of assuming a version, and when Void already has it, it gives the command
#   sudo xbps-install -Sf xfdesktop: docs/5-desktop/4-wallpaper.md.)
# Previous (Spanish) name: instalar-xfdesktop-fondo.sh. The .xbps comes from the GitHub Release
# (install/fetch-assets.sh puts it next to this script).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
D="$(dirname "$(readlink -f "$0")")"
mapfile -t PKGS < <(ls "$D"/xfdesktop-*.x86_64.xbps 2>/dev/null | sort -V)
[ "${#PKGS[@]}" -gt 0 ] || { t "there is no xfdesktop-*.x86_64.xbps in %s (build-xfdesktop.sh or install/fetch-assets.sh)" "$D"; exit 1; }
PKG=${PKGS[-1]}
VER=$(basename "$PKG" .x86_64.xbps)
t "package: %s   installed now: %s" "$VER" "$(xbps-query -p pkgver xfdesktop)"
xbps-query -p pkgver libxfce4windowing
LW=$(xbps-query -p pkgver libxfce4windowing); LW=${LW#libxfce4windowing-}
if xbps-uhelper cmpver "$LW" 4.20.6; [ $? = 255 ]; then
    t "!! the patch needs libxfce4windowing >= 4.20.6 (there is %s): update first (void-update)" "$LW"; exit 1
fi
REPO=$(mktemp -d /tmp/xfdesktop-repo.XXXXXX)
trap 'rm -rf "${REPO:?}"' EXIT
cp "$PKG" "$REPO/"
xbps-rindex -a "$REPO"/*.xbps
xbps-install -R "$REPO" "$VER"     # asks to confirm
echo
t "== check"
xbps-query -p pkgver xfdesktop
xbps-query -p repository xfdesktop
if [ "$(xbps-query -p pkgver xfdesktop)" = "$VER" ]; then t "OK: installed %s" "$VER"
else t "!! %s was not left installed" "$VER"; exit 1; fi
echo
t "Now, in the Xfce Wayland session: close the wallpaper dialog if it was open, open in a terminal"
t "  xfconf-query -c xfce4-desktop -m      (it watches the changes)"
t "open the dialog (right click on the desktop → Desktop Settings) on the screen you"
t "want and choose a wallpaper: /backdrop/screen0/monitor<connector>/workspace<N>/last-image must show up with the"
t "connector of THAT screen (eDP-1 on the IdeaPad; on the Legion, that of the screen where the dialog is),"
t "not monitorUnknown, and the wallpaper must change instantly."
