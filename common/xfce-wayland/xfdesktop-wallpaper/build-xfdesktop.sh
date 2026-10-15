#!/bin/bash
# Builds Void's xfdesktop package with the fix of the wallpaper dialog on Wayland and one revision
# more than the official one (docs/5-desktop/4-wallpaper.md). WITHOUT root:
# xbps-src builds in its own isolated environment (user namespaces). Same scheme as
# legion/portal-wlr-patch/build-portal-wlr.sh and common/steam/gamescope-patch/build-gamescope.sh.
# Previous (Spanish) name: compilar-xfdesktop.sh (folder xfdesktop-fondo/).
#
# The bug (xfdesktop 4.20.2, upstream https://gitlab.xfce.org/xfce/xfdesktop/-/issues/350, also #413
# with labwc): on Wayland the dialog (xfdesktop-settings) saves the wallpaper in
# /backdrop/screen0/monitorUnknown/… (name taken from gdk_monitor_get_model, which on Wayland is not the
# connector), while xfdesktop reads /backdrop/screen0/monitor<connector>/… (monitoreDP-1): choosing a wallpaper
# did nothing. On X11 it works.
# The patch (0001-backdrop-settings-xfwmonitor.patch) is upstream's commit ed26b06a ("Use XfwMonitor in
# backdrop settings instead of GdkMonitor", Brian J. Tarricone, 2026-05-24, MR !227 to the xfce-4.20 branch;
# in master, MR !226): the dialog takes the connector's name from libxfce4windowing, like xfdesktop. It needs
# libxfce4windowing >= 4.20.6 (Void has 4.20.7). Not released in a version on 2026-10-09. Before
# building, the script TESTS the patch against the code of Void's template (patch-still-needed,
# 2026-10-09; before it assumed "fixed in >= 4.20.3"): if it already has it, it does not build.
#
#   bash common/xfce-wayland/xfdesktop-wallpaper/build-xfdesktop.sh   # leaves the package in ~/src/void-packages/hostdir/binpkgs
# Afterwards: publish the .xbps (Release asset; install/fetch-assets.sh puts it next to this script) and
# install with install-xfdesktop-wallpaper.sh (root). Delete ~/src/void-packages when done if nothing else
# is going to be built. void-update warns if the installed xfdesktop stops being the one built here (a
# Void update replaces it: repeat this script). If the patch no longer applies, xbps-src stops at "patching".
# Done on 2026-10-09: the package of this folder (xfdesktop-4.20.2_2.x86_64.xbps, sha256 6f36c390…) was
# built on the Legion (2 min 47 s, with binary-bootstrap) and is valid for both machines. On the IdeaPad
# it also builds (5 min 29 s, spinning disk; same size and file list), but the Legion's is used.
# On the Legion it was run from /tmp (no scripts in ~): copy this script and the patch to /tmp/xfdesktop-wallpaper/, run it
# there, copy the .xbps to Common and delete /tmp/xfdesktop-wallpaper and ~/src/void-packages (~1.1 GB).
# (Copied out of the repository, set VOID_LEGION_REPO=<clone> so that it finds the patch test.)
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
D="$(dirname "$(readlink -f "$0")")"
PATCHES=("$D"/0*.patch)
[ "$(id -u)" != 0 ] || { t "without root"; exit 1; }
# Is the patch still needed? Common test (2026-10-09; common/patch-test/patch-still-needed.sh or, if the
# script runs outside the repository, ~/.local/bin/patch-still-needed): ALREADY_INCLUDED → it does not build (Void's
# code already has it); CONFLICT, PARTIAL or UNCHECKED → it stops (review the patch / no network).
TEST="$REPO_ROOT/common/patch-test/patch-still-needed.sh"
[ -f "$TEST" ] || TEST=$(command -v patch-still-needed) || { t "!! patch-still-needed is missing (common/patch-test/ or ~/.local/bin)"; exit 1; }
RES=$(bash "$TEST" void xfdesktop "${PATCHES[@]}")
echo "$RES"
case "$(sed -n 's/^RESULT [^ ]* [^ ]* \([A-Z_]*\).*/\1/p' <<<"$RES")" in
    STILL_NEEDED) ;;
    ALREADY_INCLUDED) t "The code already has the patch: no need to build (you can go back to Void's)."; exit 0 ;;
    *) t "!! Not building: review the result above."; exit 1 ;;
esac
mkdir -p ~/src && cd ~/src
[ -d void-packages ] || git clone --depth=1 https://github.com/void-linux/void-packages.git void-packages
cd void-packages
git checkout -- srcpkgs/xfdesktop 2>/dev/null || true
T=srcpkgs/xfdesktop/template
VER=$(sed -n 's/^version=//p' "$T")
REV=$(sed -n 's/^revision=//p' "$T")
t "Void template: %s_%s → built with revision=%s" "$VER" "$REV" "$((REV+1))"
mkdir -p srcpkgs/xfdesktop/patches
cp "${PATCHES[@]}" srcpkgs/xfdesktop/patches/
ls srcpkgs/xfdesktop/patches/
sed -i "s/^revision=$REV\$/revision=$((REV+1))/" "$T"
printf '%s\n' "XBPS_MAKEJOBS=$(nproc)" > etc/conf
[ -d masterdir-x86_64 ] || [ -d masterdir ] || ./xbps-src binary-bootstrap
./xbps-src pkg xfdesktop
ls -l hostdir/binpkgs/xfdesktop-"${VER}_$((REV+1))".x86_64.xbps
