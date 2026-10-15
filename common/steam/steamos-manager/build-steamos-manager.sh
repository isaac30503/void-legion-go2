#!/bin/bash
# Builds steamos-manager v26.4.1 (Valve, gitlab.steamos.cloud/holo/steamos-manager) with the patches
# of this folder (0*.patch) and packs it as the "make install" tree that
# install-steamos-manager.sh uses. WITHOUT root. Done on 2026-10-08 on the Legion (docs/6-game-mode/3-steamos-manager.md,
# steamos-manager): 1 min 30 s of building with 16 threads.
# Previous (Spanish) name: compilar-steamos-manager.sh (option --conservar, now --keep).
#
# Dependencies (the build ones are kept on purpose since 2026-10-08; docs/6-game-mode/3-steamos-manager.md):
#   sudo xbps-install -S glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config
#   git, make and dbus (already in the system); Rust/cargo from rustup in ~/.cargo/bin (extest's; on
#   2026-10-08, Rust 1.99.0). The crates' versions are pinned by the tag's Cargo.lock.
# Patches:
#   0001-gpu-set_clocks-only-in-manual.patch: AmdgpuPerformanceLevelDriver::set_clocks only writes
#     the clock to pp_od_clk_voltage with the level at "manual". The Legion Go 2's SMU 14.0.0
#     rejects it outside manual (EINVAL) and Steam resends the saved clock even if the manual clock is
#     disabled: without the patch, hundreds of "Error setting manual GPU clock: Invalid argument".
#     It adjusts two tests (gpu.rs test_set_amdgpu_gpu_clocks, root.rs manual_gpu_clock).
#     (Previous file name: 0001-gpu-set_clocks-solo-en-manual.patch; same content.)
#
# Usage: bash common/steam/steamos-manager/build-steamos-manager.sh [output-folder]   (/tmp by default)
#   → <output>/steamos-manager-v26.4.1-void-2.tar.gz; it is published as a Release asset (and kept
#     next to this script by install/fetch-assets.sh).
#   --keep (second argument) leaves the code in ~/src/steamos-manager; otherwise, it is deleted.
# The tests run inside dbus-run-session: two (job::test_job_emitted, sls::ftrace::ftrace_relay)
# need a session bus and over SSH they fail without it (also without the patch).
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
VER=v26.4.1
COMMIT=a0d399defebd60db30ba38325d9cf47dbda49bee     # "Tag 26.4.1"
URL=https://gitlab.steamos.cloud/holo/steamos-manager.git
HERE=$(dirname "$(readlink -f "$0")")
OUTDIR=$(readlink -f "${1:-/tmp}")
TAR="$OUTDIR/steamos-manager-$VER-void-2.tar.gz"
SRC="$HOME/src/steamos-manager"
ROOTDIR=$(mktemp -d /tmp/steamos-manager-root.XXXXXX)
trap 'rm -rf "$ROOTDIR"' EXIT
export PATH="$HOME/.cargo/bin:$PATH"

[ "$(id -u)" != 0 ] || { t "without root"; exit 1; }
# Is the patch still needed in $VER? Common test (2026-10-09; common/patch-test/patch-still-needed.sh
# or ~/.local/bin/patch-still-needed): ALREADY_INCLUDED → it does not build; CONFLICT/PARTIAL/UNCHECKED → it stops.
TEST="$REPO_ROOT/common/patch-test/patch-still-needed.sh"
[ -f "$TEST" ] || TEST=$(command -v patch-still-needed) || { t "!! patch-still-needed is missing (common/patch-test/ or ~/.local/bin)"; exit 1; }
RES=$(bash "$TEST" git "$URL" "$VER" steamos-manager "$HERE"/0*.patch)
echo "$RES"
case "$(sed -n 's/^RESULT [^ ]* [^ ]* \([A-Z_]*\).*/\1/p' <<<"$RES")" in
    STILL_NEEDED) ;;
    ALREADY_INCLUDED) t "%s already has the patch's change: build without patch (or use the official one)." "$VER"; exit 0 ;;
    *) t "!! Not building: review the result above."; exit 1 ;;
esac
for p in glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config git make; do
    xbps-query "$p" >/dev/null || { t "missing %s: sudo xbps-install -S %s" "$p" "$p"; exit 1; }
done
command -v cargo >/dev/null || { t "cargo is missing (rustup, ~/.cargo/bin)"; exit 1; }
command -v dbus-run-session >/dev/null || { t "dbus-run-session is missing"; exit 1; }
[ ! -e "$SRC" ] || { t "%s already exists: delete it or move it first" "$SRC"; exit 1; }

t "== clone %s" "$VER"
mkdir -p "${SRC%/*}"
git clone -q -c advice.detachedHead=false --depth 1 --branch "$VER" "$URL" "$SRC"
cd "$SRC"
[ "$(git rev-parse HEAD)" = "$COMMIT" ] || { t "!! the tag %s does not point to %s" "$VER" "$COMMIT"; exit 1; }

t "== patches"
for p in "$HERE"/0*.patch; do
    [ -e "$p" ] || continue
    echo "  ${p##*/}"; git apply "$p"
done
git diff --stat

t "== build (make build)"
make build
git diff --quiet -- Cargo.lock || { t "!! cargo changed Cargo.lock"; exit 1; }

t "== tests (make test, with its own session bus)"
rc=0; dbus-run-session -- make test > "$ROOTDIR.tests.log" 2>&1 || rc=$?
grep -E '^test result: .*[1-9][0-9]* passed|FAILED|panicked' "$ROOTDIR.tests.log" || true
[ "$rc" = 0 ] || { t "!! tests fail (log: %s)" "$ROOTDIR.tests.log"; exit 1; }
rm -f "$ROOTDIR.tests.log"

t "== make install DESTDIR=%s" "$ROOTDIR"
( umask 022; make install DESTDIR="$ROOTDIR" )
chmod 755 "$ROOTDIR"
mkdir -p "$OUTDIR"
tar czf "$TAR" --owner=root:0 --group=root:0 -C "$ROOTDIR" .

t "== checks"
ldd "$ROOTDIR/usr/lib/steamos-manager" "$ROOTDIR/usr/bin/steamosctl" | grep "not found" && exit 1
"$ROOTDIR/usr/bin/steamosctl" --version
OLD="$HERE/steamos-manager-$VER-void.tar.gz"
if [ -f "$OLD" ]; then
    if diff <(tar tzvf "$OLD" | awk '{print $1, $2, $6}' | sort -k3) \
            <(tar tzvf "$TAR" | awk '{print $1, $2, $6}' | sort -k3); then
        t "same files, permissions and owners as %s" "${OLD##*/}"
    else
        t "!! the file list differs from %s" "${OLD##*/}"
    fi
fi
sha256sum "$TAR" "$ROOTDIR/usr/lib/steamos-manager"

cd /
case "${2:-}" in --keep) t "code in %s" "$SRC" ;; *) rm -rf "$SRC" ;; esac
t "Done: %s (cargo cache in ~/.cargo/registry: %s)" "$TAR" "$(du -sh ~/.cargo/registry | cut -f1)"
