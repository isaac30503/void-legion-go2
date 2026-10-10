#!/bin/sh
# Diagnosis: why "steamos-manager -r" crashes with "No such file or directory" (2026-10-04).
# It runs it in the foreground for 4 s with RUST_LOG=debug: 1) as is; 2) with tracefs mounted.
# Previous name: diag-steamos-manager.sh (unchanged; its result of 2026-10-04 is archived in
# logs/legion/diagnostics-2026-10-04/).
# Usage: sudo sh common/steam/steamos-manager/diag-steamos-manager.sh   → ~/diag-steamos-manager.log
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
L=$TARGET_HOME/diag-steamos-manager.log; : > $L; chown "$TARGET_USER": $L
sv down steamos-manager
try() {
    echo "===== $1" >> $L
    RUST_LOG=debug timeout 4 /usr/lib/steamos-manager -r >> $L 2>&1; echo "exit: $?" >> $L
}
try "as is"
if ! mountpoint -q /sys/kernel/tracing; then
    mount -t tracefs nodev /sys/kernel/tracing && echo "== tracefs mounted" >> $L
fi
try "with tracefs"
sv up steamos-manager
t "done: %s" "$L"; tail -n 5 $L
