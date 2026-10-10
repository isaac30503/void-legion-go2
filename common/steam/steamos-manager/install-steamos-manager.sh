#!/bin/sh
# steamos-manager (Valve): with it Steam handles TDP, performance profiles and the GPU's level/manual clock
# (quick menu → Performance; the manual clock on the Legion Go 2 also needs the
# overdrive, legion/gpu-overdrive.sh). This installs the "make install" tree WITHOUT the systemd
# and sddm things. Tarball: steamos-manager-v26.4.1-void-2.tar.gz (since 2026-10-08), built on
# the Legion with build-steamos-manager.sh and the patch 0001-gpu-set_clocks-only-in-manual.patch
# (the GPU clock is only written with the level at "manual": no "Error setting manual GPU
# clock" errors with the manual clock disabled; Legion recipe, step 14, steamos-manager). Go back to the
# official one without patch: change TAR below to steamos-manager-v26.4.1-void.tar.gz (the one from Void's
# container of 2026-10-03, IdeaPad recipe, step 14) and repeat this script. It records in
# /usr/local/share/steamos-manager-void/ the fingerprint (sha256) and the package's name (package), which
# update-system reads; --remove deletes that folder. (Both tarballs come from the GitHub Release:
# install/fetch-assets.sh.)
# They are two processes, as in SteamOS:
#   - root, on the system bus ("steamos-manager -r"): runit service steamos-manager;
#   - the user's, on the session bus (Steam talks to it): Game Mode's launcher starts it
#     (/usr/local/bin/steam-game-mode, install-game-mode.sh) if /usr/lib/steamos-manager exists.
# What it controls comes from the model's profile (/usr/share/steamos-manager/devices/*.toml). On the
# Legion Go 2 it needs the lenovo-wmi-* modules (legion/tdp/install-tdp.sh).
# Previous (Spanish) name: instalar-steamos-manager.sh (it wrote the list "manifiesto" and the name
# "paquete"; installing replaces them with "manifest" and "package", which update-system reads).
# Usage: sudo sh common/steam/steamos-manager/install-steamos-manager.sh [--remove]   (--quitar also works)
set -eu
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
TAR="$(dirname "$(readlink -f "$0")")/steamos-manager-v26.4.1-void-2.tar.gz"
MAN=/usr/local/share/steamos-manager-void/manifest
MAN_OLD=/usr/local/share/steamos-manager-void/manifiesto
SV=/etc/sv/steamos-manager

reload_dbus() {
    dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
}

if is_remove "${1:-}"; then
    rm -f /var/service/steamos-manager; sleep 6
    for m in "$MAN" "$MAN_OLD"; do [ -f "$m" ] && xargs -d '\n' rm -f < "$m"; done
    rm -rf "$SV" "${MAN%/*}" /usr/share/steamos-manager /etc/steamos-manager
    reload_dbus
    t "removed (logs in /var/log/steamos-manager)"; exit 0
fi

[ -f "$TAR" ] || { t "missing %s (install/fetch-assets.sh downloads it)" "$TAR"; exit 1; }
# its two libraries (libspeechd, glib); xbps gives an error if they are already installed
for p in speech-dispatcher glib; do xbps-query "$p" >/dev/null || xbps-install -Sy "$p"; done

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
tar xzf "$TAR" -C "$T"
# Out: systemd units, the sddm setting and D-Bus activation (Exec=/bin/false +
# SystemdService: without systemd they start nothing; runit and the launcher start the processes).
rm -rf "$T/usr/lib/systemd" "$T/usr/share/dbus-1/services" "$T/usr/share/dbus-1/system-services"
mkdir -p "${MAN%/*}" /etc/steamos-manager/remotes.d
( cd "$T" && find . -type f | sed 's|^\.||' ) > "$MAN"
rm -f "$MAN_OLD" "${MAN%/*}/paquete"            # the old Spanish names: only one copy
while read -r f; do
    case "$f" in /usr/bin/*|/usr/lib/steamos-manager) m=755 ;; *) m=644 ;; esac
    install -D -m $m "$T$f" "$f"
done < "$MAN"
t "installed %s files (list in %s)" "$(wc -l < "$MAN")" "$MAN"
# Reference for update-system (2026-10-08): the fingerprint of the two binaries as they were
# installed ("sha256sum -c" checks it) and, separately, the package's name (tarball without .tar.gz),
# to know whether it is the patched one (…-void-2) or the official one (…-void). They are rewritten on every installation.
sha256sum /usr/lib/steamos-manager /usr/bin/steamosctl > "${MAN%/*}/sha256.tmp"
mv "${MAN%/*}/sha256.tmp" "${MAN%/*}/sha256"
basename "$TAR" .tar.gz > "${MAN%/*}/package.tmp"
mv "${MAN%/*}/package.tmp" "${MAN%/*}/package"
t "reference in %s/sha256 and package %s" "${MAN%/*}" "$(cat "${MAN%/*}/package")"
# GPU power profile: steamos-manager reads device/pp_power_profile_mode, which on the Legion
# Go 2 (SMU 14.0.0) NO kernel gives: neither the normal 6.18, nor Linux 7.3-rc5, nor SteamOS's 6.18.50-valve2
# (there only smu_v14_0_2 has it, from the dedicated graphics cards; checked 2026-10-04).
# Without the file, Steam shows an option that does nothing and the log fills with "Error
# getting GPU power profile". If it does not exist, that section is removed from the profiles.
if ! ls /sys/class/drm/card*/device/pp_power_profile_mode >/dev/null 2>&1; then
    for p in /usr/share/steamos-manager/devices/*.toml; do
        awk '/^\[/{omit=($0=="[gpu_power_profile]")} !omit' "$p" > "$p.tmp" && mv "$p.tmp" "$p"
    done
    t "== without pp_power_profile_mode: [gpu_power_profile] removed from the profiles"
fi
reload_dbus

mkdir -p "$SV/log" /var/log/steamos-manager
cat > "$SV/run.tmp" <<'EOS'
#!/bin/sh
# root steamos-manager (installed by common/steam/steamos-manager/install-steamos-manager.sh). Equivalent to its steamos-manager.service.
exec 2>&1
sv check dbus >/dev/null || exit 1
# It needs tracefs (its "ftrace" creates /sys/kernel/tracing/instances/…), which Void does not mount: without it
# it crashes on start with "Error: No such file or directory (os error 2)" (2026-10-04).
mountpoint -q /sys/kernel/tracing || mount -t tracefs nodev /sys/kernel/tracing || exit 1
export RUST_LOG=info
exec /usr/lib/steamos-manager -r
EOS
printf '#!/bin/sh\nexec svlogd -tt /var/log/steamos-manager\n' > "$SV/log/run.tmp"
chmod 755 "$SV/run.tmp" "$SV/log/run.tmp"
mv "$SV/run.tmp" "$SV/run"; mv "$SV/log/run.tmp" "$SV/log/run"
if [ -L /var/service/steamos-manager ]; then sv restart steamos-manager; else ln -s "$SV" /var/service/; fi

sleep 5
sv status steamos-manager
t "--- log"; tail -n 20 /var/log/steamos-manager/current
t "--- on the system bus:"
dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.NameHasOwner \
    string:com.steampowered.SteamOSManager1 | tail -n1
[ -x /usr/local/bin/steam-game-mode ] && ! grep -q steamos-manager /usr/local/bin/steam-game-mode &&
    t "!! Game Mode's launcher does not start the user process: repeat install-game-mode.sh"
t "Done: enter Game Mode and look at the quick menu → Performance."
