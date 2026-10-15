#!/bin/bash
# Legion Go 2: InputPlumber (SteamOS's controller bridge) on Void, as a runit service.
# It presents the Legion's controller to Steam as a Steam Deck controller (target "deck-uhid"):
# back buttons, Deck-style touchpad and the body's gyroscope (gyro_3d/accel_3d through amd_sfh).
# Without it, Steam sees it as "Generic X-Box pad" (xpad). It uses the official binary (not in Void):
# it only asks for libiio (0.26 in Void = libiio.so.0). It does not need hid_lenovo_go: it reads the
# controller through hidraw.
# Previous (Spanish) name: instalar-inputplumber.sh (file list /usr/local/share/inputplumber-void/manifiesto;
# --remove also reads that old list).
# Usage: sudo bash legion/install-inputplumber.sh [--remove]     
#        (with inputplumber-x86_64.tar.gz of v0.81.0 and inputplumber-udevadm next to the script;
#         the tarball comes from the GitHub Release: install/fetch-assets.sh)
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
VER=0.81.0
SHA=bb167707964777751ad15f2da0ac99eb16a926a3997098e884f749b2e06f777b
HERE="$(dirname "$(readlink -f "$0")")"
TAR="$HERE/inputplumber-x86_64.tar.gz"
BIN=/usr/local/lib/inputplumber-void/bin       # udevadm wrapper, only in the service's PATH
MAN=/usr/local/share/inputplumber-void/manifest
MAN_OLD=/usr/local/share/inputplumber-void/manifiesto
SV=/etc/sv/inputplumber
PROFILE=/etc/inputplumber/devices.d/50-legion_go_2.yaml

reload() {
    udevadm hwdb --update
    udevadm control --reload
    udevadm trigger --action=change --subsystem-match=hidraw --subsystem-match=input
    dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
}

if is_remove "${1:-}"; then
    rm -f /var/service/inputplumber
    sleep 6                                    # runsvdir lets go of the service in ≤5 s
    for m in "$MAN" "$MAN_OLD"; do [ -f "$m" ] && xargs -d '\n' rm -f < "$m"; done
    rm -rf "$SV" "${MAN%/*}" "${BIN%/bin}" /usr/share/inputplumber "$PROFILE"
    rm -f /run/udev/rules.d/*-inputplumber-hide-*.rules     # its rules for hiding
    rmdir /etc/inputplumber/devices.d /etc/inputplumber 2>/dev/null || true
    reload
    t "removed (libiio stays; the logs, in /var/log/inputplumber)"; exit 0
fi

[ -f "$TAR" ] || { t "missing %s (install/fetch-assets.sh downloads it)" "$TAR"; exit 1; }
[ -f "$HERE/inputplumber-udevadm" ] || { t "missing %s" "$HERE/inputplumber-udevadm"; exit 1; }
echo "$SHA  $TAR" | sha256sum -c --quiet && t "inputplumber-x86_64.tar.gz: v%s, sha256 checked" "$VER"

# 1. libiio (the only library the binary lacks) and setfacl (acl-progs): the udev rules
#    with which it hides the controller's original devices use chmod + setfacl.
#    xbps gives an error if a package is already installed: only the missing ones.
for p in libiio acl-progs; do xbps-query "$p" >/dev/null || xbps-install -Sy "$p"; done

# 2. The package's files, except the systemd things (units and udev's autostart rule)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
tar xzf "$TAR" -C "$T"
P="$T/inputplumber"
rm -rf "$P/usr/lib/systemd" "$P/usr/lib/udev/rules.d/90-inputplumber-autostart.rules"
mkdir -p "${MAN%/*}"
( cd "$P" && find . -type f | sed 's|^\.||' ) > "$MAN"
rm -f "$MAN_OLD"                               # the same list under the old name: only one
while read -r f; do install -D -m "$( [ "${f#/usr/bin/}" != "$f" ] && echo 755 || echo 644 )" "$P$f" "$f"; done < "$MAN"
t "installed %s files (list in %s)" "$(wc -l < "$MAN")" "$MAN"

# 2b. udevadm wrapper: InputPlumber looks in "udevadm info" for the M: and U: lines of systemd's
#     udevadm, which eudev does not print; without them it hides nothing ("Failed to hide device … Unable to
#     create match rule", 2026-10-04) and Steam also saw the "Generic X-Box pad" (two controllers).
install -D -m 755 "$HERE/inputplumber-udevadm" "$BIN/udevadm"

# 3. Own profile: the Go 2 one but emulating the Steam Deck controller instead of the Xbox Elite.
#    /etc/inputplumber/devices.d takes priority over /usr/share/inputplumber/devices.
mkdir -p "${PROFILE%/*}"
grep -q '^  - xbox-elite$' /usr/share/inputplumber/devices/50-legion_go_2.yaml
# And its scale: this Legion's amd_sfh gives raw integer °/s and m/s², but declares
# in_anglvel_scale 0.000174532 (= 0.01 °/s) and in_accel_scale 0.098: InputPlumber computes raw×scale
# and Steam received a rotation 100 times weaker and a gravity of 0.9 m/s² (the gyroscope as mouse
# moved nothing, 2026-10-04). InputPlumber applies the mount_matrix (linear) AFTER the scale
# (src/drivers/iio_imu/driver.rs): a diagonal of 100 (gyroscope) and 10 (accelerometer) compensates.
GYRO=100; ACCEL=10
# Also, the body's gyroscope and accelerometer (gyro_3d/accel_3d, iio): the 0.81 profile
# declares them with "blocked: true" and so InputPlumber opens them but discards their data: Steam had no
# gyroscope ("device 0 capabilities" without Gyro/Accelerometer; the gyroscope as mouse moved nothing,
# 2026-10-04). The profiles of other consoles with a gyroscope (Ayaneo, GPD, AYN) do not carry it.
sed 's/^  - xbox-elite$/  - deck-uhid/' /usr/share/inputplumber/devices/50-legion_go_2.yaml |
    awk '/^  - group: /{imu=($0=="  - group: imu")} !(imu && $0=="    blocked: true")' |
    awk -v g="$GYRO" -v a="$ACCEL" '{print}
        $0=="      name: gyro_3d"  {printf "      mount_matrix:\n        x: [%s, 0, 0]\n        y: [0, %s, 0]\n        z: [0, 0, %s]\n", g, g, g}
        $0=="      name: accel_3d" {printf "      mount_matrix:\n        x: [%s, 0, 0]\n        y: [0, %s, 0]\n        z: [0, 0, %s]\n", a, a, a}' > "$PROFILE.tmp"
grep -q 'name: gyro_3d' "$PROFILE.tmp"
mv "$PROFILE.tmp" "$PROFILE"
grep -A5 '^target_devices:' "$PROFILE"
t "--- sensor in the profile (without blocked):"; grep -A3 'group: imu' "$PROFILE"

# 4. udev (hwdb, access rules) and D-Bus (the policy of the name org.shadowblip.InputPlumber)
reload

# 5. runit service (equivalent to inputplumber.service), with a readable log in /var/log
mkdir -p "$SV/log" /var/log/inputplumber
cat > "$SV/run.tmp" <<'EOF'
#!/bin/sh
# InputPlumber (installed by legion/install-inputplumber.sh; docs/3-hardware-support/1-controllers.md).
exec 2>&1
sv check dbus >/dev/null || exit 1
export LOG_LEVEL=info
export PATH="/usr/local/lib/inputplumber-void/bin:$PATH"   # its udevadm (M:/U:) first
exec /usr/bin/inputplumber
EOF
cat > "$SV/log/run.tmp" <<'EOF'
#!/bin/sh
exec svlogd -tt /var/log/inputplumber
EOF
chmod 755 "$SV/run.tmp" "$SV/log/run.tmp"
mv "$SV/run.tmp" "$SV/run"; mv "$SV/log/run.tmp" "$SV/log/run"
n0=$(cat /var/log/inputplumber/current 2>/dev/null | wc -l)   # to count only what is new
if [ -L /var/service/inputplumber ]; then sv restart inputplumber; else ln -s "$SV" /var/service/; fi

# 6. Check
sleep 8
sv status inputplumber
t "--- log"; tail -n 25 /var/log/inputplumber/current
t "--- warnings when hiding since this start (it must say 0)"
tail -n +$((n0 + 1)) /var/log/inputplumber/current | grep -c 'Failed to hide' || true
t "--- gyroscope capabilities (Gyro and Accelerometer must show):"
inputplumber device 0 capabilities 2>/dev/null | tr ',' '\n' | grep -iE 'gyro|accel' || t "(none yet)"
t "--- virtual devices"; grep '^N:' /proc/bus/input/devices | grep -iE 'inputplumber|steam|valve' || t "(none yet)"
t "Done. Close Steam and open it again so it sees the new controller."
