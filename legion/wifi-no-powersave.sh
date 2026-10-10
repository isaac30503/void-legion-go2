#!/bin/sh
# Legion Go 2: Wi-Fi (MT7922) WITHOUT power saving. With it ("Power save: on", the factory setting), the
# radio slept and did not answer ARP or mDNS until the Legion itself transmitted: SSH did not get in in
# either direction and the .local name did not resolve (2026-10-04); a ping from the Legion woke
# it up. 2 = disabled for NetworkManager (applies to every Wi-Fi connection).
# Previous (Spanish) name: wifi-sin-ahorro.sh (it wrote /etc/NetworkManager/conf.d/wifi-sin-ahorro.conf;
# --remove also deletes that old file).
# Usage: sudo sh legion/wifi-no-powersave.sh [--remove]      (--quitar also works)
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
F=/etc/NetworkManager/conf.d/wifi-no-powersave.conf
OLD=/etc/NetworkManager/conf.d/wifi-sin-ahorro.conf
if is_remove "${1:-}"; then
    rm -f "$F" "$OLD"; t "removed (it comes back when the next Wi-Fi connection starts)"; exit 0
fi
mkdir -p "${F%/*}"
printf '[connection]\nwifi.powersave = 2\n' > "$F.tmp" && mv "$F.tmp" "$F"
rm -f "$OLD"                     # same content under the old name: only one copy
# Right away, without reconnecting (NetworkManager will apply it by itself on the next connections):
for i in /sys/class/net/*/wireless; do
    IF=$(basename "$(dirname "$i")"); iw dev "$IF" set power_save off; iw dev "$IF" get power_save
done
