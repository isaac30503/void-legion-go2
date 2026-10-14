#!/bin/sh
# Network interfaces that udev did not process at boot (2026-10-04, Legion: the Wi-Fi came out as
# "wlan0", not renamed to wlp193s0 and "unmanaged" in NetworkManager: "link is not initialized by udev").
# Cause (Void): udev starts in stage 1 (core-services/02-udev.sh) and the udevd service of stage 2
# does "udevadm control --exit" and launches another one: whatever the kernel announces in that gap is
# lost. The MT7922 creates its interface after loading its firmware (~4.3 s) and fell right there (new
# udevd at 5.4 s). /etc/sv/udevd/run belongs to the package: it is not touched. This service, with udevd
# already running, looks for interfaces without an entry in /run/udev/data (n<ifindex>) and repeats
# their announcement to udev.
# Previous (Spanish) name: udev-red.sh (service "udev-red", log /var/log/udev-red; --remove also
# removes those).
# Usage: sudo sh legion/udev-net.sh [--remove]     
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
SV=/etc/sv/udev-net
if is_remove "${1:-}"; then
    rm -f /var/service/udev-net /var/service/udev-red; sleep 6; rm -rf "$SV" /etc/sv/udev-red; t "removed"; exit 0
fi
# The old Spanish-named service, if it is there (same job): only one of them.
if [ -e /etc/sv/udev-red ]; then rm -f /var/service/udev-red; sleep 6; rm -rf /etc/sv/udev-red; fi
mkdir -p "$SV/log" /var/log/udev-net
cat > "$SV/run.tmp" <<'EOS'
#!/bin/sh
# Installed by legion/udev-net.sh (Legion recipe, step 2–3). Once per boot; then it stays paused.
exec 2>&1
sv check udevd >/dev/null || exit 1
udevadm settle -t 30
for d in /sys/class/net/*; do
    n=${d##*/}; [ "$n" = lo ] && continue
    [ -e "/run/udev/data/n$(cat "$d/ifindex")" ] && continue
    echo "$n not processed by udev: repeating the announcement"
    udevadm trigger --action=add "$d"
done
exec pause
EOS
printf '#!/bin/sh\nexec svlogd -tt /var/log/udev-net\n' > "$SV/log/run.tmp"
chmod 755 "$SV/run.tmp" "$SV/log/run.tmp"
mv "$SV/run.tmp" "$SV/run"; mv "$SV/log/run.tmp" "$SV/log/run"
[ -L /var/service/udev-net ] || ln -s "$SV" /var/service/
sleep 6; sv status udev-net
t "Log (it only writes if it had to act): /var/log/udev-net/current"
