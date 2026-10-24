#!/bin/sh
# ideapad-wifi-iwd.sh — IdeaPad only: NetworkManager drives the Wi-Fi through iwd, not wpa_supplicant.
# With wpa_supplicant the RTL8723BE scanned without pause (a 3.7 s scan every ~4 s; pings of 100–300 ms) unless the
# BSSID was pinned, which lost roaming between the mesh nodes; with iwd, no scans and roaming works (2026-10-02).
# NetworkManager still sets the IP and the DNS. The Legion stays with wpa_supplicant (docs/2-base-system/2-network.md).
#   /etc/NetworkManager/conf.d/wifi-backend.conf   [device] wifi.backend=iwd
#   /etc/iwd/main.conf                             DefaultInterface=* (without it iwd deletes wlp3s0 and creates
#                                                  wlan0); DisableMacAddressRandomization=true (not essential: kept,
#                                                  it costs nothing)
#   /var/service/iwd                               the iwd service enabled in runit
# The IdeaPad's wifi-reparar (its recipe in Common, step 4) repairs the same two files with the same content.
#   sudo sh common/network/ideapad-wifi-iwd.sh            applies (the Wi-Fi drops for a few seconds)
#   sudo sh common/network/ideapad-wifi-iwd.sh --remove   back to wpa_supplicant (iwd stays installed)
# The first time, iwd does not know the network yet: iwctl station <interface> connect <network> (asks the password).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
NM=/etc/NetworkManager/conf.d/wifi-backend.conf
IWD=/etc/iwd/main.conf
put() {   # put <file> <content>: leaves <file>.bak when it changes
    if [ -f "$1" ] && [ "$(cat "$1")" = "$2" ]; then return 0; fi
    [ -f "$1" ] && cp "$1" "$1.bak"
    mkdir -p "${1%/*}"; printf '%s\n' "$2" > "$1.tmp" && mv "$1.tmp" "$1"; t "== %s written" "$1"; CHANGED=1
}
CHANGED=""
if is_remove "${1:-}"; then
    sv down NetworkManager
    rm -f /var/service/iwd "$NM" "$IWD"
    sv up NetworkManager
    t "removed: NetworkManager starts wpa_supplicant again (iwd stays installed: sudo xbps-remove iwd)"
    exit 0
fi
[ -x /usr/libexec/iwd ] || { t "iwd is not installed: sudo xbps-install -S iwd"; exit 1; }
put "$IWD" '[DriverQuirks]
DefaultInterface=*

[Scan]
DisableMacAddressRandomization=true'
put "$NM" '[device]
wifi.backend=iwd'
if [ ! -e /var/service/iwd ]; then
    sv down NetworkManager; pkill -x wpa_supplicant || true
    ln -s /etc/sv/iwd /var/service/
    # NetworkManager must find iwd on D-Bus when it starts: wait for its name, not for a time.
    gdbus wait --system --timeout 20 net.connman.iwd || t "iwd did not appear on D-Bus in 20 s: sudo sv status iwd"
    sv up NetworkManager
elif [ -n "$CHANGED" ]; then
    sv restart NetworkManager
fi
t "== state:"; sv status iwd NetworkManager
