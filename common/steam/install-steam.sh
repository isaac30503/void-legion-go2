#!/bin/sh
# install-steam.sh — Steam + gamescope on Void (it started as a TEST on the IdeaPad, to see how it went
# before thinking about the Legion). Reversible.
#   1. nonfree and multilib repositories (Steam is nonfree and needs 32-bit libraries)
#   2. Steam, gamescope, MangoHud (with mangoapp, the performance overlay of the quick menu, and
#      the 32-bit one), Mesa's Vulkan for whatever GPU there is (Intel or AMD; 64 and 32 bits) and vulkaninfo;
#      complete 32-bit PipeWire (pipewire-32bit + libspa-videoconvert-32bit: Steam's client is
#      32-bit and without them Remote Play in Game Mode does not capture gamescope's image) and, with
#      an AMD GPU, Mesa's VA-API (64 and 32 bits: Remote Play's hardware encoding; 2026-10-07)
#   3. records what it installed by hand in the list of installed packages, for --remove
#      (STEAM_PACKAGES_LIST; by default installed-packages.txt next to this script; on the Legion,
#      install/install.sh uses legion/steam/installed-packages.txt)
#   4. what the steam package's README.voidlinux and SteamOS ask for: high open-files limit
#      for Proton (/etc/security/limits.d/90-steam.conf) and high vm.max_map_count
#      (/etc/sysctl.d/90-steam.conf, SteamOS's value)
#   5. checks Vulkan (gamescope needs it) and shows Void's documentation for Steam
# Previous (Spanish) name: instalar-steam.sh (list paquetes-instalados.txt).
#   sudo sh common/steam/install-steam.sh            installs (xbps shows the list and asks to confirm)
#   sudo sh common/steam/install-steam.sh --remove   removes what it installed, with its dependencies, and the repos
#                                                   
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
U=$TARGET_USER
HERE=$(dirname "$(readlink -f "$0")")
LIST=${STEAM_PACKAGES_LIST:-$HERE/installed-packages.txt}
REPOS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"
LIM=/etc/security/limits.d/90-steam.conf
SYS=/etc/sysctl.d/90-steam.conf

if is_remove "${1:-}"; then
    [ -s "$LIST" ] || { t "There is no %s: nothing to remove" "$LIST"; exit 1; }
    t "== removing: %s" "$(tr '\n' ' ' < "$LIST")"
    rm -f "$LIM" "$SYS"; t "== removed %s and %s (valid on reboot)" "$LIM" "$SYS"
    xbps-remove -R $(cat "$LIST")
    xbps-remove $REPOS 2>/dev/null || true
    xbps-install -S >/dev/null
    rm -f "$LIST"; t "== done (the games library in ~/.local/share/Steam is not deleted)"
    exit 0
fi

BEFORE=$(xbps-query -m | xargs -n1 xbps-uhelper getpkgname | sort)

t "== 1. repositories"
xbps-install -Sy $REPOS
xbps-install -S >/dev/null
xbps-query -L | sed 's/^/   /'

t "== 2. packages"
# Mesa's Vulkan according to the GPU (PCI vendor of card 0): Intel (0x8086) on the IdeaPad,
# AMD (0x1002, radeonsi/RADV) on the Legion. Without it gamescope does not start.
case "$(cat /sys/class/drm/card0/device/vendor 2>/dev/null)" in
    0x1002) VK=mesa-vulkan-radeon; VA="mesa-vaapi mesa-vaapi-32bit" ;;
    *)      VK=mesa-vulkan-intel; VA="" ;;   # Intel: this script does not install VA-API; on the IdeaPad
            # (HD 5500) intel-media-driver works (iHD 26.3.5, vainfo 2026-10-09), from ideapad-al-dia.sh --video
esac
t "   Vulkan: %s (GPU %s)" "$VK" "$(cat /sys/class/drm/card0/device/vendor 2>/dev/null)"
PKGS="steam gamescope gamescope-32bit MangoHud MangoHud-mangoapp MangoHud-32bit $VK Vulkan-Tools
      libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit mesa-dri-32bit
      $VK-32bit vulkan-loader-32bit
      libva-32bit libpulseaudio-32bit alsa-pipewire-32bit
      pipewire-32bit libspa-videoconvert-32bit $VA"
OK=""
for p in $PKGS; do
    if xbps-query "$p" >/dev/null 2>&1; then continue                      # already installed
    elif xbps-query -R "$p" >/dev/null 2>&1; then OK="$OK $p"
    else t "   (not in the repo, skipped: %s)" "$p"; fi
done
if [ -n "$OK" ]; then
    xbps-install $OK      # without -y: it shows the list and the size, and asks to confirm
else
    t "   everything already installed"
fi

AFTER=$(xbps-query -m | xargs -n1 xbps-uhelper getpkgname | sort)
printf '%s\n' "$BEFORE" > /tmp/steam-before.$$; printf '%s\n' "$AFTER" > /tmp/steam-after.$$
{ [ -f "$LIST" ] && cat "$LIST"; comm -13 /tmp/steam-before.$$ /tmp/steam-after.$$; } \
    | grep -v -x -E 'void-repo-.*' | sort -u > "$LIST.tmp"; mv "$LIST.tmp" "$LIST"
rm -f /tmp/steam-before.$$ /tmp/steam-after.$$
chown "$U": "$LIST"
t "   installed by hand (for --remove): %s" "$(tr '\n' ' ' < "$LIST")"

t "== 3. limits (valid from the next login / boot)"
cat > "$LIM" <<EOF
# Proton/esync: "eventfd: Too many open files" with the default 4096 (steam's README.voidlinux).
# 524288 = SteamOS's. Set by common/steam/install-steam.sh; --remove deletes it.
$U soft nofile 524288
$U hard nofile 524288
EOF
mkdir -p /etc/sysctl.d
cat > "$SYS" <<EOF
# Some games with Proton fail with the default 65530; this is SteamOS's value.
# Set by common/steam/install-steam.sh; --remove deletes it.
vm.max_map_count = 2147483642
EOF
sysctl -q -p "$SYS" && t "   vm.max_map_count = %s" "$(cat /proc/sys/vm/max_map_count)"
t "   nofile: 524288 from the next login (log out and back in)"

t "== 4. Vulkan (gamescope does not work without it)"
sudo -u "$U" vulkaninfo --summary 2>&1 | grep -E 'deviceName|driverName|apiVersion|ERROR' | sed 's/^/   /' || true

t "== 5. Void's documentation for Steam"
for f in /usr/share/doc/steam/README.voidlinux /usr/share/doc/steam/*; do
    [ -f "$f" ] && { echo "--- $f"; cat "$f"; break; }
done
