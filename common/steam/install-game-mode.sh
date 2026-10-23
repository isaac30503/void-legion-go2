#!/bin/sh
# install-game-mode.sh — SteamOS's Game Mode on Void: gamescope full screen (without
# Xfce underneath) and Steam in console mode
# inside, with the same arguments as SteamOS (and CachyOS): -steamos3 -steampal -steamdeck
# -gamepadui. Without them Steam thinks it is a PC in Big Picture: another interface, without "Switch to
# Desktop" and without handling mangoapp's overlay (it does not write to MANGOHUD_CONFIGFILE). With
# them it also tries to set up the machine like a Deck (TDP, charging, "wifi power management"…) through
# steamos-manager, which does nothing here unless it is installed (steam/steamos-manager/).
# The launcher works for two sessions: without DISPLAY (the Wayland session "direct screen" of
# install-direct-session.sh, the normal one) gamescope handles the screen itself; with DISPLAY (the X
# session of this script, as a fallback) it goes nested in full screen. From lightdm's login screen,
# the direct one was lost after ~20 s (docs/6-game-mode/2-game-mode.md 2): that is why it is always entered
# with autologin (install-passwordless-switch.sh).
# Switching between the two modes (steamos-session-select):
#   Game Mode → power menu → "Switch to Desktop": closes Steam and, when gamescope ends,
#     the launcher goes to Xfce (switch-mode-root desktop, without password).
#   Xfce → "Game Mode" launcher (applications menu): switch-mode-root game.
#   Without install-passwordless-switch.sh: it leaves the chosen session and logs out (login
#   screen with password).
# While Steam loads, steam-loading shows the frames of the Plymouth theme in use, with the firmware logo
# when the theme uses it (the same picture as at power-on, so one screen follows the other), and mangoapp
# starts when it closes (otherwise, it drew the overlay on top).
# Needs install-steam.sh first. Reversible.
# Previous (Spanish) name: instalar-modo-juego.sh. Installing removes the old Spanish-named pieces
# (/usr/local/bin/steam-modo-juego, steam-cargando, /usr/local/lib/steam-modo-juego,
# /usr/share/xsessions/steam-modo-juego.desktop, /usr/share/applications/modo-juego.desktop).
#   /usr/local/bin/steam-game-mode                      the session's launcher
#   /usr/share/xsessions/steam-game-mode.desktop        the session, for lightdm (X session)
#   /usr/local/bin/steamos-session-select               switches mode (Steam calls it, as in
#                                                       SteamOS): gamescope | xfce (or plasma)
#   /usr/local/bin/steamos-update                       with -steamos3 Steam asks for
#                                                       system updates: it answers "there are
#                                                       none" (code 7, like SteamOS); here the system
#                                                       is updated with void-update
#   /usr/share/applications/game-mode.desktop          "Game Mode" launcher for Xfce
#   /usr/local/lib/steam-game-mode/bin/sudo             brightness from Steam: its "sudo -n tee …/brightness"
#                                                       → elogind's SetBrightness (without privileges)
#   /usr/local/bin/steam-loading                        loading screen while Steam starts
#                                                       (the Plymouth theme's frames, like at
#                                                       power-on); it closes event-driven
#   cap_sys_nice on /usr/bin/gamescope                  high priority, as in SteamOS (it is lost
#                                                       when gamescope is updated: repeat this script)
#   sudo sh common/steam/install-game-mode.sh [--no-loading-screen]   installs
#   sudo sh common/steam/install-game-mode.sh --remove                removes it
# If it gets stuck: Ctrl+Alt+F2, log in, `pkill -KILL -x gamescope-wl` and `sudo sv restart lightdm`.
# The launcher's log (~/.local/state/steam-game-mode.log) is written in English: the checks of docs/ read it.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
BIN=/usr/local/bin/steam-game-mode
SES=/usr/share/xsessions/steam-game-mode.desktop
SEL=/usr/local/bin/steamos-session-select
UPD=/usr/local/bin/steamos-update
LAN=/usr/share/applications/game-mode.desktop
CAR=/usr/local/bin/steam-loading
BRI=/usr/local/lib/steam-game-mode/bin/sudo
# Old names: the Spanish ones (and the old Wayland session of an earlier version).
OLD="/usr/local/bin/steam-modo-juego /usr/share/xsessions/steam-modo-juego.desktop
     /usr/share/wayland-sessions/steam-modo-juego.desktop /usr/share/applications/modo-juego.desktop
     /usr/local/bin/steam-cargando /usr/local/lib/steam-modo-juego/bin/sudo"

remove_old() {
    for f in $OLD; do rm -f "$f"; done
    rmdir -p /usr/local/lib/steam-modo-juego/bin 2>/dev/null || true
}

if is_remove "${1:-}"; then
    rm -f "$BIN" "$SES" "$SEL" "$UPD" "$LAN" "$CAR" "$BRI"
    rmdir -p "${BRI%/*}" 2>/dev/null || true
    remove_old
    setcap -r /usr/bin/gamescope 2>/dev/null || true
    t "== removed %s, %s, %s, %s, %s and gamescope's cap_sys_nice" "$BIN" "$SES" "$SEL" "$UPD" "$LAN"
    exit 0
fi
{ command -v gamescope >/dev/null && command -v steam >/dev/null; } || { t "gamescope or steam is missing: first, install-steam.sh"; exit 1; }
command -v mangoapp >/dev/null || t "!! mangoapp is missing (MangoHud-mangoapp): without performance overlay. Repeat install-steam.sh"
remove_old

cat > "$BIN" <<'EOF'
#!/bin/sh
# Session "Steam (Game Mode)": gamescope full screen (nested in the session's X) + Steam
# in console mode.
# Installed by common/steam/install-game-mode.sh (docs/6-game-mode/2-game-mode.md). Log: ~/.local/state/steam-game-mode.log
# D-Bus session bus (in Xfce startxfce4 starts it): without it, Steam (its interface, a
# Chromium, fails with "Failed to connect to the bus") and the others each look for one through X11.
# gamescope portal (common/steam/portal-gamescope/install-portal-gamescope.sh, SteamOS's), if it is there:
# like SteamOS's start-gamescope-session, in this session the portal only uses those of gamescope-portals
# (screen sharing = gamescope's whole image). Before dbus-run-session: the bus inherits it.
G=/usr/local/share/xdg-desktop-portal/gamescope-portals
[ -d "$G" ] && export XDG_DESKTOP_PORTAL_DIR="$G"
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && command -v dbus-run-session >/dev/null; then
    exec dbus-run-session -- "$0" "$@"
fi
mkdir -p "$HOME/.local/state"
# Emptied on entry and opened in append mode (>>): the brightness sudo also writes here, and with ">"
# gamescope's output covered its lines (each one wrote from its own position).
: > "$HOME/.local/state/steam-game-mode.log"
exec >>"$HOME/.local/state/steam-game-mode.log" 2>&1
date '+== %F %T: entering Game Mode'     # to measure how long Steam takes to start
export XDG_CURRENT_DESKTOP=gamescope XDG_SESSION_DESKTOP=gamescope
# Audio: in Xfce, PipeWire is started by the session's autostart (/etc/xdg/autostart/
# pipewire.desktop); here there is no autostart and Steam saw no audio device
# (2026-10-03). pipewire launches wireplumber and pipewire-pulse by itself (/etc/pipewire/pipewire.conf.d/).
pw=
if command -v pipewire >/dev/null && ! pgrep -u "$(id -u)" -x pipewire >/dev/null; then
    pipewire & pw=$!
    echo "== audio: pipewire started (pid $pw)"
fi
# steamos-manager (TDP, GPU and power profile from Steam): its user process, on this session's
# bus (Steam talks to it; it, to the root one, a runit service). Only if it is installed
# (steam/steamos-manager/install-steamos-manager.sh; on the Legion Go 2). Its log goes here.
sm=
if [ -x /usr/lib/steamos-manager ]; then
    RUST_LOG=info /usr/lib/steamos-manager & sm=$!
    echo "== user steamos-manager started (pid $sm)"
fi
# Power button (common/power-button/install-power-button.sh): a press suspends (Steam), held ~3 s Steam's power
# menu opens, like SteamOS. Only if it is installed; it ends with this launcher (its parent).
pb=
if [ -x /usr/local/bin/power-button ]; then
    /usr/local/bin/power-button --mode game & pb=$!
    echo "== power button started (pid $pb)"
fi
# Brightness: Steam changes it with "echo N | sudo -n tee /sys/class/backlight/<x>/brightness", which here
# asks for a password. First in the PATH goes /usr/local/lib/steam-game-mode/bin/sudo, which turns
# ONLY that command into elogind's SetBrightness (GNOME's and KDE's: the session on screen
# can change its brightness without password or permissions); everything else goes to the real sudo.
export PATH="/usr/local/lib/steam-game-mode/bin:$PATH"
# Two ways, depending on the session that launches it:
#   - X session (the fallback): gamescope nested full screen in the session's X;
#   - Wayland session "direct screen" (install-direct-session.sh; the normal one): without DISPLAY, gamescope
#     handles the screen itself (DRM/KMS), as in SteamOS (VRR, HDR, refresh rate).
if [ -n "$DISPLAY" ]; then
    # No window manager or screensaver: so that X does not turn off the screen after 10 min (Steam
    # dims and turns it off by itself). Screen size for gamescope's window.
    xset s off -dpms 2>/dev/null
    size=$(xdotool getdisplaygeometry 2>/dev/null); W=${size% *}; H=${size#* }
    [ "$W" -gt 0 ] 2>/dev/null && [ "$H" -gt 0 ] 2>/dev/null || { W=1366; H=768; }
    WINDOW="-f -W $W -H $H -w $W -h $H"
    echo "== mode: nested in X ($DISPLAY), ${W}x${H}"
else
    WINDOW="--adaptive-sync"     # on the screen: without size (the native mode) and VRR if there is
    # Screen, like SteamOS on the Legion (its gamescope-session: -O '*',eDP-1): an external one if there is
    # (dock), otherwise its own. It goes with separate quotes so that the shell does not expand the *.
    SCREEN="*,eDP-1"
    # Almost like SteamOS's session on this Legion (/usr/lib/steamos/gamescope-session, saved in
    # the rescue): two Xwaylands (Steam and games) and the variables below, so that Steam can
    # change resolution when connecting or removing the monitor hot (2026-10-04). WITHOUT its
    # "-w 1280 -h 800 --max-scale 2 --cursor-scale-height 720": they are for drawing Steam at the
    # Steam Deck's resolution; here the image came out stretched (blurry) and the cursor big.
    WINDOW="$WINDOW --generate-drm-mode fixed --xwayland-count 2 --default-touch-mode 4
        --hide-cursor-delay 3000 --fade-out-duration 200"
    export GAMESCOPE_MODE_SAVE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/modes.cfg"
    export GAMESCOPE_PATCHED_EDID_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/gamescope/edid.bin"
    mkdir -p "${GAMESCOPE_MODE_SAVE_FILE%/*}"; touch "$GAMESCOPE_MODE_SAVE_FILE" "$GAMESCOPE_PATCHED_EDID_FILE"
    export STEAM_MULTIPLE_XWAYLANDS=1 SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0 vk_xwayland_wait_ready=false
    export STEAM_GAMESCOPE_HDR_SUPPORTED=1 STEAM_GAMESCOPE_VRR_SUPPORTED=1 STEAM_GAMESCOPE_NIS_SUPPORTED=1
    export STEAM_GAMESCOPE_TEARING_SUPPORTED=1 STEAM_GAMESCOPE_HAS_TEARING_SUPPORT=1
    export STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER=1 STEAM_GAMESCOPE_DYNAMIC_REFRESH_IN_STEAM_SUPPORTED=0
    export STEAM_GAMESCOPE_FANCY_SCALING_SUPPORT=1 STEAM_GAMESCOPE_COLOR_MANAGED=1 STEAM_GAMESCOPE_VIRTUAL_WHITE=1
    export STEAM_ENABLE_DYNAMIC_BACKLIGHT=1 STEAM_ENABLE_VOLUME_HANDLER=1 STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1
    export SRT_URLOPEN_PREFER_STEAM=1 VKD3D_SWAPCHAIN_LATENCY_FRAMES=3 GAMESCOPE_NV12_COLORSPACE=k_EStreamColorspace_BT601
    export QT_IM_MODULE=steam GTK_IM_MODULE=Steam
    # More from SteamOS's session (/usr/lib/steamos/gamescope-session, compared live with a
    # Steam Deck with SteamOS 3.8.16 on 2026-10-05; the Legion's was the same): gamescope's Vulkan layer in
    # the games (VkLayer_FROG_gamescope_wsi, from the gamescope package; the 32-bit one,
    # gamescope-32bit), the file of Steam's FPS limiter and, on AMD GPUs, the variable rate
    # shading that Steam offers in Performance (RADV; "1x1" = no reduction). In /tmp, like
    # SteamOS: games read them from inside Steam's container (pressure-vessel).
    export ENABLE_GAMESCOPE_WSI=1
    export GAMESCOPE_LIMITER_FILE="$(mktemp /tmp/gamescope-limiter.XXXXXXXX)"
    if [ "$(cat /sys/class/drm/card0/device/vendor 2>/dev/null)" = 0x1002 ]; then
        export STEAM_USE_DYNAMIC_VRS=1
        export RADV_FORCE_VRS_CONFIG_FILE="$(mktemp /tmp/radv_vrs.XXXXXXXX)"
        echo "1x1" > "$RADV_FORCE_VRS_CONFIG_FILE"
    fi
    # Screen refresh range for Steam (its refresh control and the FPS limit),
    # as SteamOS does with the Deck (STEAM_DISPLAY_REFRESH_LIMITS=40,60 on the LCD, 45,90 on the OLED).
    # Without it, on the Legion Go 2 the screen stayed at 120 Hz and the FPS limit gave half (30
    # requested → 15 in MangoHud, 2026-10-05). The range, that of gamescope's script for that screen
    # (lenovo.legiongo2.oled.lua: 48–144 Hz). By model (DMI), like steamos-manager.
    case "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" in
        83N0|83N1) export STEAM_DISPLAY_REFRESH_LIMITS=48,144 ;;   # Legion Go 2
    esac
    echo "== mode: direct screen (DRM)${STEAM_DISPLAY_REFRESH_LIMITS:+; refresh rates $STEAM_DISPLAY_REFRESH_LIMITS}"
fi
# Keyboard: gamescope does not read X's (00-keyboard.conf); libxkbcommon takes XKB_DEFAULT_LAYOUT.
# It is read from the same file so that it follows the system's layout (latam on the IdeaPad; docs/2-base-system/1-system.md).
XKB_DEFAULT_LAYOUT=$(sed -n 's/.*"XkbLayout"[[:space:]]*"\([^"]*\)".*/\1/p' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null)
export XKB_DEFAULT_LAYOUT="${XKB_DEFAULT_LAYOUT:-us}"
# And the variant, if there is one (the Legion: us + intl, with dead keys; the IdeaPad has none).
XKB_DEFAULT_VARIANT=$(sed -n 's/.*"XkbVariant"[[:space:]]*"\([^"]*\)".*/\1/p' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null)
if [ -n "$XKB_DEFAULT_VARIANT" ]; then export XKB_DEFAULT_VARIANT; fi
# Cursor: the same theme as the desktop (Volantes; Xfce's xsettings). SteamOS set its own
# (theme "steam") the same way: XCURSOR_THEME for X things and gtk-cursor-theme-name in GTK's settings.ini,
# because Chromium (Steam's interface) ignores XCursor. In Xfce xsettings rules, so
# settings.ini changes nothing on the desktop.
CURSOR=$(sed -n 's/.*name="CursorThemeName" type="string" value="\([^"]*\)".*/\1/p' \
    "${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" 2>/dev/null)
if [ -n "$CURSOR" ]; then
    export XCURSOR_THEME="$CURSOR" XCURSOR_SIZE=24
    INI="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"
    mkdir -p "${INI%/*}"
    if grep -q '^gtk-cursor-theme-name=' "$INI" 2>/dev/null; then
        sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$CURSOR/" "$INI"
    elif grep -q '^\[Settings\]' "$INI" 2>/dev/null; then
        sed -i "/^\[Settings\]/a gtk-cursor-theme-name=$CURSOR" "$INI"
    else
        printf '[Settings]\ngtk-cursor-theme-name=%s\n' "$CURSOR" >> "$INI"
    fi
    echo "cursor: $CURSOR"
fi
# -e: integration with Steam (focus, overlays). -W/-H/-f: gamescope's window takes the whole
# screen; -w/-h: Steam and the games at the same resolution.
# Performance overlay (mangoapp, package MangoHud-mangoapp) AS IN SteamOS
# (the Legion's /usr/lib/steamos/gamescope-session): gamescope WITHOUT --mangoapp; the session creates the
# file that Steam rewrites with the level chosen in the quick menu (MANGOHUD_CONFIGFILE), it starts
# at "no_display" written with echo, and mangoapp runs separately (there, gamescope-mangoapp.service).
# With --mangoapp, gamescope wrote "no_display" followed by a null byte: MangoHud did not
# recognize it ("Unknown option 'no_display'") and the overlay always showed (2026-10-03).
export STEAM_USE_MANGOAPP=1 STEAM_MANGOAPP_PRESETS_SUPPORTED=1 STEAM_MANGOAPP_HORIZONTAL_SUPPORTED=1
export STEAM_DISABLE_MANGOAPP_ATOM_WORKAROUND=1
export MANGOHUD_CONFIGFILE="${XDG_RUNTIME_DIR:-/tmp}/steam-game-mode/mangohud.config"
mkdir -p "${MANGOHUD_CONFIGFILE%/*}"
echo "no_display" > "$MANGOHUD_CONFIGFILE"
# Knowing for sure when Steam ends, without querying anything meanwhile: a named pipe
# (FIFO). Steam's wrapper writes to it when Steam ends ("steam") and, in case gamescope
# crashes first, gamescope's subshell when it ends ("gamescope"). The launcher waits
# blocked reading, spending nothing, and wakes up with whatever arrives first. It opens it for
# reading and writing (fd 3) so that writing never waits for a reader.
FIFO="${XDG_RUNTIME_DIR:-/tmp}/steam-game-mode.fifo"
rm -f "$FIFO"; mkfifo -m 600 "$FIFO"; exec 3<>"$FIFO"
# Loading screen (steam-loading) until Steam opens its first window; it closes by itself,
# event-driven. mangoapp starts AFTER it: Steam writes the overlay's saved level when
# starting, before its window, and mangoapp drew it on top of the loading screen. On start it
# reads the level that is in MANGOHUD_CONFIGFILE and follows its changes, so nothing is lost.
M=; command -v mangoapp >/dev/null && M='mangoapp'
C=; [ -x /usr/local/bin/steam-loading ] && C='/usr/local/bin/steam-loading'
P=; [ -n "$C$M" ] && P="( $C${C:+${M:+; }}$M ) & "
# gamescope's portal needs in D-Bus's environment GAMESCOPE_WAYLAND_DISPLAY (gamescope only gives
# it to its children) and XDG_CURRENT_DESKTOP=gamescope (otherwise: "Not running under a gamescope session"):
# they are passed from inside gamescope, before Steam (SteamOS does it with systemd).
U=; [ -n "$XDG_DESKTOP_PORTAL_DIR" ] && U='dbus-update-activation-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP GAMESCOPE_WAYLAND_DISPLAY XDG_DESKTOP_PORTAL_DIR; '
[ -n "$U" ] && echo "== gamescope portal: $XDG_DESKTOP_PORTAL_DIR"
# -pipewire: like SteamOS (/usr/bin/steam-jupiter always adds it): Steam captures through PipeWire
# to record games and Remote Play.
echo "== $(date '+%F %T'): launching gamescope"
( gamescope -e $WINDOW ${SCREEN:+-O "$SCREEN"} -- sh -c "${U}${P}steam -steamos3 -steampal -steamdeck -gamepadui -pipewire; echo steam > '$FIFO'"
  echo gamescope > "$FIFO" ) &
sub=$!
read -r who <&3
# On the direct screen, gamescope takes ~25 s to close after Steam: it asks elogind to release the
# screen and that D-Bus call runs out of time ("Could not close device: Connection timed out",
# 2026-10-03). If Steam ended, gamescope is closed at once: the kernel releases the screen when
# the process closes, and its "reaper" closes mangoapp. Nested in X it does not happen: it is left to end.
if [ "$who" = steam ] && [ -z "$DISPLAY" ]; then
    echo "== $(date '+%F %T'): Steam ended; closing gamescope without waiting for elogind"
    pkill -KILL -P "$sub" 2>/dev/null
fi
wait "$sub" 2>/dev/null
exec 3<&-; rm -f "$FIFO"
# When Steam ends (and gamescope with it), whether by "Switch to Desktop" or by "Exit Steam": to
# Xfce. Here, already without gamescope and still inside the session, steamos-session-select switches at once.
echo "== $(date '+%F %T'): end of gamescope; to Xfce"
[ -n "$pw" ] && { pkill -P "$pw" 2>/dev/null; kill "$pw" 2>/dev/null; }   # PipeWire and its children
[ -n "$sm" ] && kill "$sm" 2>/dev/null
[ -n "$pb" ] && kill "$pb" 2>/dev/null
/usr/local/bin/steamos-session-select xfce
EOF
chmod 755 "$BIN"

mkdir -p /usr/share/xsessions
cat > "$SES" <<EOF
[Desktop Entry]
Name=Steam (Game Mode)
Name[es]=Steam (Modo Juego)
Comment=Steam in console mode inside gamescope, like SteamOS's Game Mode
Comment[es]=Steam en modo consola dentro de gamescope, como el Modo Juego de SteamOS
Exec=$BIN
Type=Application
DesktopNames=gamescope
EOF

cat > "$SEL" <<'EOF'
#!/bin/sh
# steamos-session-select — switches between Game Mode and Xfce (same name as SteamOS's, which is
# /usr/bin/steamos-session-select: plasma → desktop, gamescope → Game Mode). Steam calls it
# ("Switch to Desktop"), as do Xfce's "Game Mode" launcher and steam-game-mode when it ends.
# Two ways:
#   - WITHOUT password, like SteamOS, if install-passwordless-switch.sh is installed: it changes lightdm's
#     autologin session and restarts it (switch-mode-root, allowed by sudoers);
#   - otherwise: it leaves the chosen session for the login screen (AccountsService, where
#     lightdm takes it from; the user can change their own without root) and closes the current session.
# Installed by common/steam/install-game-mode.sh (docs/6-game-mode/2-game-mode.md).
# Log of each call (English): ~/.local/state/steamos-session-select.log
mkdir -p "$HOME/.local/state"
exec 2>>"$HOME/.local/state/steamos-session-select.log"
echo "$(date '+%F %T') called with '$*' from ${XDG_SESSION_DESKTOP:-?} (parent: $(ps -o comm= -p $PPID))" >&2
case "${1:-gamescope}" in
    gamescope)               ses=steam-game-mode; mode=game ;;
    plasma*|desktop|xfce)    ses=xfce; mode=desktop ;;
    *) echo "!! Unknown session '$1'" >&2; exit 1 ;;
esac
LOG="$HOME/.local/state/steamos-session-select.log"
mkdir -p "${LOG%/*}"
# From the desktop to Game Mode: close the desktop Steam CLEANLY before switching session.
# Otherwise, the switch (lightdm restarts) kills it, and when starting in Game Mode Steam sees that it "did not
# close properly" and does the full checksum verification: on 2026-10-04 on the Legion
# it found 44 "bad CRC" binaries, repaired them and restarted (18 s of the 21 it took to enter).
# Event-driven: pidwait blocks until the process ends (pidfd); 30 s as a cap.
close_desktop_steam() {
    pgrep -u "$(id -u)" -x steam >/dev/null || return 0
    echo "   closing the desktop Steam (steam -shutdown)" >> "$LOG"
    steam -shutdown >/dev/null 2>&1 &
    if timeout 30 pidwait -u "$(id -u)" -x steam 2>/dev/null; then
        echo "   Steam closed cleanly" >> "$LOG"
    else
        echo "   !! Steam did not close in 30 s; switching anyway" >> "$LOG"
    fi
}
echo "$(date '+%F %T') $0 $* (session: ${XDG_SESSION_DESKTOP:-?})" >> "$LOG"
if sudo -n /usr/local/bin/switch-mode-root --check 2>/dev/null; then
    if [ "$XDG_SESSION_DESKTOP" = "gamescope" ]; then
        [ "$mode" = desktop ] || exit 0
        if pgrep -u "$(id -u)" -x gamescope-wl >/dev/null; then
            # From Steam ("Switch to Desktop"): close it cleanly (it saves the cloud). The switch is
            # done by steam-game-mode as soon as gamescope ends, still inside the session: a
            # background process from here died with the session before changing anything (2026-10-03).
            echo "   closing Steam; steam-game-mode will switch when it ends" >> "$LOG"
            steam -shutdown >/dev/null 2>&1 &
        else
            echo "   switch-mode-root desktop" >> "$LOG"
            sudo -n /usr/local/bin/switch-mode-root desktop >> "$LOG" 2>&1
        fi
    elif [ "$mode" = game ]; then
        close_desktop_steam
        echo "   switch-mode-root game" >> "$LOG"
        sudo -n /usr/local/bin/switch-mode-root game >> "$LOG" 2>&1
    fi
    exit 0
fi
echo "   without switch-mode-root: login screen" >> "$LOG"
u=/org/freedesktop/Accounts/User$(id -u)
busctl call org.freedesktop.Accounts "$u" org.freedesktop.Accounts.User SetXSession s "$ses" 2>/dev/null
busctl call org.freedesktop.Accounts "$u" org.freedesktop.Accounts.User SetSession s "$ses" 2>/dev/null
printf '[Desktop]\nSession=%s\n' "$ses" > "$HOME/.dmrc"
if [ "$XDG_SESSION_DESKTOP" = "gamescope" ]; then
    [ "$ses" = xfce ] || exit 0
    # If it is steam-game-mode calling at the end (Steam already closed), there is nothing to close.
    pgrep -u "$(id -u)" -x gamescope-wl >/dev/null || exit 0
    # Close Steam cleanly (it saves the cloud). Closing gamescope as soon as Steam ends is already done by
    # steam-game-mode (notice through the FIFO); before, here there was a "sleep 30" and a blind pkill.
    steam -shutdown >/dev/null 2>&1 &
else
    [ "$ses" = steam-game-mode ] || exit 0
    close_desktop_steam
    xfce4-session-logout --logout
fi
EOF
chmod 755 "$SEL"

cat > "$UPD" <<'EOF'
#!/bin/sh
# steamos-update — with -steamos3, Steam asks for system updates (in SteamOS it is /usr/bin/steamos-update).
# Here it only CHECKS, with void-update's check without root (2026-10-22, the user's decision):
#   steamos-update check   0 and "N updates pending" when there are some (Steam shows that there are updates),
#                          7 and "No update available" when there are none, 1 if the check failed (no network)
#   steamos-update         (Steam's "apply") updates nothing: the system is updated with void-update on the desktop,
#                          where it asks for the password and shows what changes; answers 7
# The count is void-update's list (packages + Flatpak, ~/.local/state/void-update/all), which the panel icon shares.
# Installed by common/steam/install-game-mode.sh (docs/6-game-mode/2-game-mode.md).
VU="$HOME/.local/bin/void-update"
LIST="${XDG_STATE_HOME:-$HOME/.local/state}/void-update/all"
count() { [ -s "$LIST" ] && grep -c . "$LIST" || echo 0; }
case "${1:-}" in
    --supports-duplicate-detection) exit 0 ;;
    check)
        [ -x "$VU" ] || { echo "No update available (void-update is not installed)"; exit 7; }
        "$VU" -l >/dev/null 2>&1; rc=$?
        [ $rc = 2 ] && { echo "The check failed (no network?): void-update -c on the desktop"; exit 1; }
        n=$(count)
        if [ "$n" -gt 0 ]; then echo "$n updates pending (run void-update on the desktop)"; exit 0; fi
        echo "No update available"; exit 7 ;;
    *)
        echo "Nothing is applied from here: $(count) updates pending; run void-update on the desktop" >&2
        exit 7 ;;
esac
EOF
chmod 755 "$UPD"

cat > "$LAN" <<EOF
[Desktop Entry]
Name=Game Mode
Name[es]=Modo Juego
Comment=Log out and enter Steam (Game Mode), like in SteamOS
Comment[es]=Cerrar la sesión y entrar en Steam (Modo Juego), como en SteamOS
Exec=$SEL gamescope
Icon=steam
Terminal=false
Type=Application
Categories=Game;
EOF

# Loading screen (steam-loading): it can be left out with --no-loading-screen (the Legion,
# 2026-10-04: "stock" boot, without own screens); the launcher already works without it.
case "${1:-}" in --no-loading-screen) NOLOAD=1 ;; *) NOLOAD= ;; esac
if [ -n "$NOLOAD" ]; then
    rm -f "$CAR"; t "== without loading screen (steam-loading removed)"
else
cat > "$CAR" <<'EOF'
#!/usr/bin/python3
# steam-loading — Game Mode's loading screen while Steam starts (installed by
# common/steam/install-game-mode.sh; docs/6-game-mode/2-game-mode.md): the same as Plymouth at power-on,
# the frames of the Plymouth theme in use (Theme= of /etc/plymouth/plymouthd.conf; bgrt-void if there is
# none) at the same place as two-step draws them, with the firmware logo when the theme uses it
# (UseFirmwareBackground) and at its height (VerticalAlignment).
# Plymouth cannot stay on screen here: lightdm closes it when the session starts and the screen belongs
# to gamescope.
# It closes EVENT-DRIVEN: it listens to the list of windows that gamescope publishes in X
# (GAMESCOPE_FOCUSABLE_WINDOWS: window, appid, pid…; xprop -spy only wakes up when it changes) and
# ends when a window of another program that is not mangoapp appears (the first one of Steam).
# In case that notice never arrived, after 3 min it closes anyway. Without X (gamescope crashed), too.
# Previous (Spanish) name: steam-cargando (variable CARGANDO_APPID, now LOADING_APPID).
import os, subprocess, sys, time
# First mark, before loading GTK: it separates in the log how long gamescope takes to start
# (from "launching gamescope") from how long this program takes to paint ("on screen").
print(time.strftime("== %F %T: ") + "steam-loading: starting", flush=True)
os.environ["GDK_BACKEND"] = "x11"
import gi
gi.require_version("Gtk", "3.0"); gi.require_version("GdkX11", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, GdkX11

def plymouth_theme():
    try:
        for line in open("/etc/plymouth/plymouthd.conf"):
            if line.strip().startswith("Theme="):
                return line.split("=", 1)[1].strip()
    except OSError:
        pass
    return "bgrt-void"
THEME = "/usr/share/plymouth/themes/" + plymouth_theme()
# A loading screen of its own, different from the power-on one: frames and a steam-loading.plymouth in this
# folder (common/boot/install-plymouth.sh --loading-…). Without it, the Plymouth theme in use.
if os.path.isfile("/usr/local/share/steam-loading/steam-loading.plymouth"):
    THEME = "/usr/local/share/steam-loading"

def theme_option(key, default):
    # [two-step] options of the theme in use, so this screen matches Plymouth: with or without the
    # firmware logo (UseFirmwareBackground) and the height of the animation (VerticalAlignment).
    try:
        for line in open(f"{THEME}/{os.path.basename(THEME)}.plymouth"):
            if line.strip().startswith(key + "="):
                return line.split("=", 1)[1].strip()
    except OSError:
        pass
    return default
FIRMWARE_LOGO = theme_option("UseFirmwareBackground", "true").lower() == "true"
try: VALIGN = float(theme_option("VerticalAlignment", ".7"))
except ValueError: VALIGN = .7
BGRT = "/sys/firmware/acpi/bgrt"
MAXIMUM = 180           # s: safety deadline
IGNORE = {"mangoapp", "steam-loading", "python3"}

def log(m): print(time.strftime("== %F %T: ") + "steam-loading: " + m, flush=True)

def read(n):
    try: return open(f"{BGRT}/{n}").read().strip()
    except OSError: return ""

frames = []
i = 1
while True:
    p = f"{THEME}/throbber-{i:04d}.png"
    if not os.path.exists(p):
        break
    try:
        frames.append(GdkPixbuf.Pixbuf.new_from_file(p))
        i += 1
    except GLib.Error:
        break
logo = None
if FIRMWARE_LOGO:
    try:
        logo = GdkPixbuf.Pixbuf.new_from_file(f"{BGRT}/image")
    except GLib.Error:
        pass
lx, ly = int(read("xoffset") or -1), int(read("yoffset") or -1)

win = Gtk.Window()
win.set_decorated(False)
# Screen size from the start: with the default window size (200x200) the first frames came out small in
# the top-left corner, cropped, before the window became full screen (photo, Legion, 2026-10-16).
_scr = Gdk.Screen.get_default()
SW, SH = _scr.get_width(), _scr.get_height()
win.set_default_size(SW, SH)
win.move(0, 0)
area = Gtk.DrawingArea()
win.add(area)
step = [0]

def draw(w, cr):
    W, H = w.get_allocated_width(), w.get_allocated_height()
    cr.set_source_rgb(0, 0, 0); cr.paint()
    if W < SW or H < SH:
        return False                       # not full screen yet: only black, never a cropped logo
    if logo:
        x, y = lx, ly
        if x < 0 or y < 0 or x + logo.get_width() > W or y + logo.get_height() > H:
            x, y = (W - logo.get_width()) // 2, (H - logo.get_height()) * 382 // 1000
        Gdk.cairo_set_source_pixbuf(cr, logo, x, y); cr.paint()
    if frames:
        f = frames[step[0] % len(frames)]
        # Where two-step puts it: the centre at VerticalAlignment of the height (.7 in bgrt).
        Gdk.cairo_set_source_pixbuf(cr, f, (W - f.get_width()) // 2, round(H * VALIGN) - f.get_height() // 2)
        cr.paint()
    return False
area.connect("draw", draw)

def spin():
    step[0] += 1; area.queue_draw(); return True
GLib.timeout_add(33, spin)

def leave(reason):
    log(reason); Gtk.main_quit(); return False

def name(pid):
    try: return open(f"/proc/{pid}/comm").read().strip()
    except OSError: return ""

def notice(source, cond):
    line = source.readline()
    if not line:
        return False                       # xprop ended (no X): the deadline or Gtk closes it
    nums = [int(n) for n in line.replace(",", " ").split("=")[-1].split() if n.isdigit()]
    for i in range(0, len(nums) - 2, 3):
        window, pid = nums[i], nums[i + 2]
        if window != xid and pid != os.getpid() and name(pid) not in IGNORE:
            leave(f"the window of {name(pid) or pid} appeared; leaving")
            return False
    return True

win.connect("destroy", Gtk.main_quit)
win.fullscreen()
win.show_all()
xid = win.get_window().get_xid()
# With gamescope -e (integration with Steam) only windows with a Steam game number count
# (STEAM_GAME), and gamescope shows the one that Steam tells it (GAMESCOPECTRL_BASELAYER_APPID, on the root):
# without both things, black screen (tested on 2026-10-03). It is given an own number (7) and, on
# exit, the root's is removed if it is still ours: Steam sets it when it has its interface.
APPID = os.environ.get("LOADING_APPID", os.environ.get("CARGANDO_APPID", "7"))
xprop = lambda *a: subprocess.run(["xprop", *a], capture_output=True, text=True).stdout
xprop("-id", str(xid), "-f", "STEAM_GAME", "32c", "-set", "STEAM_GAME", APPID)
xprop("-root", "-f", "GAMESCOPECTRL_BASELAYER_APPID", "32c", "-set", "GAMESCOPECTRL_BASELAYER_APPID", APPID)
spy = subprocess.Popen(["xprop", "-root", "-spy", "GAMESCOPE_FOCUSABLE_WINDOWS"],
                       stdout=subprocess.PIPE, text=True, bufsize=1)
GLib.io_add_watch(spy.stdout, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, notice)
GLib.timeout_add_seconds(MAXIMUM, leave, f"{MAXIMUM} s without notice from Steam; leaving")
log(f"on screen (window {xid:#x})")
Gtk.main()
spy.kill()
if xprop("-root", "GAMESCOPECTRL_BASELAYER_APPID").strip().endswith("= " + APPID):
    xprop("-root", "-remove", "GAMESCOPECTRL_BASELAYER_APPID")
EOF
fi
if [ -f "$CAR" ]; then chmod 755 "$CAR"; fi

mkdir -p "${BRI%/*}"
cat > "$BRI" <<'EOF'
#!/bin/sh
# Game Mode's sudo (installed by common/steam/install-game-mode.sh; it is only in steam-game-mode's PATH).
# Steam changes the brightness with "echo N | sudo -n tee /sys/class/backlight/<x>/brightness". That exact
# command is turned into elogind's SetBrightness: without privileges, only for the session on
# screen. Anything else goes to the real sudo, with its usual rules (password).
# Each brightness received is recorded in ~/.local/state/steam-game-mode.log.
if [ $# = 3 ] && [ "$1" = -n ] && [ "$2" = tee ]; then
    case "$3" in /sys/class/backlight/*/brightness)
        d=${3#/sys/class/backlight/}; d=${d%/brightness}
        case "$d" in
            ""|.*|*[!A-Za-z0-9_.-]*) ;;                       # odd name: to the real sudo
            *)  read -r n
                case "$n" in ""|*[!0-9]*) exit 1 ;; esac
                echo "== $(date '+%F %T'): brightness $n ($d)" >> "$HOME/.local/state/steam-game-mode.log"
                exec busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
                    org.freedesktop.login1.Session SetBrightness ssu backlight "$d" "$n" ;;
        esac ;;
    esac
fi
exec /usr/bin/sudo "$@"
EOF
chmod 755 "$BRI"

setcap cap_sys_nice=eip /usr/bin/gamescope
t "== installed:"; ls -la "$BIN" "$SES" "$SEL" "$UPD" "$LAN" "$BRI"; ls -la "$CAR" 2>/dev/null || t "   (without loading screen)"; getcap /usr/bin/gamescope
t "   keyboard in gamescope: %s" "$(sed -n 's/.*"XkbLayout"[[:space:]]*"\([^"]*\)".*/\1/p' /etc/X11/xorg.conf.d/00-keyboard.conf)"
t "== From Xfce: 'Game Mode' launcher (with install-passwordless-switch.sh, without password)."
