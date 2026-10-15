# shellcheck shell=bash
# shellcheck disable=SC2154  # configuration and colors: defined in base.sh (void-update sources them together)
# summary.sh — the SUMMARY at the end of an update (and of "void-update --summary"): one line per check with
# OK / REPAIRED / WARNING / NOTE (2026-10-04; short lines since 2026-10-14), so as not to have to read everything above. It repairs only what is safe
# (the same that its installer would do): the Legion's TDP DKMS module on a 6.18 kernel and gamescope's
# capability. The rest it only warns about, saying what to do. Each check shows up only if the piece exists.
# It includes what is built here or brought from outside xbps (2026-10-08): packages from local repositories
# against Void's version, steamos-manager, extest, InputPlumber and the gamescope portal. Since 2026-10-09, for
# each piece with our own patch (xfdesktop, Thunar, gamescope, xdg-desktop-portal-wlr, steamos-manager) it
# TESTS the patch against the new code (~/.local/bin/patch-still-needed, cache in ~/.cache/void-update/patches).
# Ported from update-system.fish (2026-10-11), same checks and same texts.

VU_PATCHES="${VU_PATCHES:-${XDG_DATA_HOME:-$HOME/.local/share}/void-update/patches}"
VU_PATCH_TEST="${VU_PATCH_TEST:-$HOME/.local/bin/patch-still-needed}"
VU_REPLACED=()         # local packages that this update replaces (set by vu_local_warning)
VU_NEW_FILES=0         # .new-* templates found in /etc
VU_REBOOT=""           # why a reboot is advisable, or empty

# Names of the packages installed from a local repository (without http/https/ftp): those built here with
# xbps-src (on the Legion, gamescope and xdg-desktop-portal-wlr, from hostdir/binpkgs). Generic: any other one
# built like that shows up by itself.
vu_locals() {
    xbps-query --regex -p repository -s . 2>/dev/null | grep -Ev ': (https?|ftp)://' | sed -E 's/-[^-]*: .*$//'
}

# How each known local package is rebuilt with its patch. <repo> = the folder of this repository's clone.
vu_how_to_rebuild() {
    local n=$1 c
    case "$n" in
        gamescope|gamescope-dbg)
            c=$(t "%s, install and %s (docs/7-apps/1-screen-sharing.md, \"In Game Mode\")" 'bash <repo>/common/steam/gamescope-patch/build-gamescope.sh' 'sudo setcap cap_sys_nice=eip /usr/bin/gamescope') ;;
        xdg-desktop-portal-wlr)
            c=$(t "%s, install and restart the portal (docs/7-apps/1-screen-sharing.md)" 'bash <repo>/legion/portal-wlr-patch/build-portal-wlr.sh') ;;
        Thunar|Thunar-devel)
            c=$(t "%s (installs the Thunar-*.xbps of that folder) and, as the user, %s; if Void already has an equal or higher version or revision, first %s (same folder; it tests the patch first and does not build if Void already brings it) and copy the new .xbps there (docs/5-desktop/4-wallpaper.md)" 'sudo bash <repo>/common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh' 'thunar -q' 'bash build-thunar.sh') ;;
        xfdesktop)
            c=$(t "%s (installs the .xbps of that folder); if Void already has an equal or higher version or revision, first %s (same folder; it tests the patch first and does not build if Void already brings it) and copy the new .xbps there (docs/5-desktop/4-wallpaper.md)" 'sudo bash <repo>/common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh' 'bash build-xfdesktop.sh') ;;
        *)
            c=$(t "it is not known with which script %s was built: look for it in docs/ (and add it to vu_how_to_rebuild, common/void-update/lib/summary.sh)" "$n") ;;
    esac
    # The scripts only clone void-packages if it is not there: with an old copy they would build the old template
    [ -d ~/src/void-packages ] && c="$c$(t "; careful: ~/src/void-packages already exists and the script does not update it (delete it first)")"
    printf '%s\n' "$c"
}

# Package of the template (and folder of patches) of a subpackage built here.
vu_base() { case "$1" in gamescope-dbg) echo gamescope ;; Thunar-devel) echo Thunar ;; *) echo "$1" ;; esac; }

# How to go back to Void's package (without the patch) when Void already brings the change. xbps-install -f
# installs the repository's one even if the one here has a higher revision (tested with -n on 2026-10-09).
vu_how_to_go_back() {
    local b; b=$(vu_base "$1")
    case "$b" in
        gamescope) echo "sudo xbps-install -Sf gamescope && sudo setcap cap_sys_nice=eip /usr/bin/gamescope" ;;
        Thunar) echo "sudo xbps-install -Sf Thunar && thunar -q" ;;
        xdg-desktop-portal-wlr) echo "sudo xbps-install -Sf xdg-desktop-portal-wlr && pkill -u \$USER -f '^/usr/libexec/xdg-desktop-portal-wlr'" ;;
        *) echo "sudo xbps-install -Sf $b" ;;
    esac
}

# Is our own patch of a package still needed? It TESTS it against the code of Void's template
# (patch-still-needed). Prints "STATE|tested version|detail" (STILL_NEEDED, ALREADY_INCLUDED, PARTIAL,
# CONFLICT or UNCHECKED, e.g. without network).
vu_test_patch() {
    local n=$1 hint=${2:-} b r args=()
    b=$(vu_base "$n")
    shopt -s nullglob; local patches=("$VU_PATCHES/$b"/0*.patch); shopt -u nullglob
    if [ ! -x "$VU_PATCH_TEST" ] || [ ${#patches[@]} -eq 0 ]; then
        echo "UNCHECKED|?|$(t "the patch test is not installed (%s, docs/8-maintenance/2-own-patches.md)" common/patch-test/install-patch-test.sh)"; return 0
    fi
    [ -n "$hint" ] && args=(--version "$hint")
    r=$(timeout 900 "$VU_PATCH_TEST" "${args[@]}" void "$b" "${patches[@]}" 2>/dev/null | grep '^RESULT ' | tail -1)
    [ -n "$r" ] || { echo "UNCHECKED|?|$(t "the test did not finish")"; return 0; }
    # RESULT <name> <version> <STATE> <detail…>
    set -- $r
    local st=$4 ver=$3; shift 4
    echo "$st|$ver|$*"
}

# Version of a package in Void's remote repositories (only the configured http/https/ftp ones; data of the
# last sync, without network).
vu_void_version() {
    local repos=() r
    while read -r r; do repos+=("--repository=$r"); done < <(xbps-query -L 2>/dev/null | grep -oE '(https?|ftp)://[^ ]+')
    [ ${#repos[@]} -gt 0 ] || return 1
    xbps-query -i -R "${repos[@]}" -p pkgver "$1" 2>/dev/null
}

# Warns BEFORE confirming if the update replaces some package built here (Void's does not carry the patch).
# Receives the lines of xbps-install -un; leaves the names in VU_REPLACED for the summary.
vu_local_warning() {
    VU_REPLACED=()
    local locals l new n before from st ver det
    locals=$(vu_locals); [ -n "$locals" ] || return 0
    for l in "$@"; do
        new=${l%% *}; n=$(printf '%s\n' "$new" | vu_pkgname)
        printf '%s\n' "$locals" | grep -qxF "$n" || continue
        VU_REPLACED+=("$n")
        before=$(xbps-query -p pkgver "$n" 2>/dev/null)
        IFS='|' read -r st ver det <<< "$(vu_test_patch "$n" "${new#"$n-"}")"
        from="(${before#"$n-"} → ${new#"$n-"})"
        echo
        if [ "$st" = ALREADY_INCLUDED ]; then
            echo "${c_green}✓ $(t "Void will replace the patched %s %s and its code (%s) ALREADY BRINGS the patch (tested): it can be updated without losing anything." "$n" "$from" "$ver")${c_off}"
            continue
        fi
        printf '%s' "$c_yellow"
        case "$st" in
            STILL_NEEDED)
                echo "⚠ $(t "Void will replace the patched %s %s: Void's does not carry the patch (tested on its code, %s)." "$n" "$from" "$ver")"
                echo "  $(t "After updating, rebuild: %s" "$(vu_how_to_rebuild "$n")")" ;;
            CONFLICT|PARTIAL)
                echo "⚠ $(t "Void will replace the patched %s %s and the patch can NOT be used as it is on its code (%s): %s." "$n" "$from" "$ver" "$det")"
                echo "  $(t "Review the patch before rebuilding: %s" "$(vu_how_to_rebuild "$n")")" ;;
            *)
                echo "⚠ $(t "Void will replace the patched %s %s; unchecked whether its code already brings it (%s)." "$n" "$from" "$det")"
                echo "  $(t "After updating, rebuild: %s" "$(vu_how_to_rebuild "$n")")" ;;
        esac
        echo "  $(t "To keep the patched one (without Void's fixes): answer n and %s" "sudo xbps-pkgdb -m hold $n")"
        printf '%s' "$c_off"
    done
}

# Short names for the summary's name column (half a terminal; 2026-10-14)
vu_short_name() { case "$1" in xdg-desktop-portal-wlr) echo portal-wlr ;; steamos-manager) echo steamos-mgr ;; *) echo "$1" ;; esac; }

# A summary line ("STATE|name|short|detail") for a package built here: the short text fits the line; the detail
# says which patch it carries, what is lost without it and what to do.
vu_local_line() {
    local n=$1 patch=$2 loss=$3 ver repo how void from_void=0 st='' pver='' det='' tested='' short_t='' back cmp
    ver=$(xbps-query -p pkgver "$n" 2>/dev/null); [ -n "$ver" ] || return 0
    repo=$(xbps-query -p repository "$n" 2>/dev/null)
    how=$(vu_how_to_rebuild "$n")
    void=$(vu_void_version "$n")
    [[ "$repo" =~ ^(https?|ftp):// ]] && from_void=1
    if [ -n "$void" ] && { [ "$void" != "$ver" ] || [ $from_void = 1 ]; }; then
        IFS='|' read -r st pver det <<< "$(vu_test_patch "$n" "${void#"$n-"}")"
    fi
    case "$st" in
        STILL_NEEDED) tested=$(t "; the patch is still needed (tested on Void's code %s)" "$pver"); short_t=$(t "patch still needed") ;;
        ALREADY_INCLUDED) tested=" $(t "(tested on Void's code %s)" "$pver")" ;;
        CONFLICT|PARTIAL) tested=" $(t "(on Void's code %s, the patch cannot be used as it is: %s)" "$pver" "$det")" ;;
        UNCHECKED) tested=" $(t "(patch unchecked on Void's code: %s)" "$det")"; short_t=$(t "patch unchecked") ;;
    esac
    back=$(vu_how_to_go_back "$n")
    if [ $from_void = 1 ]; then
        case "$st" in
            ALREADY_INCLUDED) echo "OK|$(vu_short_name "$n")|$(t "Void's, already fixed")|$(t "%s is Void's, which already brings %s%s" "$ver" "$patch" "$tested")" ;;
            CONFLICT|PARTIAL) echo "WARNING|$(vu_short_name "$n")|$(t "WITHOUT patch: review it")|$(t "%s is Void's, WITHOUT %s: %s. Review the patch before rebuilding%s. Then: %s" "$ver" "$patch" "$loss" "$tested" "$how")" ;;
            *) echo "WARNING|$(vu_short_name "$n")|$(t "WITHOUT patch: rebuild")|$(t "%s is Void's, WITHOUT %s: %s. Rebuild: %s%s" "$ver" "$patch" "$loss" "$how" "$tested")" ;;
        esac
        return 0
    fi
    if [ -z "$void" ]; then echo "OK|$(vu_short_name "$n")|$(t "patched (not in Void)")|$(t "%s with %s (built here; Void does not have it)" "$ver" "$patch")"; return 0; fi
    xbps-uhelper cmpver "$ver" "$void"; cmp=$?
    case "$st" in
        ALREADY_INCLUDED)
            if [ $cmp -eq 255 ]; then
                echo "NOTE|$(vu_short_name "$n")|$(t "Void already has the fix")|$(t "%s with %s (built here). NOTE: Void has %s, which already brings it%s: the next update replaces it without losing anything" "$ver" "$patch" "$void" "$tested")"
            else
                echo "NOTE|$(vu_short_name "$n")|$(t "Void already has the fix")|$(t "%s with %s (built here). NOTE: Void already brings it%s: one can go back to Void's (%s) with %s" "$ver" "$patch" "$tested" "$void" "$back")"
            fi
            return 0 ;;
        CONFLICT|PARTIAL)
            echo "WARNING|$(vu_short_name "$n")|$(t "patch does not fit Void")|$(t "%s with %s (built here; in Void, %s)%s. Review the patch before the next rebuild: %s" "$ver" "$patch" "$void" "$tested" "$how")"
            return 0 ;;
    esac
    case $cmp in
        1) echo "OK|$(vu_short_name "$n")|${short_t:-$(t "patched")}|$(t "%s with %s (built here; in Void, %s)%s" "$ver" "$patch" "$void" "$tested")" ;;
        0) # The scripts build with Void's revision + 1: if Void reaches the same one, it is a newer build of
           # its own (e.g. because of a new library) that xbps does not install.
           echo "WARNING|$(vu_short_name "$n")|$(t "Void rebuilt it: rebuild")|$(t "Void published %s, the same version and revision as the patched one here: xbps does not install it, but it brings changes from Void that are missing here. Rebuild to have them with %s: %s%s" "$void" "$patch" "$how" "$tested")" ;;
        *) echo "WARNING|$(vu_short_name "$n")|$(t "Void newer: patch lost")|$(t "Void has %s, newer than the patched %s: the next update replaces it WITHOUT %s (unless it is held). Rebuild afterwards: %s%s" "$void" "$ver" "$patch" "$how" "$tested")" ;;
    esac
}

# Libraries that an executable or library does not find (ldd "not found").
vu_missing() { for f in "$@"; do ldd "$f" 2>/dev/null | sed -nE 's/^\s*(\S+) => not found.*/\1/p'; done | sort -u; }

# For --summary: whether a reboot is advisable, known without the update's list (glibc installed after booting).
vu_reboot_since_boot() {
    local latest boot glibc
    latest=$(ls /usr/lib/modules | sort -V | tail -1)
    if [ "$latest" != "$(uname -r)" ]; then t "kernel %s installed, %s is running" "$latest" "$(uname -r)"; return 0; fi
    boot=$(sed -n 's/^btime //p' /proc/stat)
    glibc=$(date -d "$(xbps-query -p install-date glibc)" +%s 2>/dev/null)
    [ -n "$glibc" ] && [ "$glibc" -gt "$boot" ] && t "glibc updated after booting"
    return 0
}

# vu_summary [--no-repair] [--verbose]: the final summary, one short line per check (name and state; 2026-10-14,
# the user's request: each check on one line). The detail (what it is, what to do) is printed under it only for
# WARNING, REPAIRED and NOTE, or for all with --verbose (void-update --summary -v). With --no-repair it does not
# use sudo: what it would repair, it warns about. Each entry of "lines": STATE|name|short|detail.
vu_summary() {
    local repair=1 verbose=0 lines=() latest a
    for a in "$@"; do case "$a" in --no-repair) repair=0 ;; --verbose) verbose=1 ;; esac; done
    latest=$(ls /usr/lib/modules | sort -V | tail -1)

    # The Legion's TDP modules (DKMS, they only build for 6.18) and the kernel hold
    if command -v dkms >/dev/null && [ -n "$(dkms status -m lenovo-wmi-tdp 2>/dev/null)" ]; then
        if dkms status -m lenovo-wmi-tdp -k "$latest" 2>/dev/null | grep -q installed; then
            lines+=("OK|TDP|$(t "for %s" "$latest")|$(t "TDP (lenovo-wmi-tdp) built for %s" "$latest")")
        elif [[ "$latest" =~ ^6\.18\. ]]; then
            if [ $repair = 0 ]; then
                lines+=("WARNING|TDP|$(t "not built (%s)" "$latest")|$(t "TDP (lenovo-wmi-tdp) not built for %s: %s (void-update does it by itself)" "$latest" "sudo dkms autoinstall -k $latest")")
            elif sudo dkms autoinstall -k "$latest" >/dev/null 2>&1 && dkms status -m lenovo-wmi-tdp -k "$latest" | grep -q installed; then
                lines+=("REPAIRED|TDP|$(t "rebuilt (%s)" "$latest")|$(t "TDP (lenovo-wmi-tdp) rebuilt for %s" "$latest")")
            else
                lines+=("WARNING|TDP|$(t "does NOT build (%s)" "$latest")|$(t "TDP (lenovo-wmi-tdp) does NOT build for %s: the error is in %s. Until it is fixed, that kernel (the one the hidden GRUB boots) has no fine TDP; to boot the previous one, %s (docs/1-platform/3-boot.md). Fix: docs/3-hardware-support/2-power.md, \"Fine TDP\"" "$latest" '/var/lib/dkms/lenovo-wmi-tdp/*/build/make.log' 'grub-hidden.sh --remove')")
            fi
        else
            lines+=("WARNING|TDP|$(t "kernel not 6.18")|$(t "the newest kernel (%s) is not of the 6.18 series: on it the Legion has no fine TDP control (the modules are only for 6.18). Boot the 6.18 one or bring its sources (docs/3-hardware-support/2-power.md)" "$latest")")
        fi
        if xbps-query -H 2>/dev/null | grep -qE '^linux-[0-9]'; then
            lines+=("OK|kernel|$(t "held")|$(t "kernel held in its series: it will not change series by itself")")
        else
            lines+=("WARNING|kernel|$(t "not held")|$(t "the kernel could move to another series in an update and the Legion would lose the fine TDP control. To avoid it: %s" 'sudo xbps-pkgdb -m hold linux linux-headers')")
        fi
    fi

    # Kernel series: the one Void recommends (the repository's "linux" metapackage) against the installed one.
    local recommended series
    recommended=$(xbps-query -R -p pkgver linux 2>/dev/null | sed -E 's/^linux-([0-9]+\.[0-9]+).*/\1/')
    series=$(sed -E 's/^([0-9]+\.[0-9]+).*/\1/' <<< "$latest")
    if [ -n "$recommended" ]; then
        if [ "$recommended" = "$series" ]; then lines+=("OK|kernel|$(t "%s, Void's" "$series")|$(t "kernel of the %s series, the one Void recommends" "$series")")
        else lines+=("WARNING|kernel|$(t "%s; Void: %s" "$series" "$recommended")|$(t "Void already recommends the %s series of the kernel; here it is still %s. Changing is your decision (on the Legion: release the hold and bring the TDP modules of that series)" "$recommended" "$series")"); fi
    fi

    # gamescope loses cap_sys_nice when it is updated (Game Mode; steam-modo-juego = the launcher's old name)
    if { [ -x /usr/local/bin/steam-game-mode ] || [ -x /usr/local/bin/steam-modo-juego ]; } && [ -x /usr/bin/gamescope ]; then
        if getcap /usr/bin/gamescope | grep -q cap_sys_nice; then lines+=("OK|gamescope|cap_sys_nice|$(t "gamescope with cap_sys_nice")")
        elif [ $repair = 0 ]; then lines+=("WARNING|gamescope|$(t "without cap_sys_nice")|$(t "gamescope without cap_sys_nice: %s (void-update does it by itself)" 'sudo setcap cap_sys_nice=eip /usr/bin/gamescope')")
        elif sudo setcap cap_sys_nice=eip /usr/bin/gamescope && getcap /usr/bin/gamescope | grep -q cap_sys_nice; then lines+=("REPAIRED|gamescope|$(t "cap_sys_nice given back")|$(t "gamescope: cap_sys_nice given back")")
        else lines+=("WARNING|gamescope|$(t "without cap_sys_nice")|$(t "gamescope without cap_sys_nice (%s)" 'sudo setcap cap_sys_nice=eip /usr/bin/gamescope')"); fi
    fi

    # Packages built here with a patch (local repository), one line each. The known ones always show up as long
    # as their piece is there; the others, while they are local or if this update replaced them.
    local known=() n l
    if [ -d /usr/local/share/xdg-desktop-portal/gamescope-portals ] && [ -x /usr/bin/gamescope ]; then
        known+=(gamescope); l=$(vu_local_line gamescope "$(t "the PipeWire patch")" "$(t "Game Mode may crash when sharing the screen")"); [ -n "$l" ] && lines+=("$l")
    fi
    if [ -f ~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service ]; then
        known+=(xdg-desktop-portal-wlr); l=$(vu_local_line xdg-desktop-portal-wlr "$(t "the windows patch")" "$(t "Vesktop will ask again several times when sharing a window")"); [ -n "$l" ] && lines+=("$l")
    fi
    if [ -f ~/.config/xfce4/labwc/rc.xml ] && xbps-query xfdesktop >/dev/null 2>&1; then
        known+=(xfdesktop); l=$(vu_local_line xfdesktop "$(t "the fix of the wallpaper dialog on Wayland")" "$(t "on Xfce Wayland, choosing a wallpaper in the dialog does nothing")"); [ -n "$l" ] && lines+=("$l")
    fi
    if [ -f ~/.config/xfce4/labwc/rc.xml ] && xbps-query Thunar >/dev/null 2>&1; then
        known+=(Thunar); l=$(vu_local_line Thunar "$(t "the fix of \"Set as wallpaper\" on Wayland")" "$(t "on Xfce Wayland, that Thunar menu does not change the wallpaper")"); [ -n "$l" ] && lines+=("$l")
    fi
    for n in $(vu_locals) "${VU_REPLACED[@]}"; do
        printf '%s\n' "${known[@]}" | grep -qxF "$n" && continue
        known+=("$n"); l=$(vu_local_line "$n" "$(t "its patch")" "$(t "what it fixed is lost")"); [ -n "$l" ] && lines+=("$l")
    done

    # Programs that do not come from xbps (official binaries): that they still find their libraries
    local missing
    if [ -e /usr/bin/inputplumber ] && [ -z "$(xbps-query -o /usr/bin/inputplumber 2>/dev/null)" ]; then
        missing=$(vu_missing /usr/bin/inputplumber | tr '\n' ' ' | sed 's/ $//')
        if [ -z "$missing" ]; then lines+=("OK|InputPlumber|$(t "libraries ok")|$(t "InputPlumber finds its libraries")")
        else lines+=("WARNING|InputPlumber|$(t "missing: %s" "$missing")|$(t "InputPlumber (official binary) does NOT find: %s. Install the Void package that provides it (%s) or move to a version of InputPlumber that uses the current one and repeat %s (docs/3-hardware-support/1-controllers.md)" "$missing" "xbps-query -Ro '*/<library>'" legion/install-inputplumber.sh)"); fi
    fi
    if [ -e /usr/local/lib/xdg-desktop-portal-gamescope ]; then
        missing=$(vu_missing /usr/local/lib/xdg-desktop-portal-gamescope | tr '\n' ' ' | sed 's/ $//')
        if [ -z "$missing" ]; then lines+=("OK|portal-gs|$(t "libraries ok")|$(t "gamescope portal finds its libraries")")
        else lines+=("WARNING|portal-gs|$(t "missing: %s" "$missing")|$(t "gamescope portal (Valve's binary) does NOT find: %s. It only depends on glibc: install what is missing, or bring the one of a new SteamOS version and repeat %s (docs/7-apps/1-screen-sharing.md, \"In Game Mode\")" "$missing" common/steam/portal-gamescope/install-portal-gamescope.sh)"); fi
    fi

    # steamos-manager (built here with a patch, outside xbps): libraries, reference sha256, build dependencies,
    # which package it is, and whether upstream published a new version that still needs the patch.
    if [ -e /usr/lib/steamos-manager ]; then
        local bad=() dir=/usr/local/share/steamos-manager-void pkg='' name ref sum='' deps=() p note='' tag url newest r
        if [ -f $dir/package ]; then pkg=$(head -1 $dir/package | tr -d '[:space:]'); elif [ -f $dir/paquete ]; then pkg=$(head -1 $dir/paquete | tr -d '[:space:]'); fi
        if [ -z "$pkg" ]; then name=$(t "unknown package (repeat %s to record it)" install-steamos-manager.sh)
        elif [[ "$pkg" == *-void ]]; then name=$(t "package %s (the official one, WITHOUT the set_clocks patch: \"Error setting manual GPU clock\" in the log with the manual clock disabled; the patched one is …-void-2)" "$pkg")
        else name=$(t "package %s" "$pkg"); fi
        missing=$(vu_missing /usr/lib/steamos-manager /usr/bin/steamosctl | tr '\n' ' ' | sed 's/ $//')
        [ -n "$missing" ] && bad+=("$(t "does NOT find %s: rebuild with %s and install with %s (the build dependencies are installed on purpose; docs/6-game-mode/3-steamos-manager.md)" "$missing" 'common/steam/steamos-manager/build-steamos-manager.sh /tmp' install-steamos-manager.sh)")
        ref=$dir/sha256
        if [ ! -f $ref ]; then bad+=("$(t "without reference sha256 (%s): it cannot be known whether it is the patched one (repeat %s)" "$ref" install-steamos-manager.sh)")
        elif ! sha256sum -c --status $ref 2>/dev/null; then bad+=("$(t "the installed one is NOT the reference one (sha256 different from that of %s): repeat %s" "$ref" install-steamos-manager.sh)")
        else sum=$(grep '/usr/lib/steamos-manager$' $ref | cut -c1-8); fi
        for p in glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config git make; do xbps-query $p >/dev/null 2>&1 || deps+=("$p"); done
        [ ${#deps[@]} -gt 0 ] && bad+=("$(t "to rebuild it, missing: %s" "sudo xbps-install -S ${deps[*]}")")
        [ -x ~/.cargo/bin/cargo ] || bad+=("$(t "to rebuild it, missing Rust from rustup (~/.cargo/bin/cargo; docs/6-game-mode/8-controller-on-desktop.md)")")
        tag=$(grep -oE 'v[0-9][0-9.]*[0-9]' <<< "$pkg" | head -1)
        url=https://gitlab.steamos.cloud/holo/steamos-manager.git
        newest=$(timeout 30 git ls-remote --tags --refs "$url" 'v*' 2>/dev/null | sed -nE 's#.*refs/tags/(v[0-9]+(\.[0-9]+)*)$#\1#p' | sort -V | tail -1)
        shopt -s nullglob; local smp=("$VU_PATCHES/steamos-manager"/0*.patch); shopt -u nullglob
        if [ -z "$newest" ]; then note=$(t "; unchecked whether there is a new version (without network)")
        elif [ -n "$tag" ] && [ "$newest" != "$tag" ]; then
            if [ -x "$VU_PATCH_TEST" ] && [ ${#smp[@]} -gt 0 ]; then
                r=$(timeout 900 "$VU_PATCH_TEST" git "$url" "$newest" steamos-manager "${smp[@]}" 2>/dev/null | grep '^RESULT ' | tail -1)
                set -- $r
                case "${4:-}" in
                    STILL_NEEDED) note=$(t "; NOTE: upstream published %s and the patch is still needed (tested): to move to it, rebuild with %s changing VER and COMMIT" "$newest" build-steamos-manager.sh) ;;
                    ALREADY_INCLUDED) note=$(t "; NOTE: upstream published %s and it already brings the patch's change (tested): one can move to it without the patch" "$newest") ;;
                    CONFLICT|PARTIAL) shift 4; note=$(t "; NOTE: upstream published %s and the patch cannot be used as it is (%s): review it before moving to it" "$newest" "$*") ;;
                    *) note=$(t "; NOTE: upstream published %s (patch unchecked)" "$newest") ;;
                esac
            else note=$(t "; NOTE: upstream published %s (without the patch test installed)" "$newest"); fi
        fi
        if [ ${#bad[@]} -eq 0 ] && [ -z "$note" ]; then lines+=("OK|steamos-mgr|$(t "the reference one")|$(t "steamos-manager, %s: finds its libraries, is the reference one (sha256 %s…) and its build dependencies are there%s" "$name" "$sum" "$note")")
        elif [ ${#bad[@]} -eq 0 ]; then lines+=("NOTE|steamos-mgr|$(t "new upstream version")|$(t "steamos-manager, %s: finds its libraries, is the reference one (sha256 %s…) and its build dependencies are there%s" "$name" "$sum" "$note")")
        else lines+=("WARNING|steamos-mgr|$(t "%s problem(s)" "${#bad[@]}")|steamos-manager, $name: $(printf '%s; ' "${bad[@]}" | sed 's/; $//')$note"); fi
    fi

    # extest (built here with Rust from rustup, 32 bits): libraries and what is needed to rebuild it
    local extest=~/.local/lib/extest/libextest.so
    if [ -e "$extest" ]; then
        local bad=() i686
        missing=$(vu_missing "$extest" | tr '\n' ' ' | sed 's/ $//')
        [ -n "$missing" ] && bad+=("$(t "does NOT find %s: rebuild with %s (docs/6-game-mode/8-controller-on-desktop.md)" "$missing" 'cd ~/src/extest && ~/.cargo/bin/cargo build --release && install -D -m 755 target/i686-unknown-linux-gnu/release/libextest.so ~/.local/lib/extest/libextest.so')")
        i686=$(ls -d ~/.rustup/toolchains/*/lib/rustlib/i686-unknown-linux-gnu 2>/dev/null | head -1)
        [ -x ~/.cargo/bin/cargo ] || bad+=("$(t "to rebuild it, missing Rust from rustup (~/.cargo, ~/.rustup)")")
        # shellcheck disable=SC2088  # the message shows "~" literally
        [ -x ~/.cargo/bin/cargo ] && [ -z "$i686" ] && bad+=("$(t "to rebuild it, missing the 32-bit target: %s" '~/.cargo/bin/rustup target add i686-unknown-linux-gnu')")
        [ -f ~/src/extest/Cargo.lock ] || bad+=("$(t "to rebuild it, missing ~/src/extest (its code, 1.0.3: copy in %s)" legion/steam/extest/extest-1.0.3-src.tar.gz)")
        xbps-query gcc-multilib >/dev/null 2>&1 || bad+=("$(t "to rebuild it, missing: %s" 'sudo xbps-install -S gcc-multilib')")
        if [ ${#bad[@]} -eq 0 ]; then lines+=("OK|extest|$(t "can be rebuilt")|$(t "extest finds its libraries and can be rebuilt (~/.rustup, ~/.cargo, ~/src/extest, gcc-multilib)")")
        else lines+=("WARNING|extest|$(t "%s problem(s)" "${#bad[@]}")|extest: $(printf '%s; ' "${bad[@]}" | sed 's/; $//')"); fi
    fi

    # What the steps above already warned about, repeated here
    if [ "$VU_NEW_FILES" -gt 0 ] 2>/dev/null; then lines+=("WARNING|.new-*|$(t "%s in /etc" "$VU_NEW_FILES")|$(t "%s .new-* template(s) in /etc: compare, do not apply" "$VU_NEW_FILES")")
    else lines+=("OK|.new-*|$(t "none found")|$(t "no .new-* templates in /etc")"); fi
    if [ -n "$VU_REBOOT" ]; then lines+=("WARNING|$(t "reboot")|$(t "advisable")|$(t "a reboot is advisable: %s" "$VU_REBOOT")")
    else lines+=("OK|$(t "reboot")|$(t "not needed")|$(t "no reboot needed")"); fi

    echo "==> $(t "Summary")"
    local warnings=0 notes=0 state name short detail rest width sym
    # Half a terminal (2026-10-14, the user's request): symbols instead of words, a 13-column name, a short text;
    # the detail wrapped to at most 52 columns.
    width=$(( ${COLUMNS:-$(tput cols 2>/dev/null || echo 80)} - 5 )); [ $width -le 52 ] || width=52; [ $width -ge 30 ] || width=30
    for l in "${lines[@]}"; do
        state=${l%%|*}; rest=${l#*|}; name=${rest%%|*}; rest=${rest#*|}; short=${rest%%|*}; detail=${rest#*|}
        case "$state" in
            OK)       sym="$c_green✓" ;;
            NOTE)     sym="$c_green""ℹ"; notes=$((notes+1)) ;;
            REPAIRED) sym="$c_cyan↻" ;;
            *)        sym="$c_yellow⚠"; warnings=$((warnings+1)) ;;
        esac
        printf ' %s%s %-13s %s\n' "$sym" "$c_off" "$name" "$short"
        if [ -n "$detail" ] && { [ $verbose = 1 ] || [ "$state" != OK ]; }; then
            printf '%s\n' "$detail" | fold -s -w "$width" | sed 's/^/   /'
        fi
    done
    if [ $warnings -eq 0 ]; then printf '%s✓ %s%s' "$c_green" "$(t "All in order")" "$c_off"
    else printf '%s⚠ %s%s' "$c_yellow" "$(t "%s warning(s): check above" "$warnings")" "$c_off"; fi
    if [ $verbose = 0 ] && [ $warnings -eq 0 ] && [ $notes -eq 0 ]; then printf '  %s\n' "$(t "(-v: detail)")"; else echo; fi
}
