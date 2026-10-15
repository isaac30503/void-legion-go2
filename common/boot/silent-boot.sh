#!/bin/sh
# silent-boot.sh — silences runit's "=> …" lines at boot and shutdown, without hiding
# warnings or errors. They are printed by msg() (and msg_ok the green "OK") of /etc/runit/functions;
# /etc/runit/1 and /etc/runit/3 load /etc/rc.conf before almost all of them, so it is enough to
# redefine them there (rc.conf is a configuration file: it survives updates;
# /etc/runit/functions does not). msg_warn and msg_error stay as they are.
# It also adjusts the kernel line in /etc/default/grub (leaves .bak); afterwards the menu has to be
# regenerated (update-grub, or common/grub-theme/install-theme.sh, which does it).
# And it removes GRUB's loading messages in /etc/grub.d/10_linux (remove-loading.py; leaves .bak).
#   sudo sh common/boot/silent-boot.sh            applies (leaves /etc/rc.conf.bak)
#   sudo sh common/boot/silent-boot.sh --remove   shows everything again
# docs/1-platform/3-boot.md ("Boot and shutdown with fewer messages").
# Previous (Spanish) name: arranque/arranque-silencioso.sh (block "# >>> arranque silencioso" in rc.conf and
# /etc/modules-load.d/dm-raid.conf.desactivado: applying or --remove also handles those old names).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
REMOVE=; is_remove "${1:-}" && REMOVE=1
CONF=/etc/rc.conf
BEGIN='# >>> silent boot'; END='# <<< silent boot'
BEGIN_OLD='# >>> arranque silencioso'; END_OLD='# <<< arranque silencioso'
cp "$CONF" "$CONF.bak"
sed -i "/^$BEGIN/,/^$END/d; /^$BEGIN_OLD/,/^$END_OLD/d" "$CONF"
if [ -z "$REMOVE" ]; then
    cat >> "$CONF" <<EOF
$BEGIN (docs/1-platform/3-boot.md; remove: sudo sh common/boot/silent-boot.sh --remove)
# Silences runit's "=> …" lines and "OK"; warnings and errors still come out.
msg() { :; }
msg_ok() { :; }
# Only at boot (/etc/runit/1) and at shutdown (/etc/runit/3), which are the ones that load this
# file: the NORMAL output of what they run (btrfs, fsck, seedrng, sysctl, modules-load…) goes
# nowhere; errors (stderr) stay on screen, and runit's warnings/errors too
# (through descriptor 3, which points to the screen). The emergency console gets it back.
# With Plymouth (install-plymouth.sh): warnings and errors also come out on top of the logo and the
# logo is removed if the emergency console kicks in. No logo at shutdown: stage 3 loads this with
# X still open (it would fight over the screen) and 70-pkill.sh would kill it halfway.
case "\$0" in
    */runit/1|*/runit/3)
        exec 3>&1 1>/dev/null
        plymsg() { command -v plymouth >/dev/null && plymouth display-message --text="\$*" 2>/dev/null; true; }
        msg_warn() { printf "\\033[1m\\033[33mWARNING: \$@\\033[m\\n" >&3; plymsg "WARNING: \$*"; }
        msg_error() { printf "\\033[1m\\033[31mERROR: \$@\\033[m\\n" >&3; plymsg "ERROR: \$*"; }
        emergency_shell() {
            command -v plymouth >/dev/null && plymouth quit 2>/dev/null
            exec 1>&3
            echo; echo "Cannot continue due to errors above, starting emergency shell."
            echo "When ready type exit to continue booting."
            /bin/sh -l
        }
        ;;
esac
$END
EOF
fi
# RAID modules: /etc/modules-load.d/dm-raid.conf was left by the installer (it belongs to no
# package) and here there is no RAID or LVM; it loaded dm-raid, raid456… and their list showed on screen.
DMR=/etc/modules-load.d/dm-raid.conf
[ -f "$DMR.desactivado" ] && mv "$DMR.desactivado" "$DMR.disabled"     # the old Spanish suffix
if [ -n "$REMOVE" ]; then
    [ -f "$DMR.disabled" ] && mv "$DMR.disabled" "$DMR" && t "== %s restored" "$DMR"
else
    [ -f "$DMR" ] && mv "$DMR" "$DMR.disabled" && t "== %s disabled (.disabled)" "$DMR"
fi

# Kernel line: "quiet" AFTER "loglevel=3" overrode it (the last one wins: quiet lets
# errors through); udev silenced and no blinking cursor on the console.
# It respects "splash" (set by install-plymouth.sh: without it Plymouth does not start).
GRUB=/etc/default/grub
cp "$GRUB" "$GRUB.bak"
SPLASH=; grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*[" ]splash[" ]' "$GRUB" && SPLASH=" splash"
if [ -n "$REMOVE" ]; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet$SPLASH\"|" "$GRUB"
else
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet loglevel=3 rd.udev.log_level=3 udev.log_level=3 vt.global_cursor_default=0$SPLASH\"|" "$GRUB"
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$GRUB"

# GRUB's "Loading ..." (see remove-loading.py)
L10=/etc/grub.d/10_linux
cp "$L10" "$L10.bak"
chmod 644 "$L10.bak"   # not executable! update-grub runs EVERYTHING executable in /etc/grub.d/:
                       # with an executable 10_linux.bak, every entry showed up twice
python3 "$(dirname "$(readlink -f "$0")")/remove-loading.py" "$L10" ${REMOVE:+--remove}
sh -n "$L10" && t "== syntax of %s: fine" "$L10"
sh -n "$CONF" && t "== syntax of %s: fine" "$CONF"
t "== differences:"; diff "$CONF.bak" "$CONF" || true
t "== test (as runit's scripts load it):"
M1=$(t "this should NOT come out"); M2=$(t "normal output: should NOT come out"); M3=$(t "a warning DOES come out")
M4=$(t "an error DOES come out"); M5=$(t "an error of a program DOES come out")
sh -c ". /etc/runit/functions; . $CONF; msg '$M1'; msg_ok; echo '$M2'; msg_warn '$M3'; msg_error '$M4'; echo '$M5' >&2" /etc/runit/1
