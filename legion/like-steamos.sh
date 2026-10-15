#!/bin/bash
# Legion Go 2 (and the IdeaPad, from its own script): system settings that SteamOS has and Void does not.
# They come from comparing live with a Steam Deck (SteamOS 3.8.16) on 2026-10-05 (docs/6-game-mode/4-steamos-parity.md,
# "SteamOS settings").
# Previous (Spanish) name: como-steamos.sh (files 30-como-steamos.conf, 91-como-steamos.conf and the
# "como-steamos" block of /etc/rc.local; applying or --remove also cleans those old names).
#   sudo bash legion/like-steamos.sh           # apply (if Steam is open, it closes it cleanly)
#   sudo bash legion/like-steamos.sh --remove  # undo (the packages stay)
# 1. /etc/sysctl.d/30-like-steamos.conf: split_lock_mitigate=0 (SteamOS: 30-splitlock.conf; with 1, the
#    kernel slows down ~10 ms the program that does a "split lock", and some Windows games
#    stutter), inotify like Arch/SteamOS (10-arch.conf) and fq_codel as the network queue
#    (systemd's 50-default.conf; less latency with a loaded line; applies to interfaces created
#    afterwards, that is, from the next boot).
# 2. Transparent huge pages "always" like SteamOS (in /etc/rc.local, which Void runs at boot).
# 3. rtkit: PipeWire with real-time priority, like on the Deck (RR 20). It is only installed:
#    D-Bus starts it on demand when PipeWire asks for it
#    (/usr/share/dbus-1/system-services/org.freedesktop.RealtimeKit1.service). It does NOT go in runit:
#    with both, they clashed (2026-10-07, on the Legion: D-Bus started it first and runit's exited with
#    code 1 and was relaunched every second). If it finds /var/service/rtkit (old installation), it stops
#    it and removes it, without killing D-Bus's rtkit-daemon. Takes effect when PipeWire starts again.
# 4. earlyoom with SteamOS's thresholds (-M/-S 409600,307200 KiB) and gamemode (gamemoded is started by
#    D-Bus in the session when a game asks for it; libgamemode-32bit for the 32-bit ones).
# 5. gamescope-32bit: gamescope's Vulkan layer for 32-bit games (the 64-bit one already comes).
# 6. Desktop Steam with -pipewire (like SteamOS's /usr/bin/steam-jupiter): the user's launcher and
#    autostart. (Game Mode gets it from common/steam/install-game-mode.sh.)
# 7. Kernel with full preemption, preempt=full: SteamOS's goes with CONFIG_PREEMPT=y; Void's,
#    with PREEMPT_VOLUNTARY but PREEMPT_DYNAMIC (chosen at boot). In GRUB_CMDLINE_LINUX of
#    /etc/default/grub and not in GRUB_CMDLINE_LINUX_DEFAULT, which common/boot/silent-boot.sh and
#    legion/grub-hidden.sh rewrite. Regenerates the menu (update-grub); valid from the next boot.
# 8. memlock 8 MiB for the user, like SteamOS (systemd's DefaultLimitMEMLOCK); on Void, the
#    gcr package sets "@users - memlock 1024" (10-gcr-memlock.conf) and the user's entry takes
#    priority over the group's. Valid from the next session.
# Log: ~/like-steamos.log
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
U=$TARGET_USER
H=$TARGET_HOME
exec > >(tee "$H/like-steamos.log") 2>&1
SYS=/etc/sysctl.d/30-like-steamos.conf
SYS_OLD=/etc/sysctl.d/30-como-steamos.conf
BEGIN="# >>> like-steamos (transparent huge pages like SteamOS)"
END="# <<< like-steamos"
BEGIN_OLD="# >>> como-steamos (huge pages transparentes como SteamOS)"
END_OLD="# <<< como-steamos"
# Desktop launcher and autostart (the autostart's old Spanish name too, if it is still there).
LAUNCHERS="$H/.local/share/applications/steam.desktop $H/.config/autostart/steam-background.desktop $H/.config/autostart/steam-segundo-plano.desktop"
GRUB=/etc/default/grub
LIM=/etc/security/limits.d/91-like-steamos.conf
LIM_OLD=/etc/security/limits.d/91-como-steamos.conf

if is_remove "${1:-}"; then
    rm -f "$SYS" "$SYS_OLD"
    sed -i "/^$BEGIN\$/,/^$END\$/d; /^$BEGIN_OLD\$/,/^$END_OLD\$/d" /etc/rc.local
    echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
    sysctl -w kernel.split_lock_mitigate=1 fs.inotify.max_user_watches=175875 \
        fs.inotify.max_user_instances=128 net.core.default_qdisc=pfifo_fast
    [ -L /var/service/rtkit ] && { sv down rtkit; rm -f /var/service/rtkit; }   # from old installations
    rm -f /var/service/earlyoom /etc/sv/earlyoom/conf "$LIM" "$LIM_OLD"
    if grep -q '^GRUB_CMDLINE_LINUX=.*preempt=full' "$GRUB"; then
        sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)preempt=full/\1/; s/^GRUB_CMDLINE_LINUX=" */GRUB_CMDLINE_LINUX="/; /^GRUB_CMDLINE_LINUX=/ s/ *"$/"/' "$GRUB"
        update-grub
    fi
    for f in $LAUNCHERS; do [ -f "$f" ] && sudo -u "$U" sed -i 's#/usr/bin/steam -steamdeck -pipewire#/usr/bin/steam -steamdeck#' "$f"; done
    t "removed (rtkit, earlyoom, gamemode, libgamemode-32bit and gamescope-32bit stay installed)"; exit 0
fi

# Steam running (the desktop one starts by itself in the background): close it cleanly, like
# /etc/runit/shutdown.d/05-close-steam.sh (steam -shutdown with the process's own environment and an
# event-driven wait, 30 s cap): otherwise it would rewrite its launchers on exit.
if pgrep -u "$U" -x steam >/dev/null; then
    t "== closing Steam (steam -shutdown)"
    _p=$(pgrep -u "$U" -x steam | head -1)
    _e=$(tr '\0' '\n' < "/proc/$_p/environ" 2>/dev/null | grep -E '^(HOME|USER|LOGNAME|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | tr '\n' ' ')
    chpst -u "$U" env -i PATH=/usr/bin:/bin $_e /usr/bin/steam -shutdown </dev/null >/dev/null 2>&1 &
    timeout 30 pidwait -u "$U" -x steam 2>/dev/null
    if pgrep -u "$U" -x steam >/dev/null; then t "Steam did not close: close it by hand and repeat."; exit 1; fi
    t "   Steam closed (it starts again by itself in the next session, or open it from the menu)"
fi

t "== 1. sysctl"
cat > "$SYS.tmp" <<'EOF'
# Like SteamOS (set by legion/like-steamos.sh; docs/6-game-mode/4-steamos-parity.md).
kernel.split_lock_mitigate = 0
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
net.core.default_qdisc = fq_codel
EOF
mv "$SYS.tmp" "$SYS"
rm -f "$SYS_OLD"                 # the same settings under the old name: only one file
sysctl -p "$SYS"

t "== 2. transparent huge pages: always"
sed -i "/^$BEGIN_OLD\$/,/^$END_OLD\$/d" /etc/rc.local
if ! grep -q "^$BEGIN\$" /etc/rc.local; then
    printf '%s\n%s\n%s\n' "$BEGIN" "echo always > /sys/kernel/mm/transparent_hugepage/enabled" "$END" >> /etc/rc.local
fi
echo always > /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/enabled

t "== 3-5. packages (only the missing ones)"
F=""; for p in rtkit earlyoom gamemode libgamemode-32bit gamescope-32bit; do xbps-query "$p" >/dev/null || F="$F $p"; done
[ -n "$F" ] && xbps-install -Sy $F
printf 'OPTS="-M 409600,307200 -S 409600,307200 -r 3600"\n' > /etc/sv/earlyoom/conf
[ -L /var/service/earlyoom ] || ln -s /etc/sv/earlyoom /var/service/
# rtkit does not go in runit (D-Bus starts it, see 3 above). Old installation with the link: stop it and
# remove it; the rtkit-daemon that D-Bus started does not belong to runsv and keeps going.
if [ -L /var/service/rtkit ]; then sv down rtkit; rm -f /var/service/rtkit; t "   removed /var/service/rtkit (D-Bus starts it)"; fi

t "== 6. desktop Steam with -pipewire"
for f in $LAUNCHERS; do
    [ -f "$f" ] || { t "   (%s is not there)" "$f"; continue; }
    grep -q -- '-steamdeck -pipewire' "$f" ||
        sudo -u "$U" sed -i 's#/usr/bin/steam -steamdeck\( \|$\)#/usr/bin/steam -steamdeck -pipewire\1#' "$f"
    t "   %s: %s commands with -pipewire" "$f" "$(grep -c -- '-steamdeck -pipewire' "$f")"
done

t "== 7. kernel: preempt=full (from the next boot)"
if grep -q '^GRUB_CMDLINE_LINUX=' "$GRUB"; then
    grep -q '^GRUB_CMDLINE_LINUX=.*preempt=full' "$GRUB" ||
        sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 preempt=full"/; s/^GRUB_CMDLINE_LINUX=" /GRUB_CMDLINE_LINUX="/' "$GRUB"
else
    echo 'GRUB_CMDLINE_LINUX="preempt=full"' >> "$GRUB"
fi
grep -E '^GRUB_CMDLINE_LINUX(_DEFAULT)?=' "$GRUB"
update-grub
grep -c 'preempt=full' /boot/grub/grub.cfg

t "== 8. memlock 8 MiB (from the next session)"
printf '%s\n' "# Like SteamOS (set by legion/like-steamos.sh; docs/6-game-mode/4-steamos-parity.md)." "$U - memlock 8192" > "$LIM"
rm -f "$LIM_OLD"
cat "$LIM"

t "== check (runit takes up to 5 s to start the services)"
sleep 6
sysctl kernel.split_lock_mitigate fs.inotify.max_user_watches fs.inotify.max_user_instances net.core.default_qdisc
sv status earlyoom
t "Done. Still to do, if not done: sudo sh common/steam/install-game-mode.sh --no-loading-screen. And reboot."
