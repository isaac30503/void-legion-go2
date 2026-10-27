#!/bin/bash
# Builds Void's gamescope package with the PipeWire patch (0003-pipewire-fix-use-after-free.patch,
# next to it) and one revision more than the official one (docs/7-apps/1-screen-sharing.md, "Screen sharing in Game
# Mode"). Without root: xbps-src builds in its own isolated environment (user namespaces).
#   bash common/steam/gamescope-patch/build-gamescope.sh   # leaves the packages in ~/src/void-packages/hostdir/binpkgs (and debug/)
# Done on 2026-10-07 on the Legion (16 threads): ~6 min the first time (with binary-bootstrap), ~4 the second.
# Install (root) and put back cap_sys_nice (it is lost when reinstalling gamescope):
#   sudo xbps-install -R ~/src/void-packages/hostdir/binpkgs -R ~/src/void-packages/hostdir/binpkgs/debug gamescope
#   sudo setcap cap_sys_nice=eip /usr/bin/gamescope
# (with gamescope-dbg installed, add "gamescope-dbg": its version has to be the same). Afterwards, publish
# the .xbps as Release assets and delete ~/src/void-packages (~1.1 GB). void-update warns if the gamescope
# installed stops being the one built here (a Void update replaces it: repeat this script).
# If Void bumps the version and the patch no longer applies, xbps-src stops at "patching": review the patch.
# Previous (Spanish) name: compilar-gamescope.sh (folder gamescope-parche/).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
D="$(dirname "$(readlink -f "$0")")"
PATCH="$D/0003-pipewire-fix-use-after-free.patch"
# Is the patch still needed? Common test (2026-10-09; common/patch-test/patch-still-needed.sh or, if the
# script runs outside the repository, ~/.local/bin/patch-still-needed): ALREADY_INCLUDED → it does not build (Void's
# code already has it); CONFLICT, PARTIAL or UNCHECKED → it stops (review the patch / no network).
TEST="$REPO_ROOT/common/patch-test/patch-still-needed.sh"
[ -f "$TEST" ] || TEST=$(command -v patch-still-needed) || { t "!! patch-still-needed is missing (common/patch-test/ or ~/.local/bin)"; exit 1; }
RES=$(bash "$TEST" void gamescope "$PATCH")
echo "$RES"
case "$(sed -n 's/^RESULT [^ ]* [^ ]* \([A-Z_]*\).*/\1/p' <<<"$RES")" in
    STILL_NEEDED) ;;
    ALREADY_INCLUDED) t "The code already has the patch: no need to build (you can go back to Void's)."; exit 0 ;;
    *) t "!! Not building: review the result above."; exit 1 ;;
esac
mkdir -p ~/src && cd ~/src
[ -d void-packages ] || git clone --depth=1 https://github.com/void-linux/void-packages.git void-packages
cd void-packages
git checkout -- srcpkgs/gamescope 2>/dev/null || true
T=srcpkgs/gamescope/template
REV=$(sed -n 's/^revision=//p' "$T")
t "Void template: %s_%s → built with revision=%s" "$(sed -n 's/^version=//p' "$T")" "$REV" "$((REV+1))"
cp "$PATCH" srcpkgs/gamescope/patches/
sed -i "s/^revision=$REV\$/revision=$((REV+1))/" "$T"
printf '%s\n' "XBPS_MAKEJOBS=$(nproc)" "XBPS_DEBUG_PKGS=yes" > etc/conf
# Use the system's mirror if configured in /etc/xbps.d/
M="$(sed -n 's/^repository=\(https\?:\/\/[^ ]*\/\)current.*/\1current/p' /etc/xbps.d/*.conf 2>/dev/null | head -1)"
[ -n "$M" ] && echo "XBPS_MIRROR=$M" >> etc/conf
[ -d masterdir-x86_64 ] || [ -d masterdir ] || ./xbps-src binary-bootstrap
./xbps-src pkg gamescope
ls -l hostdir/binpkgs/gamescope-*.xbps hostdir/binpkgs/debug/gamescope-dbg-*.xbps
