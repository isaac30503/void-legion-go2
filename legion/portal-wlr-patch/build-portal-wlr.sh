#!/bin/bash
# Builds Void's xdg-desktop-portal-wlr package with the patches of this folder (0001: also restore
# windows; 0002: reuse the source of a restored session that was closed without starting, when
# changing streams in Vesktop; 0003: pass the exact request and the app to the chooser, in
# XDPW_REQUEST_HANDLE and XDPW_APP_ID) and one revision more than the official one (Legion recipe, step 14,
# "Desktop portals and screen sharing"). Without root: xbps-src builds in its own isolated
# environment. Same scheme as common/steam/gamescope-patch/build-gamescope.sh.
# Previous (Spanish) name: compilar-portal-wlr.sh (folder portal-wlr-parche/).
#   bash legion/portal-wlr-patch/build-portal-wlr.sh     # leaves the package in ~/src/void-packages/hostdir/binpkgs
# Install (root), restart the portal (without root) and clean up:
#   sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs xdg-desktop-portal-wlr
#   (if that same revision is already installed, with -f: sudo xbps-install -f -R …; and restart the session
#   or the machine: the first time, restarting only the portal was not enough)
#   pkill -u "$USER" -f '^/usr/libexec/xdg-desktop-portal-wlr'     # D-Bus relaunches it (it cuts a stream)
#   rm -rf ~/src/void-packages
# update-system warns if the installed one stops being the one built here (a Void update
# replaces it: repeat this script). If the patch no longer applies, xbps-src stops at "patching".
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
D="$(dirname "$(readlink -f "$0")")"
PATCHES=("$D"/0*.patch)
# Is the patch still needed? Common test (2026-10-09; common/patch-test/patch-still-needed.sh or, if the
# script runs outside the repository, ~/.local/bin/patch-still-needed): ALREADY_INCLUDED → it does not build (Void's
# code already has it); CONFLICT, PARTIAL or UNCHECKED → it stops (review the patch / no network).
TEST="$REPO_ROOT/common/patch-test/patch-still-needed.sh"
[ -f "$TEST" ] || TEST=$(command -v patch-still-needed) || { t "!! patch-still-needed is missing (common/patch-test/ or ~/.local/bin)"; exit 1; }
RES=$(bash "$TEST" void xdg-desktop-portal-wlr "${PATCHES[@]}")
echo "$RES"
case "$(sed -n 's/^RESULT [^ ]* [^ ]* \([A-Z_]*\).*/\1/p' <<<"$RES")" in
    STILL_NEEDED) ;;
    ALREADY_INCLUDED) t "The code already has the patch: no need to build (you can go back to Void's)."; exit 0 ;;
    *) t "!! Not building: review the result above."; exit 1 ;;
esac
mkdir -p ~/src && cd ~/src
[ -d void-packages ] || git clone --depth=1 https://github.com/void-linux/void-packages.git void-packages
cd void-packages
git checkout -- srcpkgs/xdg-desktop-portal-wlr 2>/dev/null || true
T=srcpkgs/xdg-desktop-portal-wlr/template
REV=$(sed -n 's/^revision=//p' "$T")
t "Void template: %s_%s → built with revision=%s" "$(sed -n 's/^version=//p' "$T")" "$REV" "$((REV+1))"
mkdir -p srcpkgs/xdg-desktop-portal-wlr/patches
cp "${PATCHES[@]}" srcpkgs/xdg-desktop-portal-wlr/patches/
ls srcpkgs/xdg-desktop-portal-wlr/patches/
sed -i "s/^revision=$REV\$/revision=$((REV+1))/" "$T"
printf '%s\n' "XBPS_MAKEJOBS=$(nproc)" > etc/conf
[ -d masterdir-x86_64 ] || [ -d masterdir ] || ./xbps-src binary-bootstrap
./xbps-src pkg xdg-desktop-portal-wlr
ls -l hostdir/binpkgs/xdg-desktop-portal-wlr-*.xbps
