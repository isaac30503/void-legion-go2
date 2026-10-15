#!/bin/bash
# Installs the patched Thunar ("Set as wallpaper" on Wayland; see build-thunar.sh) from
# the Thunar-*.xbps of this folder, with a temporary local repository (a path with a space, like Common's,
# is not accepted by xbps as a repository). Only Thunar: the wallpaper plugin goes in it; Thunar-devel (next
# to it, just in case) is not needed. ROOT: sudo bash common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh
# docs/5-desktop/4-wallpaper.md. It does not touch the wallpaper configuration.
# Afterwards, AS THE USER: thunar -q (closes Thunar, which has the old plugin loaded) and open it again.
# Going back (Void's, without the patch): when Void publishes a higher revision, void-update
#   replaces it and warns. Downgrading by hand to Void's before that is not tested.
# Previous (Spanish) name: instalar-thunar-fondo.sh. The .xbps comes from the GitHub Release
# (install/fetch-assets.sh puts it next to this script).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
D="$(dirname "$(readlink -f "$0")")"
mapfile -t PKGS < <(ls "$D"/Thunar-[0-9]*.x86_64.xbps 2>/dev/null | sort -V)
[ "${#PKGS[@]}" -gt 0 ] || { t "there is no Thunar-*.x86_64.xbps in %s (build-thunar.sh or install/fetch-assets.sh)" "$D"; exit 1; }
PKG=${PKGS[-1]}
VER=$(basename "$PKG" .x86_64.xbps)
t "package: %s   installed now: %s" "$VER" "$(xbps-query -p pkgver Thunar)"
LW=$(xbps-query -p pkgver libxfce4windowing); LW=${LW#libxfce4windowing-}
if xbps-uhelper cmpver "$LW" 4.20.6; [ $? = 255 ]; then
    t "!! the patch needs libxfce4windowing >= 4.20.6 (there is %s): update first (void-update)" "$LW"; exit 1
fi
REPO=$(mktemp -d /tmp/thunar-repo.XXXXXX)
trap 'rm -rf "$REPO"' EXIT
cp "$PKG" "$REPO/"
xbps-rindex -a "$REPO"/*.xbps
xbps-install -R "$REPO" "$VER"     # asks to confirm
echo
t "== check"
xbps-query -p pkgver Thunar
xbps-query -p repository Thunar
[ "$(xbps-query -p pkgver Thunar)" = "$VER" ] || { t "!! %s was not left installed" "$VER"; exit 1; }
LDD=$(ldd /usr/lib/thunarx-3/thunar-wallpaper-plugin.so)
grep -q 'libxfce4windowing-0.so.0 => /' <<<"$LDD" && t "OK: installed %s (the wallpaper plugin uses libxfce4windowing)" "$VER" \
    || { t "!! the wallpaper plugin does not link libxfce4windowing"; exit 1; }
echo
t "Now, AS THE USER (without sudo): thunar -q ; then, in Xfce Wayland, in an xterm:"
t "  xfconf-query -c xfce4-desktop -m      (it watches the changes)"
t "open Thunar on the screen you want, right click on an image → Set as wallpaper:"
t "/backdrop/screen0/monitor<connector>/workspace<N>/last-image must show up with the connector of the screen"
t "where Thunar's window is (eDP-1 on the IdeaPad; eDP-1 or DP-1 on the Legion), not monitorUnknown,"
t "and the wallpaper must change instantly. (It also keeps writing monitor0/image-path: it is xfdesktop's"
t "old format, harmless.)"
