# shellcheck shell=bash
# list.sh — the pending updates, as cachy-update shows them: name, old version and new version, with the part of
# the version that changes in red (old) and green (new), aligned in columns. Reads the state files of the last
# check (check.sh).

# vu_color_versions < "name old -> new" lines
vu_color_versions() {
    local name old arrow new i common cut
    while read -r name old arrow new; do
        [ -n "$name" ] || continue
        if [ -z "$c_off" ] || [ "$old" = "(new)" ]; then printf '%s %s -> %s\n' "$name" "$old" "$new"; continue; fi
        # length of the common prefix, cut back to just after its last separator (. _ - :) so that whole
        # parts change color (1.2.10 -> 1.2.11: "10"/"11" colored, not only "0"/"1")
        i=0; while [ $i -lt ${#old} ] && [ "${old:$i:1}" = "${new:$i:1}" ]; do i=$((i+1)); done
        if [ "$old" != "$new" ]; then
            common=${old:0:$i}; cut=${common%[._:-]*}
            if [ "$cut" != "$common" ]; then i=$(( ${#cut} + 1 )); else i=0; fi
        fi
        printf '%s %s -> %s\n' "${c_bold}${name}${c_off}" "${old:0:$i}${c_red}${c_bold}${old:$i}${c_off}" "${new:0:$i}${c_green}${c_bold}${new:$i}${c_off}"
    done
}

# vu_print_list: prints what is pending; returns 1 if nothing is
vu_print_list() {
    local np nf
    np=$(vu_count "$VU_STATE/packages"); nf=$(vu_count "$VU_STATE/flatpak")
    [ $((np + nf)) -gt 0 ] || return 1
    if [ "$np" -gt 0 ]; then
        step "Packages (%s):" "$np"
        vu_color_versions < "$VU_STATE/packages" | column -t
    fi
    if [ "$nf" -gt 0 ]; then
        [ "$np" -gt 0 ] && echo
        step "Flatpak (%s):" "$nf"
        column -t < "$VU_STATE/flatpak"
    fi
    return 0
}
