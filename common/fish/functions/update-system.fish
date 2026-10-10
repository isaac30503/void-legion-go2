# Updates Void with xbps. The idea comes from omarchy-update (Arch), adapted to Void and to what
# happened on this machine; the deliberate differences are in the recipe
# (void-ideapad-100.md, step 6; docs/reference/void-ideapad-100-steps.md in this repository). In order:
#
#  1. Syncs and shows what is going to be updated and how much it weighs; asks to confirm once. If the
#     list replaces a package built here (installed from a local repository, e.g.
#     xbps-src's hostdir/binpkgs), it warns BEFORE confirming, with the script that rebuilds it.
#  2. xbps first, alone: with an old xbps, xbps-install refuses to update anything else.
#  3. Everything else. If a new OpenSSH came in, it restarts sshd: the old one in memory cuts
#     all new connections (runit does not restart services on update).
#  4. Orphans, WITHOUT the kernels: the kernel of the previous series becomes an orphan and is the
#     backup one. omarchy-update would remove them all; here it warns and they are left.
#  5. Cache: downloaded packages that no longer match anything installed.
#  6. Loose kernels (those that belong to no package, e.g. the ISO's) with vkpurge.
#  7. .new-* files in /etc: they are only warned about, never applied (see recipe, step 1).
#  8. Flatpak and LazyVim, if they are installed.
#  9. If there is a new kernel or glibc, it warns to reboot. It never reboots by itself.
# 10. SUMMARY at the end, one line per check with OK / REPAIRED / WARNING, so as not to have to
#     read everything above (2026-10-04). It repairs only what is safe (the same that its
#     installer would do): the Legion's TDP DKMS module on a 6.18 kernel and gamescope's
#     capability. The rest it only warns about, saying what to do. Each check shows up only if the
#     piece exists. It includes what is built here or brought from outside xbps (2026-10-08): packages from
#     local repositories against Void's version, steamos-manager (which package it is, libraries,
#     reference sha256 and dependencies to rebuild it), extest (libraries and what is needed to
#     rebuild it), InputPlumber and the gamescope portal (libraries).
#     Since 2026-10-09, for each piece with our own patch (xfdesktop, Thunar, gamescope,
#     xdg-desktop-portal-wlr, steamos-manager) it TESTS the patch against the new code
#     (~/.local/bin/patch-still-needed, cache in ~/.cache/update-system/patches): whether it is still
#     needed, whether Void already brings it (and how to go back to Void's) or whether upstream rewrote that part. Also in the
#     warning before confirming. Without network: "unchecked".
#
# update-system --summary: only the summary (step 10), without syncing, without sudo and without changing anything
# (2026-10-08; --resumen also works). What "Void has" is what the last sync has; what it would repair, it warns about.
#
# Its texts follow the system's language (__vl_t, translations in ~/.local/share/void-legion; the Spanish
# ones are the original texts). Where the messages name this repository's scripts they write <repo> (the
# folder of the clone). Previous name: update-system (unchanged); the patch test was
# parche-sigue-haciendo-falta (now patch-still-needed, installed by common/patch-test/install-patch-test.sh).
function update-system --description "Update Void (xbps), clean orphans and cache, warn if a reboot is needed"
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    if contains -- "$argv[1]" --summary --resumen
        set -g __us_replaced
        set -g __us_new_files (count (find /etc -name '*.new-*' 2>/dev/null))
        set -g __us_reboot (__update_system_reboot_since_boot)
        __update_system_summary --no-repair
        return 0
    end

    echo "==> "(__vl_t "Syncing repositories")
    sudo xbps-install -S; or return 1

    # Keep sudo alive: the first update after installing took ~45 min of download,
    # and without this it would ask for the password again halfway. It ends when the mark is deleted, and
    # at most after 2 h in case the function is interrupted with Ctrl+C before deleting it.
    set -l mark (mktemp)
    bash -c 'for i in $(seq 120); do [ -e "$1" ] || exit 0; sudo -n true 2>/dev/null || exit 0; sleep 60; done' _ $mark &
    disown

    __update_system_steps
    set -l state $status
    if test $state -eq 0
        __update_system_summary
    end

    # Date of the last complete update, for fastfetch's "Updated" line
    # (xbps keeps no history; the date of its pkgdb changes with any installation)
    if test $state -eq 0
        mkdir -p ~/.local/state
        date +%s > ~/.local/state/update-system.last
    end

    rm -f $mark
    return $state
end

function __update_system_steps
    # xbps-install -un: "pkgver action arch repo installed-size download-size"
    set -l pending (xbps-install -un)
    set -l names (string split -f1 ' ' -- $pending | string replace -r -- '-[^-]*$' '')
    set -g __us_replaced

    if test (count $pending) -eq 0
        echo "✓ "(__vl_t "Packages up to date")
    else
        echo
        printf '%s\n' $pending | awk '{printf "  %-45s %s\n", $1, $2}'
        __update_system_local_warning $pending
        set -l mib (printf '%s\n' $pending | awk '{s += $6} END {printf "%.0f", s / 1048576}')
        echo
        read -l -P (__vl_t "Update %s packages (%s MiB to download)? [Y/n] " (count $pending) $mib) resp
        if string match -qri -- '^n' $resp
            __vl_t "Canceled."
            return 1
        end

        if contains -- xbps $names
            echo
            echo "==> "(__vl_t "Updating xbps first")
            sudo xbps-install -uy xbps; or return 1
        end

        echo
        echo "==> "(__vl_t "Updating the system")
        sudo xbps-install -uy; or return 1

        if contains -- openssh $names
            echo
            echo "==> "(__vl_t "OpenSSH changed: restarting sshd (the open sessions go on)")
            sudo sv restart sshd
        end
    end

    # Orphans except the kernels (linuxX.Y), which stay as backup
    set -l orphans (xbps-query -O | string replace -r -- '-[^-]*$' '')
    set -l kernels (string match -r -- '^linux[0-9.]+$' $orphans)
    set -l remove (string match -v -r -- '^linux[0-9.]+$' $orphans)
    if test -n "$remove"
        echo
        echo "==> "(__vl_t "Removing orphans (dependencies nobody uses anymore)")
        sudo xbps-remove -Ry $remove
    end
    if test -n "$kernels"
        echo
        echo "ℹ "(__vl_t "Orphan backup kernel, kept: %s" "$kernels")
        echo "  "(__vl_t "To remove it once the current one has been fine for a while: %s" "sudo xbps-remove -R $kernels")
    end

    echo
    echo "==> "(__vl_t "Cleaning the package cache")
    sudo xbps-remove -Oy

    if test -n "$(vkpurge list 2>/dev/null)"
        echo
        echo "==> "(__vl_t "Removing loose kernels: %s" (vkpurge list | string join ' '))
        sudo vkpurge rm all
    end

    set -l new_files (find /etc -name '*.new-*' 2>/dev/null)
    set -g __us_new_files (count $new_files)
    if test -n "$new_files"
        echo
        set_color yellow
        echo "⚠ "(__vl_t "New configuration templates (do NOT apply them without comparing them; the current file is the good one):")
        printf '  %s\n' $new_files
        echo "  "(__vl_t "Compare: %s   ·   Careful with passwd: the template has no users." "diff <file> <file>.new-*")
        set_color normal
    end

    if type -q flatpak
        echo
        echo "==> Flatpak"
        flatpak update -y
    end

    if type -q nvim; and test -d ~/.config/nvim
        echo
        echo "==> "(__vl_t "LazyVim: syncing Neovim's plugins")
        nvim --headless "+Lazy! sync" +qa
    end

    # Reboot: kernel newer than the running one, or glibc updated
    set -l latest (ls /usr/lib/modules | sort -V | tail -1)
    set -g __us_reboot ""
    if test "$latest" != (uname -r); or contains -- glibc $names
        set -g __us_reboot (test "$latest" != (uname -r); and __vl_t "kernel %s installed, %s is running" $latest (uname -r); or __vl_t "glibc updated")
        echo
        set_color yellow
        echo "↻ "(__vl_t "A reboot is advisable: %s" "$__us_reboot")
        set_color normal
    end

    echo
    echo "✓ "(__vl_t "Completed")
end

# Names of the packages installed from a local repository (without http/https/ftp): those built
# here with xbps-src (on the Legion, gamescope and xdg-desktop-portal-wlr, from hostdir/binpkgs). Generic:
# any other one built like that shows up by itself.
function __update_system_locals
    xbps-query --regex -p repository -s . 2>/dev/null | string match -rv -- ': (https?|ftp)://' | string replace -r -- '-[^-]*: .*$' ''
end

# How each known local package is rebuilt with its patch. <repo> = the folder of this repository's clone.
function __update_system_how_to_rebuild -a n
    set -l c
    switch $n
        case gamescope gamescope-dbg
            set c (__vl_t "%s, install and %s (Legion recipe, step 14, \"Screen sharing in Game Mode\")" 'bash <repo>/common/steam/gamescope-patch/build-gamescope.sh' 'sudo setcap cap_sys_nice=eip /usr/bin/gamescope')
        case xdg-desktop-portal-wlr
            set c (__vl_t "%s, install and restart the portal (Legion recipe, step 14, \"Portals\", point 4)" 'bash <repo>/legion/portal-wlr-patch/build-portal-wlr.sh')
        case Thunar Thunar-devel
            set c (__vl_t "%s (installs the Thunar-*.xbps of that folder) and, as the user, %s; if Void already has an equal or higher version or revision, first %s (same folder; it tests the patch first and does not build if Void already brings it) and copy the new .xbps there (step 15 of each machine's recipe, \"Desktop wallpaper on Wayland\")" 'sudo bash <repo>/common/xfce-wayland/thunar-wallpaper/install-thunar-wallpaper.sh' 'thunar -q' 'bash build-thunar.sh')
        case xfdesktop
            set c (__vl_t "%s (installs the .xbps of that folder); if Void already has an equal or higher version or revision, first %s (same folder; it tests the patch first and does not build if Void already brings it) and copy the new .xbps there (step 15 of each machine's recipe, \"Desktop wallpaper on Wayland\")" 'sudo bash <repo>/common/xfce-wayland/xfdesktop-wallpaper/install-xfdesktop-wallpaper.sh' 'bash build-xfdesktop.sh')
        case '*'
            set c (__vl_t "it is not known with which script %s was built: look for it in the recipe (and add it to __update_system_how_to_rebuild)" $n)
    end
    # The scripts only clone void-packages if it is not there: with an old copy they would build the old template
    test -d ~/src/void-packages; and set c "$c"(__vl_t "; careful: ~/src/void-packages already exists and the script does not update it (delete it first)")
    echo $c
end

# How to go back to Void's package (without the patch) when Void already brings the change. xbps-install -f installs the
# repository's one even if the one here has a higher revision (tested with -n on 2026-10-09).
function __update_system_how_to_go_back -a n
    set -l b (__update_system_base $n)
    switch $b
        case gamescope
            echo "sudo xbps-install -Sf gamescope && sudo setcap cap_sys_nice=eip /usr/bin/gamescope"
        case Thunar
            echo "sudo xbps-install -Sf Thunar && thunar -q"
        case xdg-desktop-portal-wlr
            echo "sudo xbps-install -Sf xdg-desktop-portal-wlr && pkill -u \$USER -f '^/usr/libexec/xdg-desktop-portal-wlr'"
        case '*'
            echo "sudo xbps-install -Sf $b"
    end
end

# Package of the template (and folder of patches) of a subpackage built here.
function __update_system_base -a n
    switch $n
        case gamescope-dbg
            echo gamescope
        case Thunar-devel
            echo Thunar
        case '*'
            echo $n
    end
end

# Is our own patch of a package still needed? (2026-10-09) It TESTS it against the code of Void's
# template (patch-still-needed: downloads the distfile with its checksum, applies Void's patches
# and tests ours with git apply --check and --reverse --check). Cache per version in
# ~/.cache/update-system/patches: the first time for each version it downloads the code (seconds); afterwards, nothing
# if the template is the version that the repository publishes ($hint). Returns "STATE|tested version|detail"
# (STILL_NEEDED, ALREADY_INCLUDED, PARTIAL, CONFLICT or UNCHECKED, e.g. without network).
function __update_system_test_patch -a n hint
    set -l b (__update_system_base $n)
    set -l prog ~/.local/bin/patch-still-needed
    set -l patches ~/.local/share/update-system/patches/$b/0*.patch
    if not test -x $prog; or test (count $patches) -eq 0
        echo "UNCHECKED|?|"(__vl_t "the patch test is not installed (%s, recipe step 6)" common/patch-test/install-patch-test.sh)
        return 0
    end
    set -l args
    test -n "$hint"; and set args --version $hint
    set -l r (timeout 900 $prog $args void $b $patches 2>/dev/null | string match -r '^RESULT .*')
    if test -z "$r"
        echo "UNCHECKED|?|"(__vl_t "the test did not finish")
        return 0
    end
    set -l f (string split ' ' -- $r)
    echo "$f[4]|$f[3]|"(string join ' ' -- $f[5..-1])
end

# Version of a package in Void's remote repositories (only the configured http/https/ftp ones;
# data of the last sync, without network).
function __update_system_void_version -a n
    set -l repos (xbps-query -L 2>/dev/null | string match -r -- '(?:https?|ftp)://\S+')
    test -n "$repos"; or return 1
    xbps-query -i -R --repository=$repos -p pkgver $n 2>/dev/null
end

# Step 1: warns BEFORE confirming if the update replaces some package built here (Void's
# does not carry the patch). It receives the lines of xbps-install -un: so it can be tested with a made-up
# list. It leaves the names in __us_replaced for the summary.
function __update_system_local_warning
    set -g __us_replaced
    set -l locals (__update_system_locals)
    test -n "$locals"; or return 0
    for l in $argv
        set -l new (string split -f1 ' ' -- $l)
        set -l n (string replace -r -- '-[^-]*$' '' $new)
        contains -- $n $locals; or continue
        set -a __us_replaced $n
        set -l before (xbps-query -p pkgver $n 2>/dev/null)
        set -l pr (string split '|' -- (__update_system_test_patch $n (string replace -- "$n-" '' $new)))
        set -l from "("(string replace -- "$n-" '' $before)" → "(string replace -- "$n-" '' $new)")"
        echo
        if test "$pr[1]" = ALREADY_INCLUDED
            set_color green
            echo "✓ "(__vl_t "Void will replace the patched %s %s and its code (%s) ALREADY BRINGS the patch (tested): it can be updated without losing anything." $n $from $pr[2])
            set_color normal
            continue
        end
        set_color yellow
        switch $pr[1]
            case STILL_NEEDED
                echo "⚠ "(__vl_t "Void will replace the patched %s %s: Void's does not carry the patch (tested on its code, %s)." $n $from $pr[2])
                echo "  "(__vl_t "After updating, rebuild: %s" (__update_system_how_to_rebuild $n))
            case CONFLICT PARTIAL
                echo "⚠ "(__vl_t "Void will replace the patched %s %s and the patch can NOT be used as it is on its code (%s): %s." $n $from $pr[2] "$pr[3]")
                echo "  "(__vl_t "Review the patch before rebuilding: %s" (__update_system_how_to_rebuild $n))
            case '*'
                echo "⚠ "(__vl_t "Void will replace the patched %s %s; unchecked whether its code already brings it (%s)." $n $from "$pr[3]")
                echo "  "(__vl_t "After updating, rebuild: %s" (__update_system_how_to_rebuild $n))
        end
        echo "  "(__vl_t "To keep the patched one (without Void's fixes): answer n and %s" "sudo xbps-pkgdb -m hold $n")
        set_color normal
    end
end

# A summary line for a package built here: name, which patch it carries and what is lost without it.
#
# Since 2026-10-09 it TESTS the patch against Void's code (__update_system_test_patch) when
# Void's version differs from the installed one, or when what is installed is already Void's: that way it knows, without assuming
# anything from the version number, whether the patch is still needed (STILL_NEEDED), whether Void already brings it
# (ALREADY_INCLUDED: it says how to go back to Void's) or whether upstream rewrote that part (CONFLICT / PARTIAL).
# Without network: "unchecked" and the line from before.
function __update_system_local_line -a n patch loss
    set -l ver (xbps-query -p pkgver $n 2>/dev/null)
    test -n "$ver"; or return 0
    set -l repo (xbps-query -p repository $n 2>/dev/null)
    set -l how (__update_system_how_to_rebuild $n)
    set -l void (__update_system_void_version $n)
    set -l from_void 0
    string match -qr -- '^(https?|ftp)://' $repo; and set from_void 1
    set -l pr
    if test -n "$void"; and begin; test "$void" != "$ver"; or test $from_void -eq 1; end
        set pr (string split '|' -- (__update_system_test_patch $n (string replace -- "$n-" '' $void)))
    end
    set -l st $pr[1]
    set -l tested
    switch "$st"
        case STILL_NEEDED
            set tested (__vl_t "; the patch is still needed (tested on Void's code %s)" $pr[2])
        case ALREADY_INCLUDED
            set tested " "(__vl_t "(tested on Void's code %s)" $pr[2])
        case CONFLICT PARTIAL
            set tested " "(__vl_t "(on Void's code %s, the patch cannot be used as it is: %s)" $pr[2] "$pr[3]")
        case UNCHECKED
            set tested " "(__vl_t "(patch unchecked on Void's code: %s)" "$pr[3]")
    end
    set -l back (__update_system_how_to_go_back $n)
    if test $from_void -eq 1
        switch "$st"
            case ALREADY_INCLUDED
                echo "OK|"(__vl_t "%s is Void's, which already brings %s%s" $ver $patch "$tested")
            case CONFLICT PARTIAL
                echo "WARNING|"(__vl_t "%s is Void's, WITHOUT %s: %s. Review the patch before rebuilding%s. Then: %s" $ver $patch $loss "$tested" $how)
            case '*'
                echo "WARNING|"(__vl_t "%s is Void's, WITHOUT %s: %s. Rebuild: %s%s" $ver $patch $loss $how "$tested")
        end
        return 0
    end
    if test -z "$void"
        echo "OK|"(__vl_t "%s with %s (built here; Void does not have it)" $ver $patch)
        return 0
    end
    xbps-uhelper cmpver $ver $void
    set -l cmp $status
    switch "$st"
        case ALREADY_INCLUDED
            if test $cmp -eq 255
                echo "OK|"(__vl_t "%s with %s (built here). NOTE: Void has %s, which already brings it%s: the next update replaces it without losing anything" $ver $patch $void "$tested")
            else
                echo "OK|"(__vl_t "%s with %s (built here). NOTE: Void already brings it%s: one can go back to Void's (%s) with %s" $ver $patch "$tested" $void $back)
            end
            return 0
        case CONFLICT PARTIAL
            echo "WARNING|"(__vl_t "%s with %s (built here; in Void, %s)%s. Review the patch before the next rebuild: %s" $ver $patch $void "$tested" $how)
            return 0
    end
    switch $cmp
        case 1
            echo "OK|"(__vl_t "%s with %s (built here; in Void, %s)%s" $ver $patch $void "$tested")
        case 0
            # The scripts build with Void's revision + 1: if Void reaches the same one, it is a
            # newer build of its own (e.g. because of a new library) that xbps does not install.
            echo "WARNING|"(__vl_t "Void published %s, the same version and revision as the patched one here: xbps does not install it, but it brings changes from Void that are missing here. Rebuild to have them with %s: %s%s" $void $patch $how "$tested")
        case '*'
            echo "WARNING|"(__vl_t "Void has %s, newer than the patched %s: the next update replaces it WITHOUT %s (unless it is held). Rebuild afterwards: %s%s" $void $ver $patch $how "$tested")
    end
end

# Libraries that an executable or library does not find (ldd "not found").
function __update_system_missing
    for f in $argv
        ldd $f 2>/dev/null | string match -r '^\s*(\S+) => not found' | string match -rv '=>'
    end | sort -u
end

# For --summary: whether a reboot is advisable, known without the update's list (glibc installed
# after booting, from the pkgdb's date).
function __update_system_reboot_since_boot
    set -l latest (ls /usr/lib/modules | sort -V | tail -1)
    if test "$latest" != (uname -r)
        __vl_t "kernel %s installed, %s is running" $latest (uname -r)
        return 0
    end
    set -l boot (string replace -rf -- '^btime ' '' < /proc/stat)
    set -l glibc (date -d (xbps-query -p install-date glibc) +%s 2>/dev/null)
    if test -n "$glibc"; and test "$glibc" -gt "$boot"
        __vl_t "glibc updated after booting"
    end
end

# Final summary (step 10). One line per check: OK, REPAIRED or WARNING.
# With --no-repair (update-system --summary) it does not use sudo: what it would repair, it warns about.
function __update_system_summary
    set -l repair 1
    contains -- --no-repair $argv; and set repair 0
    set -l lines
    set -l latest (ls /usr/lib/modules | sort -V | tail -1)

    # The Legion's TDP modules (DKMS, they only build for 6.18) and the kernel hold
    if type -q dkms; and test -n "$(dkms status -m lenovo-wmi-tdp 2>/dev/null)"
        if dkms status -m lenovo-wmi-tdp -k $latest 2>/dev/null | string match -q '*installed*'
            set -a lines "OK|"(__vl_t "TDP (lenovo-wmi-tdp) built for %s" $latest)
        else if string match -qr '^6\.18\.' -- $latest
            if test $repair -eq 0
                set -a lines "WARNING|"(__vl_t "TDP (lenovo-wmi-tdp) not built for %s: %s (update-system does it by itself)" $latest "sudo dkms autoinstall -k $latest")
            else if sudo dkms autoinstall -k $latest >/dev/null 2>&1; and dkms status -m lenovo-wmi-tdp -k $latest | string match -q '*installed*'
                set -a lines "REPAIRED|"(__vl_t "TDP (lenovo-wmi-tdp) rebuilt for %s" $latest)
            else
                set -a lines "WARNING|"(__vl_t "TDP (lenovo-wmi-tdp) does NOT build for %s: the error is in %s. Until it is fixed, that kernel (the one the hidden GRUB boots) has no fine TDP; to boot the previous one, %s (Legion recipe, step 8). Fix: Legion recipe, step 14, TDP, \"Updates\"" $latest '/var/lib/dkms/lenovo-wmi-tdp/*/build/make.log' 'grub-hidden.sh --remove')
            end
        else
            set -a lines "WARNING|"(__vl_t "the newest kernel (%s) is not of the 6.18 series: on it the Legion has no fine TDP control (the modules are only for 6.18). Boot the 6.18 one or bring its sources (Legion recipe, step 14)" $latest)
        end
        if xbps-query -H 2>/dev/null | string match -qr '^linux-[0-9]'
            set -a lines "OK|"(__vl_t "kernel held in its series: it will not change series by itself")
        else
            set -a lines "WARNING|"(__vl_t "the kernel could move to another series in an update and the Legion would lose the fine TDP control. To avoid it: %s" 'sudo xbps-pkgdb -m hold linux linux-headers')
        end
    end

    # Kernel series: the one Void recommends (the repository's "linux" metapackage) against the
    # installed one. With "linux" held it is not followed by itself: here one sees when there is a new one.
    set -l recommended (xbps-query -R -p pkgver linux 2>/dev/null | string replace -r -- '^linux-([0-9]+\.[0-9]+).*' '$1')
    set -l series (string replace -r -- '^([0-9]+\.[0-9]+).*' '$1' $latest)
    if test -n "$recommended"
        if test "$recommended" = "$series"
            set -a lines "OK|"(__vl_t "kernel of the %s series, the one Void recommends" $series)
        else
            set -a lines "WARNING|"(__vl_t "Void already recommends the %s series of the kernel; here it is still %s. Changing is your decision (on the Legion: release the hold and bring the TDP modules of that series)" $recommended $series)
        end
    end

    # gamescope loses cap_sys_nice when it is updated (Game Mode)
    # (steam-modo-juego: the launcher's previous Spanish name, for a machine that still has it)
    if begin; test -x /usr/local/bin/steam-game-mode; or test -x /usr/local/bin/steam-modo-juego; end; and test -x /usr/bin/gamescope
        if getcap /usr/bin/gamescope | string match -q '*cap_sys_nice*'
            set -a lines "OK|"(__vl_t "gamescope with cap_sys_nice")
        else if test $repair -eq 0
            set -a lines "WARNING|"(__vl_t "gamescope without cap_sys_nice: %s (update-system does it by itself)" 'sudo setcap cap_sys_nice=eip /usr/bin/gamescope')
        else if sudo setcap cap_sys_nice=eip /usr/bin/gamescope; and getcap /usr/bin/gamescope | string match -q '*cap_sys_nice*'
            set -a lines "REPAIRED|"(__vl_t "gamescope: cap_sys_nice given back")
        else
            set -a lines "WARNING|"(__vl_t "gamescope without cap_sys_nice (%s)" 'sudo setcap cap_sys_nice=eip /usr/bin/gamescope')
        end
    end

    # Packages built here with a patch (local repository), one line each: whether they are still
    # the patched ones and whether Void already has an equal or newer build. The known ones always show up as long
    # as their piece is there (even if Void has already replaced them); the others, while they are local or if
    # this update replaced them.
    #  - gamescope with the PipeWire patch (Legion, 2026-10-07): only where the gamescope portal is.
    #  - xdg-desktop-portal-wlr with the patch that restores windows (Legion, 2026-10-07): only where
    #    the screen-share chooser is (its D-Bus service with XDPW_PERSIST_MODE).
    set -l known
    if test -d /usr/local/share/xdg-desktop-portal/gamescope-portals; and test -x /usr/bin/gamescope
        set -a known gamescope
        set -a lines (__update_system_local_line gamescope (__vl_t "the PipeWire patch") (__vl_t "Game Mode may crash when sharing the screen"))
    end
    if test -f ~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.wlr.service
        set -a known xdg-desktop-portal-wlr
        set -a lines (__update_system_local_line xdg-desktop-portal-wlr (__vl_t "the windows patch") (__vl_t "Vesktop will ask again several times when sharing a window"))
    end
    #  - xfdesktop with the fix of the wallpaper dialog on Wayland (upstream ed26b06a, 2026-10-09) and Thunar
    #    with the one of "Set as wallpaper" (our own patch, 2026-10-09): only where there is Xfce
    #    Wayland (labwc). If Void already brings them the patch test says so (before, it was assumed from the
    #    version of xfdesktop, >= 4.20.3, and from the ldd of Thunar's plugin: removed on 2026-10-09).
    if test -f ~/.config/xfce4/labwc/rc.xml; and xbps-query xfdesktop >/dev/null 2>&1
        set -a known xfdesktop
        set -a lines (__update_system_local_line xfdesktop (__vl_t "the fix of the wallpaper dialog on Wayland") (__vl_t "on Xfce Wayland, choosing a wallpaper in the dialog does nothing"))
    end
    if test -f ~/.config/xfce4/labwc/rc.xml; and xbps-query Thunar >/dev/null 2>&1
        set -a known Thunar
        set -a lines (__update_system_local_line Thunar (__vl_t "the fix of \"Set as wallpaper\" on Wayland") (__vl_t "on Xfce Wayland, that Thunar menu does not change the wallpaper"))
    end
    for n in (__update_system_locals) $__us_replaced
        contains -- $n $known; and continue
        set -a known $n
        set -a lines (__update_system_local_line $n (__vl_t "its patch") (__vl_t "what it fixed is lost"))
    end

    # Programs that do not come from xbps (official binaries): that they still find their libraries
    if test -e /usr/bin/inputplumber; and test -z "$(xbps-query -o /usr/bin/inputplumber 2>/dev/null)"
        set -l missing (__update_system_missing /usr/bin/inputplumber)
        if test -z "$missing"
            set -a lines "OK|"(__vl_t "InputPlumber finds its libraries")
        else
            set -a lines "WARNING|"(__vl_t "InputPlumber (official binary) does NOT find: %s. Install the Void package that provides it (%s) or move to a version of InputPlumber that uses the current one and repeat %s (Legion recipe, step 14)" (string join ' ' -- $missing) "xbps-query -Ro '*/<library>'" legion/install-inputplumber.sh)
        end
    end
    if test -e /usr/local/lib/xdg-desktop-portal-gamescope
        set -l missing (__update_system_missing /usr/local/lib/xdg-desktop-portal-gamescope)
        if test -z "$missing"
            set -a lines "OK|"(__vl_t "gamescope portal finds its libraries")
        else
            set -a lines "WARNING|"(__vl_t "gamescope portal (Valve's binary) does NOT find: %s. It only depends on glibc: install what is missing, or bring the one of a new SteamOS version and repeat %s (Legion recipe, step 14, \"Screen sharing in Game Mode\")" (string join ' ' -- $missing) common/steam/portal-gamescope/install-portal-gamescope.sh)
        end
    end

    # steamos-manager (built here with a patch, outside xbps): libraries, that it is the reference
    # binary (sha256 that its installer writes in /usr/local/share/steamos-manager-void/sha256)
    # and that its build dependencies are still there (they are kept on purpose to rebuild it). It says
    # which package it is (file "package" of the same folder, which the installer writes since
    # 2026-10-08; "paquete", its previous Spanish name, is read too): the official one (…-void) is a documented option, not a failure, so it is warned as a
    # note inside the line, without WARNING; if the file is missing (installed before), it is also a note.
    if test -e /usr/lib/steamos-manager
        set -l bad
        set -l dir /usr/local/share/steamos-manager-void
        set -l pkg
        if test -f $dir/package
            set pkg (string trim < $dir/package)[1]
        else if test -f $dir/paquete
            set pkg (string trim < $dir/paquete)[1]
        end
        set -l name
        if test -z "$pkg"
            set name (__vl_t "unknown package (repeat %s to record it)" install-steamos-manager.sh)
        else if string match -q -- '*-void' $pkg
            set name (__vl_t "package %s (the official one, WITHOUT the set_clocks patch: \"Error setting manual GPU clock\" in the log with the manual clock disabled; the patched one is …-void-2)" $pkg)
        else
            set name (__vl_t "package %s" $pkg)
        end
        set -l missing (__update_system_missing /usr/lib/steamos-manager /usr/bin/steamosctl)
        if test -n "$missing"
            set -a bad (__vl_t "does NOT find %s: rebuild with %s and install with %s (the build dependencies are installed on purpose; Legion recipe, step 14, steamos-manager)" (string join ' ' -- $missing) 'common/steam/steamos-manager/build-steamos-manager.sh /tmp' install-steamos-manager.sh)
        end
        set -l ref $dir/sha256
        set -l sum
        if not test -f $ref
            set -a bad (__vl_t "without reference sha256 (%s): it cannot be known whether it is the patched one (repeat %s)" $ref install-steamos-manager.sh)
        else if not sha256sum -c --status $ref 2>/dev/null
            set -a bad (__vl_t "the installed one is NOT the reference one (sha256 different from that of %s): repeat %s" $ref install-steamos-manager.sh)
        else
            set sum (string sub -l 8 -- (string split -f1 ' ' -- (string match -- '*/usr/lib/steamos-manager' < $ref)))
        end
        set -l deps
        for p in glib-devel eudev-libudev-devel speech-dispatcher-devel clang pkg-config git make
            xbps-query $p >/dev/null 2>&1; or set -a deps $p
        end
        test -n "$deps"; and set -a bad (__vl_t "to rebuild it, missing: %s" "sudo xbps-install -S "(string join ' ' -- $deps))
        test -x ~/.cargo/bin/cargo; or set -a bad (__vl_t "to rebuild it, missing Rust from rustup (~/.cargo/bin/cargo; Legion recipe, step 14, \"Controller on the desktop\", extest)")
        # Is there a new upstream version and does it still need the patch? (2026-10-09) Only if the
        # latest vX.Y.Z tag differs from the installed one (network: git ls-remote, ~1 s; the test, with cache).
        set -l note
        set -l tag (string match -r -- 'v[0-9][0-9.]*[0-9]' $pkg)
        set -l url https://gitlab.steamos.cloud/holo/steamos-manager.git
        set -l newest (timeout 30 git ls-remote --tags --refs $url 'v*' 2>/dev/null | string match -r -- 'refs/tags/(v[0-9]+(?:\.[0-9]+)*)$' | string match -rv -- '^refs' | sort -V | tail -1)
        set -l patches ~/.local/share/update-system/patches/steamos-manager/0*.patch
        if test -z "$newest"
            set note (__vl_t "; unchecked whether there is a new version (without network)")
        else if test -n "$tag"; and test "$newest" != "$tag"
            if test -x ~/.local/bin/patch-still-needed; and test (count $patches) -gt 0
                set -l r (string split ' ' -- (timeout 900 ~/.local/bin/patch-still-needed git $url $newest steamos-manager $patches 2>/dev/null | string match -r '^RESULT .*'))
                switch "$r[4]"
                    case STILL_NEEDED
                        set note (__vl_t "; NOTE: upstream published %s and the patch is still needed (tested): to move to it, rebuild with %s changing VER and COMMIT" $newest build-steamos-manager.sh)
                    case ALREADY_INCLUDED
                        set note (__vl_t "; NOTE: upstream published %s and it already brings the patch's change (tested): one can move to it without the patch" $newest)
                    case CONFLICT PARTIAL
                        set note (__vl_t "; NOTE: upstream published %s and the patch cannot be used as it is (%s): review it before moving to it" $newest (string join ' ' -- $r[5..-1]))
                    case '*'
                        set note (__vl_t "; NOTE: upstream published %s (patch unchecked)" $newest)
                end
            else
                set note (__vl_t "; NOTE: upstream published %s (without the patch test installed)" $newest)
            end
        end
        if test -z "$bad"
            set -a lines "OK|"(__vl_t "steamos-manager, %s: finds its libraries, is the reference one (sha256 %s…) and its build dependencies are there%s" $name $sum "$note")
        else
            set -a lines "WARNING|steamos-manager, $name: "(string join '; ' -- $bad)"$note"
        end
    end

    # extest (built here with Rust from rustup, 32 bits): libraries and what is needed to rebuild it
    set -l extest ~/.local/lib/extest/libextest.so
    if test -e $extest
        set -l bad
        set -l missing (__update_system_missing $extest)
        if test -n "$missing"
            set -a bad (__vl_t "does NOT find %s: rebuild with %s (Legion recipe, step 14, \"Controller on the desktop\")" (string join ' ' -- $missing) 'cd ~/src/extest && ~/.cargo/bin/cargo build --release && install -D -m 755 target/i686-unknown-linux-gnu/release/libextest.so ~/.local/lib/extest/libextest.so')
        end
        set -l i686 ~/.rustup/toolchains/*/lib/rustlib/i686-unknown-linux-gnu
        test -x ~/.cargo/bin/cargo; or set -a bad (__vl_t "to rebuild it, missing Rust from rustup (~/.cargo, ~/.rustup)")
        test -x ~/.cargo/bin/cargo; and test -z "$i686"; and set -a bad (__vl_t "to rebuild it, missing the 32-bit target: %s" '~/.cargo/bin/rustup target add i686-unknown-linux-gnu')
        test -f ~/src/extest/Cargo.lock; or set -a bad (__vl_t "to rebuild it, missing ~/src/extest (its code, 1.0.3: copy in %s)" legion/steam/extest/extest-1.0.3-src.tar.gz)
        xbps-query gcc-multilib >/dev/null 2>&1; or set -a bad (__vl_t "to rebuild it, missing: %s" 'sudo xbps-install -S gcc-multilib')
        if test -z "$bad"
            set -a lines "OK|"(__vl_t "extest finds its libraries and can be rebuilt (~/.rustup, ~/.cargo, ~/src/extest, gcc-multilib)")
        else
            set -a lines "WARNING|extest: "(string join '; ' -- $bad)
        end
    end

    # What the steps above already warned about, repeated here
    if test "$__us_new_files" -gt 0 2>/dev/null
        set -a lines "WARNING|"(__vl_t "%s .new-* template(s) in /etc: compare, do not apply" $__us_new_files)
    else
        set -a lines "OK|"(__vl_t "no .new-* templates in /etc")
    end
    if test -n "$__us_reboot"
        set -a lines "WARNING|"(__vl_t "a reboot is advisable: %s" "$__us_reboot")
    else
        set -a lines "OK|"(__vl_t "no reboot needed")
    end

    echo
    echo "==> "(__vl_t "Summary")
    # State words, translated once (OK stays OK in Spanish too)
    set -l w_ok (__vl_t "OK")
    set -l w_repaired (__vl_t "REPAIRED")
    set -l w_warning (__vl_t "WARNING")
    set -l warnings 0
    for l in $lines
        set -l parts (string split -m1 '|' -- $l)
        set -l state $parts[1]
        set -l text $parts[2]
        switch $state
            case OK
                set_color green; printf '  %-9s' $w_ok
            case REPAIRED
                set_color cyan; printf '  %-9s' $w_repaired
            case '*'
                set_color yellow; printf '  %-9s' $w_warning; set warnings (math $warnings + 1)
        end
        set_color normal; echo $text
    end
    echo
    if test $warnings -eq 0
        set_color green; echo "✓ "(__vl_t "All in order"); set_color normal
    else
        set_color yellow; echo "⚠ "(__vl_t "%s warning(s): check above" $warnings); set_color normal
    end
end
