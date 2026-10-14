# shellcheck shell=bash
# shellcheck disable=SC2154  # configuration and colors: defined in base.sh (void-update sources them together)
# shellcheck disable=SC2034  # VU_REPLACED, VU_NEW_FILES: read by summary.sh
# upgrade.sh — void-update without options: the full update. The idea comes from omarchy-update (Arch) and
# cachy-update, adapted to Void and to what happened on these machines. In order:
#
#  1. Syncs (sudo xbps-install -S) and shows Void's news published since the last update (some ask for a manual
#     step). Then the list of updates, colored like cachy-update, and how much it weighs; asks to confirm once.
#     If the list replaces a package built here (installed from a local repository, e.g. xbps-src's
#     hostdir/binpkgs), it warns BEFORE confirming, testing its patch against the new code.
#  2. xbps first, alone: with an old xbps, xbps-install refuses to update anything else.
#  3. Everything else. If a new OpenSSH came in, it restarts sshd: the old one in memory cuts all new
#     connections (runit does not restart services on update).
#  4. Flatpak, if installed.
#  5. Orphans, WITHOUT the kernels: the kernel of the previous series becomes an orphan and is the backup one.
#  6. Cache: downloaded packages that no longer match anything installed.
#  7. Loose kernels (those that belong to no package, e.g. the ISO's) with vkpurge.
#  8. .new-* files in /etc: only warned about, never applied (see recipe, step 1).
#  9. LazyVim, if installed.
# 10. Services that still run old code after the update (services.sh): it offers to restart them.
# 11. SUMMARY (summary.sh): one line per check, OK / REPAIRED / WARNING.
# 12. If there is a new kernel or glibc, it says so and ASKS whether to reboot ([y/N]). It never reboots by itself.
# A lock in $XDG_RUNTIME_DIR prevents two updates at the same time.

vu_upgrade() {
    exec {ulock}> "$VU_RUN/void-update.lock"
    if ! flock -n "$ulock"; then
        warn "There is already a void-update running"
        ask n "Go on anyway? [y/N] " || { t "Canceled."; return 4; }
    fi

    step "Syncing repositories"
    sudo xbps-install -S || return 5

    # Keep sudo alive: the first update after installing took ~45 min of download, and without this it would
    # ask for the password again halfway. It ends when the mark is deleted, and at most after 2 h in case
    # it is interrupted with Ctrl+C before deleting it.
    local mark; mark=$(mktemp)
    bash -c 'for i in $(seq 120); do [ -e "$1" ] || exit 0; sudo -n true 2>/dev/null || exit 0; sleep 60; done' _ "$mark" &
    disown
    vu_steps; local state=$?
    rm -f "$mark"
    [ $state -eq 0 ] || return $state

    vu_set_state up-to-date
    : > "$VU_STATE/notified"
    date +%s > "$VU_STATE/last-update"      # fastfetch's "Updated" line (xbps keeps no history)
    date +%s > "$VU_STATE/last-check"
    vu_summary
    if [ -n "$VU_REBOOT" ]; then
        echo
        if ask n "↻ A reboot is advisable (%s). Reboot now? [y/N] " "$VU_REBOOT"; then sudo reboot; fi
    fi
    return 0
}

vu_steps() {
    local raw pending=() names mib orphans kernels remove new_files
    vu_news_before_update
    raw=$(mktemp)
    xbps-install -un > "$raw" 2>/dev/null
    mapfile -t pending < "$raw"
    names=$(cut -d' ' -f1 "$raw" | vu_pkgname)
    vu_write_pending "$raw"
    VU_REPLACED=()

    if [ ${#pending[@]} -eq 0 ]; then
        ok "Packages up to date"
    else
        echo
        vu_print_list
        vu_local_warning "${pending[@]}"
        mib=$(awk '{s += $6} END {printf "%.0f", s / 1048576}' "$VU_STATE/xbps-raw")
        echo
        ask y "Update %s packages (%s MiB to download)? [Y/n] " "${#pending[@]}" "$mib" || { t "Canceled."; return 4; }
        if grep -qx xbps <<< "$names"; then
            echo; step "Updating xbps first"
            sudo xbps-install -uy xbps || return 5
        fi
        echo; step "Updating the system"
        sudo xbps-install -uy || return 5
        : > "$VU_STATE/packages"
        if grep -qx openssh <<< "$names"; then
            echo; step "OpenSSH changed: restarting sshd (the open sessions go on)"
            sudo sv restart sshd
        fi
    fi

    if [ "$flatpak" = true ] && command -v flatpak >/dev/null; then
        echo; echo "${c_blue}==>${c_off}${c_bold} Flatpak${c_off}"
        flatpak update -y && : > "$VU_STATE/flatpak"
    fi
    cat "$VU_STATE/packages" "$VU_STATE/flatpak" > "$VU_STATE/all"

    # Orphans except the kernels (linuxX.Y), which stay as backup
    local orphans kernels remove
    orphans=$(xbps-query -O | vu_pkgname)
    kernels=$(grep -E '^linux[0-9.]+$' <<< "$orphans" | tr '\n' ' ' | sed 's/ $//')
    remove=$(grep -vE '^linux[0-9.]+$' <<< "$orphans" | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$remove" ]; then
        echo; step "Removing orphans (dependencies nobody uses anymore)"
        # shellcheck disable=SC2086
        sudo xbps-remove -Ry $remove
    fi
    if [ -n "$kernels" ]; then
        echo
        info "Orphan backup kernel, kept: %s" "$kernels"
        echo "  $(t "To remove it once the current one has been fine for a while: %s" "sudo xbps-remove -R $kernels")"
    fi

    echo; step "Cleaning the package cache"
    sudo xbps-remove -Oy

    if [ -n "$(vkpurge list 2>/dev/null)" ]; then
        echo; step "Removing loose kernels: %s" "$(vkpurge list | tr '\n' ' ' | sed 's/ $//')"
        sudo vkpurge rm all
    fi

    local new_files
    new_files=$(find /etc -name '*.new-*' 2>/dev/null)
    VU_NEW_FILES=$(grep -c . <<< "$new_files")
    if [ -n "$new_files" ]; then
        echo
        printf '%s' "$c_yellow"
        echo "⚠ $(t "New configuration templates (do NOT apply them without comparing them; the current file is the good one):")"
        printf '  %s\n' $new_files
        echo "  $(t "Compare: %s   ·   Careful with passwd: the template has no users." "diff <file> <file>.new-*")"
        printf '%s' "$c_off"
    fi

    if command -v nvim >/dev/null && [ -d ~/.config/nvim ]; then
        echo; step "LazyVim: syncing Neovim's plugins"
        nvim --headless "+Lazy! sync" +qa
    fi

    # Services still running old code (only if something was updated)
    if [ ${#pending[@]} -gt 0 ]; then echo; vu_services --ask || true; fi

    # Reboot: kernel newer than the running one, or glibc updated
    local latest; latest=$(ls /usr/lib/modules | sort -V | tail -1)
    VU_REBOOT=""
    if [ "$latest" != "$(uname -r)" ]; then VU_REBOOT=$(t "kernel %s installed, %s is running" "$latest" "$(uname -r)")
    elif grep -qx glibc <<< "$names"; then VU_REBOOT=$(t "glibc updated"); fi

    echo; ok "Completed"
    return 0
}
