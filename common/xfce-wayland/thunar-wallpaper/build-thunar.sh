#!/bin/bash
# Builds Void's Thunar package with the fix of "Set as wallpaper" on Wayland and
# one revision more than the official one (each machine's recipe, step 15, "Desktop wallpaper on Wayland").
# WITHOUT root: xbps-src builds in its own isolated environment. Same scheme as
# ../xfdesktop-wallpaper/build-xfdesktop.sh.
# Previous (Spanish) name: compilar-thunar.sh (folder thunar-fondo/).
#
# The bug (Thunar 4.20.9/4.20.10; not fixed upstream on 2026-10-09, neither in xfce-4.20 nor in master):
# the wallpaper plugin (plugins/thunar-wallpaper/twp-provider.c) names the monitor with
# gdk_monitor_get_model(). On X11 that is the connector (eDP-1); on Wayland it is the model ("Unknown"): it writes
# to /backdrop/screen0/monitorUnknown/…, which xfdesktop does not read, and the wallpaper does not change.
# The patch (0001-wallpaper-use-the-monitor-connector-name.patch, own, in upstream's style so it can be
# sent): it asks libxfce4windowing for the connector (xfw_screen_get_default +
# xfw_screen_get_monitor_from_gdk_monitor + xfw_monitor_get_connector), like xfdesktop's commit ed26b06a;
# if it does not find it, the previous behaviour. libxfce4windowing (>= 4.20.6) stays as an optional
# dependency in configure.ac; here it is required (post_configure checks HAVE_LIBXFCE4WINDOWING in config.h).
# It changes configure.ac and Makefile.am, so the template regenerates configure (xdt-autogen).
#
#   bash common/xfce-wayland/thunar-wallpaper/build-thunar.sh   # leaves Thunar-*.xbps and Thunar-devel-*.xbps in ~/src/void-packages/hostdir/binpkgs
# Only Thunar needs to be installed (the plugin goes in it; Thunar-devel is installed on neither).
# Afterwards: publish the Thunar-*.xbps (Release asset; install/fetch-assets.sh puts it next to this script),
# install with install-thunar-wallpaper.sh (root) and delete ~/src/void-packages. update-system warns if a
# Void update replaces it: repeat this script.
# Before building it TESTS the patch against the code of Void's template (patch-still-needed,
# 2026-10-09; before it looked with grep for a specific line): ALREADY_INCLUDED → it does not build; CONFLICT → it stops.
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
RES=$(bash "$TEST" void Thunar "${PATCHES[@]}")
echo "$RES"
case "$(sed -n 's/^RESULT [^ ]* [^ ]* \([A-Z_]*\).*/\1/p' <<<"$RES")" in
    STILL_NEEDED) ;;
    ALREADY_INCLUDED) t "The code already has the patch: no need to build (you can go back to Void's)."; exit 0 ;;
    *) t "!! Not building: review the result above."; exit 1 ;;
esac
mkdir -p ~/src && cd ~/src
[ -d void-packages ] || git clone --depth=1 https://github.com/void-linux/void-packages.git void-packages
cd void-packages
git checkout -- srcpkgs/Thunar 2>/dev/null || true
rm -rf srcpkgs/Thunar/patches
T=srcpkgs/Thunar/template
VER=$(sed -n 's/^version=//p' "$T")
REV=$(sed -n 's/^revision=//p' "$T")
printf '%s\n' "XBPS_MAKEJOBS=$(nproc)" > etc/conf
[ -d masterdir-x86_64 ] || [ -d masterdir ] || ./xbps-src binary-bootstrap

t "Void template: %s_%s → built with revision=%s" "$VER" "$REV" "$((REV+1))"
mkdir -p srcpkgs/Thunar/patches
cp "${PATCHES[@]}" srcpkgs/Thunar/patches/
ls srcpkgs/Thunar/patches/
sed -i "s/^revision=$REV\$/revision=$((REV+1))/" "$T"
cat >> "$T" <<'TEMPLATE'

# --- added by build-thunar.sh (wallpaper on Wayland) ---
hostmakedepends+=" xfce4-dev-tools autoconf automake libtool gettext-devel gtk-doc"
# libxfce4windowing-0.pc asks in Requires.private for wnck, xrandr and wayland-client: without their -devel,
# pkg-config does not accept it and configure goes on without it (without a warning: it is optional)
makedepends+=" libxfce4windowing-devel libwnck-devel libXrandr-devel wayland-devel"
pre_configure() {
	NOCONFIGURE=1 xdt-autogen
}
post_configure() {
	grep -q '^#define HAVE_LIBXFCE4WINDOWING 1' config.h || msg_error "configure did not find libxfce4windowing\n"
}
TEMPLATE
tail -8 "$T"
./xbps-src pkg Thunar
ls -l hostdir/binpkgs/Thunar-*"${VER}_$((REV+1))".x86_64.xbps
