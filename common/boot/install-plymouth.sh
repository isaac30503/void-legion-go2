#!/bin/sh
# install-plymouth.sh — a loading animation from the boot until the session (Plymouth), and the same or
# another one for Game Mode's loading screen (steam-loading). Six animations (plymouth-void/generate.py,
# all drawn from vectors at the panel's size):
#   Steam A / Void A   the firmware logo (BGRT: Lenovo's) in its place and the small symbol spinning below
#   Steam B / Void B   that symbol, large and centred, without the firmware logo
#   Steam C            the whole Steam mechanism in a blue rectangle with STEAM
#   Void C             Void's logo with its letters, large, the arcs spinning behind them
# Void's runit does not integrate Plymouth, so it is done here:
#   - initramfs with Plymouth (dracut's module 45plymouth), "splash" and loglevel=2 in the kernel line
#     (silent-boot.sh). With loglevel=3 the console shows pr_crit messages: on the Legion
#     "amdgpu: Overdrive is enabled…" (steamos-manager's ppfeaturemask) came out at 2 s, before Plymouth,
#     and kept the text console on screen before and after the animation (2026-10-16);
#   - lightdm closes Plymouth by itself. As Plymouth is on console 1, lower than its minimum-vt (7), it does
#     not reuse it: X stays on 7. Console 1 has no text login (agetty-tty1 out: its vhangup() would take
#     the console from Plymouth; 2-6 stay, Ctrl+Alt+F2). DO NOT close Plymouth before lightdm: on
#     2026-10-02 a "plymouth quit --retain-splash" in /etc/sv/lightdm/conf left the machine stuck on the logo;
#   - shutdown and reboot: /etc/runit/shutdown.d/07-plymouth.sh, between 05-close-steam.sh and 10-sv-stop.sh,
#     stops lightdm and clears the console, so runit's "leave stage" lines do not show. The animation at
#     shutdown is optional (--shutdown-animation): on the Legion it freezes after a few frames (Plymouth
#     22.02 draws into the scanout buffer; amdgpu refuses its DirtyFB and the panel's power saving,
#     PSR/Replay, already on after the session, repeats the last image).
#   sudo sh common/boot/install-plymouth.sh [ANIMATION] [--loading-ANIMATION] [--shutdown-animation] [--debug]
#       ANIMATION: --void-b (default), --void-a, --void-c, --steam-a, --steam-b, --steam-c
#       --loading-steam-b (default) … --loading-void-c: Game Mode's loading screen (its frames go to
#       /usr/local/share/steam-loading/); --loading-same: the same one as at power-on
#       Without options: "B with B", Void B at power-on and Steam B while Steam loads (what both machines use)
#       --debug: Plymouth's trace in /run/plymouth-trace.log (with "stream:": with "file:" alone, Plymouth
#       22.02 also writes it ON THE SCREEN)
#   sudo sh common/boot/install-plymouth.sh --remove   removes it (leaves the package installed)
# docs/1-platform/3-boot.md. Run it again to change the animation. Previous (Spanish) name:
# arranque/instalar-plymouth.sh (and plymouth-void.sh, kept outside the repository while it was tested).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
GRUB=/etc/default/grub
LDM=/etc/sv/lightdm/conf
TTY1=/etc/runit/runsvdir/default/agetty-tty1
HOOK=/etc/runit/shutdown.d/07-plymouth.sh
CONF=/etc/plymouth/plymouthd.conf
ANIM_FLAG=/etc/plymouth/shutdown-animation
LOADING=/usr/local/share/steam-loading
THEMES="bgrt-steam steam-grande steam-mecanismo bgrt-void void-simbolo void-logo"
BEGIN='# >>> plymouth'; END='# <<< plymouth'
HERE=$(dirname "$(readlink -f "$0")")
DEBUG_ARGS="plymouth.debug=stream:/run/plymouth-trace.log plymouth.debug=file:/run/plymouth-debug.log"

theme_of() {   # variant → theme folder name
    case $1 in
        steam-a) echo bgrt-steam ;; steam-b) echo steam-grande ;; steam-c) echo steam-mecanismo ;;
        void-a) echo bgrt-void ;;   void-b) echo void-simbolo ;;  void-c) echo void-logo ;;
    esac
}

REMOVE=; VARIANT=void-b; LOAD=steam-b; ANIM=; DEBUG=
for a in "$@"; do
    case $a in
        --remove) REMOVE=1 ;;
        --steam-a|--steam-b|--steam-c|--void-a|--void-b|--void-c) VARIANT=${a#--} ;;
        --loading-steam-a|--loading-steam-b|--loading-steam-c|--loading-void-a|--loading-void-b|--loading-void-c)
            LOAD=${a#--loading-} ;;
        --loading-same) LOAD= ;;
        --shutdown-animation) ANIM=1 ;;
        --debug) DEBUG=1 ;;
        *) t "unknown option: %s" "$a"; exit 2 ;;
    esac
done
NAME=$(theme_of "$VARIANT")

cp "$GRUB" "$GRUB.bak"
# The block of the first version (it closed Plymouth before lightdm: see above)
if [ -f "$LDM" ]; then
    cp "$LDM" "$LDM.bak"; sed -i "/^$BEGIN/,/^$END/d" "$LDM"
    [ -s "$LDM" ] || rm -f "$LDM" "$LDM.bak"
fi
# The kernel line without what this script adds (splash and the debug trace)
strip_kernel_line() {
    sed -i -e '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/ plymouth\.debug=[^ "]*//g' \
           -e '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/ splash\([ "]\)/\1/g' "$GRUB"
}

if [ -n "$REMOVE" ]; then
    strip_kernel_line
    command -v plymouth-set-default-theme >/dev/null && plymouth-set-default-theme bgrt
    for n in $THEMES; do rm -rf "/usr/share/plymouth/themes/$n"; done
    t "   themes removed"
    [ -f "$CONF" ] && sed -i '/^DeviceScale=1$/d' "$CONF"
    rm -rf "${LOADING:?}" "${ANIM_FLAG:?}" "${HOOK:?}"
    [ -e "$TTY1" ] || ln -s /etc/sv/agetty-tty1 "$TTY1"
    t "   text login of console 1 given back"
else
    t "== 1. packages"
    command -v plymouthd >/dev/null || xbps-install -Sy plymouth plymouth-data
    command -v rsvg-convert >/dev/null || xbps-install -Sy librsvg-utils
    python3 -c 'import PIL' 2>/dev/null || xbps-install -Sy python3-Pillow
    [ -f /usr/share/void-artwork/void-logo.svg ] || xbps-install -Sy void-artwork

    t "== 2. theme %s (%s)" "$NAME" "$VARIANT"
    # The frames are made for the panel's height and Plymouth scales nothing (DeviceScale=1): on the
    # Legion, with its automatic scale 2, it stretched them and they came out blurry (2026-10-03).
    HEIGHT=$(head -1 /sys/class/drm/card*-eDP-*/modes /sys/class/drm/card*-LVDS-*/modes 2>/dev/null | grep -m1 -oE 'x[0-9]+$' | tr -d x)
    t "   panel %s px high" "${HEIGHT:-768}"
    for n in $THEMES; do rm -rf "/usr/share/plymouth/themes/$n"; done
    python3 "$HERE/plymouth-void/generate.py" "/usr/share/plymouth/themes/$NAME" "$VARIANT" "${HEIGHT:-768}"
    plymouth-set-default-theme "$NAME"
    # DeviceScale AFTER Theme: the reader of plymouth-set-default-theme (and of dracut, which uses it
    # to choose which theme to put in the initramfs) only looks at the FIRST key of [Daemon]; with
    # DeviceScale in front it does not see the theme and uses "spinner" (it happened on 2026-10-03).
    sed -i '/^DeviceScale=/d' "$CONF"
    sed -i "/^Theme=$NAME\$/a DeviceScale=1" "$CONF"
    grep -A3 '^\[Daemon\]' "$CONF" | sed 's/^/   /'
    [ "$(plymouth-set-default-theme)" = "$NAME" ] || { t "!! Plymouth does not see the theme %s: the initramfs is NOT rebuilt" "$NAME"; exit 1; }

    rm -rf "${LOADING:?}"
    if [ -n "$LOAD" ]; then
        t "   Game Mode's loading screen: %s (%s)" "$LOAD" "$LOADING"
        python3 "$HERE/plymouth-void/generate.py" "$LOADING" "$LOAD" "${HEIGHT:-768}"
    else
        t "   Game Mode's loading screen: the same"
    fi

    t "== 3. kernel line: splash"
    strip_kernel_line
    sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 splash"/' "$GRUB"

    t "== 4. console 1 for Plymouth: without text login on it"
    rm -f "$TTY1"
    for f in /etc/runit/runsvdir/default/agetty*; do [ -e "$f" ] && printf '%s ' "${f##*/}"; done; echo

    t "== 5. shutdown: %s" "$HOOK"
    cat > "$HOOK.tmp" <<'EOF'
# 07-plymouth.sh — loaded by /etc/runit/3 with "." (no subshell: no exit), after 05-close-steam.sh (Steam
# already closed with the session alive) and before 10-sv-stop.sh. Like upstream's plymouth-poweroff.service:
# the graphical session goes first (it lets go of the screen); then, only with
# /etc/plymouth/shutdown-animation, plymouthd --mode=shutdown and show-splash (plymouthd does not setsid:
# it stays in stage 3's session, which 70-pkill.sh spares). Everything with timeout: a failure of Plymouth
# never stops the shutdown. Without "splash" in the kernel line it does nothing.
# Put and removed by void-legion-go2's common/boot/install-plymouth.sh.
if [ -z "$IS_CONTAINER" ] && [ -x /usr/bin/plymouthd ] && grep -qw splash /proc/cmdline; then
    : > /run/system-shutting-down          # switch-mode-root does not change the mode when the session goes
    # The session's console (vt7) keeps what runit wrote when changing stage ("leave stage /etc/runit/2",
    # "enter stage /etc/runit/3"): it showed when lightdm stopped (2026-10-16). Cleared with the session still
    # on screen (nothing is seen) and again afterwards.
    printf '\033[H\033[2J\033[3J' > /dev/tty0 2>/dev/null
    timeout 15 sv force-stop lightdm >/dev/null 2>&1
    printf '\033[H\033[2J\033[3J' > /dev/tty0 2>/dev/null
    if [ -e /etc/plymouth/shutdown-animation ]; then
        [ -f /run/plymouth-trace.log ] && mv -f /run/plymouth-trace.log /run/plymouth-trace-boot.log
        if ! timeout 2 plymouth --ping >/dev/null 2>&1; then
            timeout 5 plymouthd --mode=shutdown --attach-to-session </dev/null >/dev/null 2>&1
        fi
        timeout 5 plymouth show-splash >/dev/null 2>&1
    fi
fi
true
EOF
    sh -n "$HOOK.tmp" && mv "$HOOK.tmp" "$HOOK" && chmod 644 "$HOOK"
    if [ -n "$ANIM" ]; then : > "$ANIM_FLAG"; t "   animation at shutdown: yes"
    else rm -f "$ANIM_FLAG"; t "   animation at shutdown: no (black, without text)"; fi
fi

t "== 6. kernel line and /etc/rc.conf block (silent-boot.sh: loglevel=2 with splash)"
sh "$HERE/silent-boot.sh" >/dev/null
if [ -z "$REMOVE" ] && [ -n "$DEBUG" ]; then
    sed -i "s|^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"|\1 $DEBUG_ARGS\"|" "$GRUB"
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$GRUB"

t "== 7. initramfs and menu"
dracut --force --regenerate-all
if [ -x /usr/local/share/grub-theme/install-theme.sh ]; then
    bash /usr/local/share/grub-theme/install-theme.sh | tail -8   # update-grub + repaint the background
elif [ -x /usr/local/share/grub-tema/instalar-tema.sh ]; then
    bash /usr/local/share/grub-tema/instalar-tema.sh | tail -8    # the old Spanish-named installation
else
    update-grub
fi
t "== check"
for i in /boot/initramfs-*.img; do
    printf '   %s: ' "$i"; if lsinitrd "$i" 2>/dev/null | grep -q 'plymouthd'; then t "with Plymouth"; else t "without Plymouth"; fi
done
