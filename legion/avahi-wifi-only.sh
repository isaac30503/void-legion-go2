#!/bin/sh
# avahi-wifi-only.sh — make avahi announce Legion-Go-Gen-2.local only over the Wi-Fi (2026-10-04;
# docs/2-base-system/2-network.md). With the dock, the Legion has two networks at once (Wi-Fi and the dock's,
# enp196s0f3u1u1): avahi heard its own announcement over the other one, thought the name was taken and
# renamed itself to Legion-Go-Gen-3.local (adds 1 to the final number) — "ssh lego" stopped
# resolving. The Wi-Fi is always there; the name of the dock's interface depends on the adapter.
# Trade-off: without Wi-Fi (cable only), there is no .local name.
# Previous (Spanish) name: avahi-solo-wifi.sh.
#   sudo sh legion/avahi-wifi-only.sh            applies
#   sudo sh legion/avahi-wifi-only.sh --remove   announces over all of them
# Interface: WIFI_INTERFACE of local.env (wlp193s0 on the Legion).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
need_env WIFI_INTERFACE
C=/etc/avahi/avahi-daemon.conf
cp "$C" "$C.bak"
sed -i '/^allow-interfaces=/d' "$C"
is_remove "${1:-}" || sed -i "/^\[server\]/a allow-interfaces=$WIFI_INTERFACE" "$C"
sed -n '/^\[server\]/,/^\[/p' "$C" | grep -v '^#' | grep . | sed 's/^/   /'
sv restart avahi-daemon
t "   avahi restarted; check the name with: pgrep -a avahi-daemon"
