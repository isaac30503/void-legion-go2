#!/bin/sh
# diag-lightdm.sh — saves what matters from lightdm's log (only root reads it) in
# diag-lightdm.txt, next to it, to see why the lock screen came out on top of Game Mode.
# (It was used on the IdeaPad on 2026-10-03; its result stays on the disk, not in this repository.)
# Previous name: diag-lightdm.sh (unchanged).
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
OUT="$(dirname "$(readlink -f "$0")")/diag-lightdm.txt"
{
for f in /var/log/lightdm/lightdm.log.old /var/log/lightdm/lightdm.log; do
    [ -f "$f" ] || continue
    echo "===== $f"
    grep -n -v -E 'Loading configuration|Registered seat|has property|_g_io_module' "$f"
done
echo "===== seat0-greeter.log (end)"; tail -40 /var/log/lightdm/seat0-greeter.log 2>/dev/null
} > "$OUT" 2>&1
chown "$TARGET_USER": "$OUT"; t "saved in %s (%s lines)" "$OUT" "$(wc -l < "$OUT")"
