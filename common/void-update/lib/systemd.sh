# shellcheck shell=bash
# shellcheck disable=SC2154  # configuration and colors: defined in base.sh (void-update sources them together)
# systemd.sh — maintenance of systemd-compat (common/systemd-compat; docs/2-base-system/4-systemd-compat.md), the
# systemctl/journalctl/systemd-run/systemd-inhibit that programs written for systemd call (2026-10-17):
#   void-update --systemd          the report: installation, units.d, the programs that call systemd and what of it
#                                  was asked and not served since the last review
#   void-update --systemd --ack    marks all that as reviewed (until a program changes or asks something new)
#   the summary                    one line: OK, or WARNING when something needs a look
# Two sources, so that a program changing how it works (a plugin update) is noticed either way:
#   - what it ASKS: every request systemd-compat does not fully serve leaves a line in requests.log (root's in
#     /run/systemd-compat, the user's in $XDG_RUNTIME_DIR/systemd-compat; per boot);
#   - what its CODE says: the lines that call systemd in the folders of systemd_compat_scan (void-update.conf;
#     default the Decky plugins), compared with the ones of the last review.

VU_SC_LIB=${VU_SC_LIB:-/usr/local/lib/systemd-compat}
VU_SC_ETC=${VU_SC_ETC:-/etc/systemd-compat}
VU_SC_STATE="$VU_STATE/systemd-compat"
# Scripts of the system that decide "is there systemd?" by whether systemctl exists (command -v, which, -x…): with
# systemd-compat installed they take the systemd path. The ones that also check /run/systemd (dracut, resolvconf,
# dhcpcd) are not affected; the others need a look once (vu_sc_detectors; 2026-10-17, after ssh-survey.sh did just that).
# The forms: sh/bash (command -v, which, type [-p], hash, test -x), fish (command -q, type -q), "does it answer?"
# (systemctl --version, which systemd-compat answers), Python (shutil.which, os.path.exists, os.access).
# /usr/lib and /usr/share: where packages keep helper scripts (5 s cold on the Legion, 0.6 s warm).
VU_SC_DETECT_DIRS=${VU_SC_DETECT_DIRS:-/etc /usr/local /usr/bin /usr/sbin /usr/libexec /usr/lib /usr/share $HOME/.local/bin $HOME/.config/fish}
VU_SC_DETECT='(command -[vq]|which|type( -[pPq])?|hash)[[:space:]]+["'"'"']?(/usr)?(/s?bin/)?systemctl|systemctl[[:space:]]+--version|-[xfe][[:space:]]+["'"'"']?/(usr/)?s?bin/systemctl|(shutil\.which|os\.path\.exists|os\.access)\(["'"'"'](/usr/s?bin/)?systemctl'
# What counts as calling systemd. busctl and loginctl are left out: elogind provides them.
VU_SC_PATTERN='systemctl|journalctl|systemd-run|systemd-inhibit|systemd-analyze|org\.freedesktop\.systemd1|/run/systemd|NOTIFY_SOCKET|sd_notify'

# The consumers: each subfolder of each folder of systemd_compat_scan ("~" allowed), one per line: NAME<TAB>PATH
vu_sc_consumers() {
    local dir d IFS=:
    for dir in $systemd_compat_scan; do
        dir=${dir/#\~/$HOME}
        [ -d "$dir" ] || continue
        for d in "$dir"/*/; do [ -d "$d" ] && printf '%s\t%s\n' "$(basename "$d")" "${d%/}"; done
    done
}
# The lines of a consumer that call systemd: "file: code" (no line numbers, no comments), sorted
vu_sc_lines() {
    (cd "$1" && grep -rIE --include='*.py' --include='*.sh' --exclude-dir=node_modules --exclude-dir=dist \
        --exclude-dir=__pycache__ "$VU_SC_PATTERN" . 2>/dev/null) \
        | sed -E 's#^\./##; s#^([^:]*):[[:space:]]*#\1: #' | grep -vE '^[^:]*: (#|"""|//)' | sort -u
}
vu_sc_version() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version",""))' "$1/package.json" 2>/dev/null; }
vu_sc_key() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }

# The units a consumer names ("x.service", and plugin_loader), with what they are here
vu_sc_units() {
    (cd "$1" && grep -rhoIE --include='*.py' --include='*.sh' --exclude-dir=node_modules --exclude-dir=dist \
        "[\"'][A-Za-z0-9_.@*-]+\.service[\"']|[\"']plugin_loader[\"']" . 2>/dev/null) | tr -d "\"'" | sed 's/\.service$//' | sort -u
}
vu_sc_what() {   # UNIT → what it is here (a short text)
    [ -f "$VU_SC_LIB/compat.sh" ] || { t "systemd-compat not installed"; return; }
    local r
    # shellcheck disable=SC1091  # installed by install-systemd-compat.sh
    r=$( export SYSTEMD_COMPAT_ETC="$VU_SC_ETC"; . "$VU_SC_LIB/compat.sh"
         sc_lookup system "$1"; [ "$SC_KIND" = deny ] && { echo "system deny"; exit; }   # before the pattern check: hhd@*
         case $1 in *[*?]*) echo "pattern"; exit ;; esac
         sc_resolve system "$1"; [ "$SC_TYPE" != none ] && { echo "system $SC_TYPE $SC_SVC"; exit; }
         sc_resolve user "$1"; echo "user $SC_TYPE" )
    case $r in
        "system runit "*) if [ -e "/var/service/${r##* }" ]; then t "runit service %s" "${r##* }"; else t "runit service %s (not enabled)" "${r##* }"; fi ;;
        "system deny"*|"user deny") t "hidden on purpose (deny in units.d)" ;;
        "system proc"*|"user proc") t "unit of systemd-compat (units.d or systemd-run)" ;;
        pattern) t "pattern: matches the runit services of that name" ;;
        *) t "does not exist here (that program will see it as not installed)" ;;
    esac
}

# The detectors: "PATH<TAB>safe|review<TAB>the matching lines", plus those of the
# repository systemd-compat came from (its MANIFEST). /usr/bin and /usr/sbin are the same folder on Void: deduplicated.
vu_sc_detectors() {
    local dirs repo f lines
    # shellcheck disable=SC2206  # a list of folders
    dirs=($VU_SC_DETECT_DIRS)
    repo=$(sed -n 's/^repo=//p' "$VU_SC_LIB/MANIFEST" 2>/dev/null)
    [ -d "$repo" ] && dirs+=("$repo/common" "$repo/legion" "$repo/install")
    grep -rlIE --exclude-dir=systemd-compat "$VU_SC_DETECT" "${dirs[@]}" 2>/dev/null | while read -r f; do readlink -f "$f"; done | sort -u |
    while read -r f; do
        case $f in */lib/void-update/lib/systemd.sh|*/common/void-update/lib/systemd.sh) continue ;; esac
        lines=$(grep -hoE "$VU_SC_DETECT" "$f" | sort -u | paste -sd' ')
        # safe: it also asks what tells that systemd RUNS (/run/systemd/system or /run/systemd/private: any other
        # /run/systemd path, like /run/systemd/resolve, proves nothing), or it runs in the initramfs (dracut's
        # modules), where systemd-compat does not exist
        if grep -qE '/run/systemd/(system|private)' "$f" || case $f in /usr/lib/dracut/*) true ;; *) false ;; esac; then
            printf '%s\tsafe\t%s\n' "$f" "$lines"
        else printf '%s\treview\t%s\n' "$f" "$lines"; fi
    done
}
# Detectors to review that are not in the last review (or whose lines changed)
vu_sc_new_detectors() {
    local ack="$VU_SC_STATE/detectors.ack"
    vu_sc_detectors | awk -F'\t' '$2 == "review"' | while IFS= read -r l; do grep -qxF "$l" "$ack" 2>/dev/null || printf '%s\n' "$l"; done
}

# Requests not served, since the last review: "COUNT<TAB>tool status request<TAB>detail<TAB>caller", most first
vu_sc_logs() { printf '%s\n' /run/systemd-compat/requests.log "${XDG_RUNTIME_DIR:-/nonexistent}/systemd-compat/requests.log"; }
vu_sc_boot() { tr -d - < /proc/sys/kernel/random/boot_id; }
vu_sc_new_requests() {
    local f boot seen n ack="$VU_SC_STATE/requests.ack"
    boot=$(vu_sc_boot)
    while read -r f; do
        [ -r "$f" ] || continue
        n=$(wc -l < "$f")
        seen=$(awk -v f="$f" -v b="$boot" '$1 == f && $2 == b { print $3 }' "$ack" 2>/dev/null | tail -1)
        { [ -n "$seen" ] && [ "$seen" -le "$n" ]; } || seen=0
        tail -n "+$((seen + 1))" "$f"
    done < <(vu_sc_logs) | awk -F'\t' '{
        c = $6; sub(/ \(.*$/, "", c); if (length(c) > 50) c = substr(c, 1, 50) "…"
        k = $3 " " $4 ": " $5 "\t" $7 "\t" c; n[k]++ }
        END { for (k in n) print n[k] "\t" k }' | sort -t$'\t' -k1,1nr
}

# Problems of the installation, one per line (empty: none)
vu_sc_problems() {
    local n l owner repo f want have pkg
    for n in systemctl journalctl systemd-run; do
        l=$(readlink "/usr/bin/$n" 2>/dev/null)
        [ "$l" = "$VU_SC_LIB/$n" ] && continue
        owner=$(xbps-query -o "/usr/bin/$n" 2>/dev/null | head -1)
        if [ -n "$owner" ]; then t "/usr/bin/%s now comes from a package (%s): systemd-compat no longer answers there" "$n" "$owner"
        else t "/usr/bin/%s is not systemd-compat's (%s)" "$n" "${l:-$(t "missing")}"; fi
    done
    [ "$(readlink /usr/bin/systemd-inhibit 2>/dev/null)" = elogind-inhibit ] || t "/usr/bin/systemd-inhibit does not point to elogind-inhibit"
    if [ -r "$VU_SC_LIB/MANIFEST" ]; then
        # what is installed against what was installed, and against the repository it came from
        (cd "$VU_SC_LIB" && grep -E '^[0-9a-f]{64}  ' MANIFEST | sha256sum -c --quiet - >/dev/null 2>&1) \
            || t "files of %s or units.d changed since they were installed (repeat the installer)" "$VU_SC_LIB"
        repo=$(sed -n 's/^repo=//p' "$VU_SC_LIB/MANIFEST")
        if [ -d "$repo/common/systemd-compat" ]; then
            for f in compat.sh systemctl journalctl systemd-run requires units.d/50-void-legion.conf; do
                want=$(sha256sum < "$repo/common/systemd-compat/$f" 2>/dev/null | cut -c1-64)
                have=$(grep -E "  (.*/)?${f##*/}\$" "$VU_SC_LIB/MANIFEST" | cut -c1-64)
                [ "$want" = "$have" ] || { t "the repository has a newer systemd-compat: %s" "sudo sh $repo/common/systemd-compat/install-systemd-compat.sh"; break; }
            done
        fi
    fi
    if [ -r "$VU_SC_LIB/requires" ]; then
        while read -r pkg _; do
            case $pkg in ''|\#*) continue ;; esac
            xbps-query "$pkg" >/dev/null 2>&1 || t "missing package %s (%s)" "$pkg" "sudo xbps-install -S $pkg"
        done < "$VU_SC_LIB/requires"
    fi
    # units.d: each runit alias, a service that exists; each exec unit, a command that exists
    local u k rest
    for f in "$VU_SC_ETC"/units.d/*.conf; do
        [ -r "$f" ] || continue
        while read -r u _ k rest; do
            case $u in ''|\#*) continue ;; esac
            case $k in
                runit) [ -f "/etc/sv/${rest%% *}/run" ] || t "units.d: %s points to the runit service %s, which does not exist (%s)" "$u" "${rest%% *}" "$f" ;;
                exec) command -v "${rest%% *}" >/dev/null || t "units.d: %s runs %s, which is not installed (%s)" "$u" "${rest%% *}" "$f" ;;
            esac
        done < "$f"
    done
}

# Consumers whose systemd lines changed since the last review: "NAME<TAB>new|changed"
vu_sc_changed() {
    local name path key old
    while IFS=$'\t' read -r name path; do
        key=$(vu_sc_key "$name")
        local now; now=$(vu_sc_lines "$path")
        [ -n "$now" ] || { [ -f "$VU_SC_STATE/consumers/$key" ] && printf '%s\tchanged\n' "$name"; continue; }
        old="$VU_SC_STATE/consumers/$key"
        if [ ! -f "$old" ]; then printf '%s\tnew\n' "$name"
        elif [ "$now" != "$(cat "$old")" ]; then printf '%s\tchanged\n' "$name"; fi
    done < <(vu_sc_consumers)
}

# The line of the summary ("STATE|name|short|detail"), or nothing if there is nothing about systemd here
vu_systemd_line() {
    local consumers=0 callers=0 name path problems changed reqs nreq
    while IFS=$'\t' read -r name path; do
        consumers=$((consumers + 1)); [ -n "$(vu_sc_lines "$path")" ] && callers=$((callers + 1))
    done < <(vu_sc_consumers)
    if [ ! -e "$VU_SC_LIB/systemctl" ]; then
        [ $callers -gt 0 ] || return 0
        echo "WARNING|systemd|$(t "not installed")|$(t "%s program(s) call systemd and get nothing (e.g. Decky plugins cannot restart Decky): %s (docs/2-base-system/4-systemd-compat.md)" "$callers" 'sudo sh <repo>/common/systemd-compat/install-systemd-compat.sh')"
        return 0
    fi
    problems=$(vu_sc_problems)
    changed=$(vu_sc_changed | cut -f1 | paste -sd, | sed 's/,/, /g')
    local det; det=$(vu_sc_new_detectors | grep -c .)
    reqs=$(vu_sc_new_requests); nreq=$(printf '%s' "$reqs" | grep -c .)
    if [ -n "$problems" ]; then
        echo "WARNING|systemd|$(t "%s problem(s)" "$(printf '%s\n' "$problems" | grep -c .)")|$(printf '%s\n' "$problems" | paste -sd'\t' | sed 's/\t/; /g')"
    elif [ -n "$changed" ] || [ "$nreq" -gt 0 ] || [ "$det" -gt 0 ]; then
        local why=()
        [ -n "$changed" ] && why+=("$(t "changed how they call systemd: %s" "$changed")")
        [ "$det" -gt 0 ] && why+=("$(t "%s script(s) decide whether there is systemd by systemctl existing" "$det")")
        [ "$nreq" -gt 0 ] && why+=("$(t "%s kind(s) of request not served" "$nreq")")
        echo "WARNING|systemd|$(t "to review")|$(printf '%s; ' "${why[@]}" | sed 's/; $//'). $(t "See %s; once reviewed, %s" 'void-update --systemd' 'void-update --systemd --ack')"
    else
        echo "OK|systemd|$(t "%s program(s) served" "$callers")|$(t "systemd-compat installed and as in the repository; %s program(s) call systemd, none changed since the last review, and nothing new was left unserved" "$callers")"
    fi
}

# void-update --systemd [--ack]
vu_systemd_report() {
    local name path key ver lines old u reqs problems
    if [ "${1:-}" = --ack ]; then
        mkdir -p "$VU_SC_STATE/consumers"
        while IFS=$'\t' read -r name path; do
            key=$(vu_sc_key "$name"); lines=$(vu_sc_lines "$path")
            if [ -n "$lines" ]; then printf '%s\n' "$lines" > "$VU_SC_STATE/consumers/$key"; else rm -f "$VU_SC_STATE/consumers/$key"; fi
        done < <(vu_sc_consumers)
        local boot f; boot=$(vu_sc_boot)
        while read -r f; do [ -r "$f" ] && printf '%s %s %s\n' "$f" "$boot" "$(wc -l < "$f")"; done < <(vu_sc_logs) > "$VU_SC_STATE/requests.ack"
        vu_sc_detectors | awk -F'\t' '$2 == "review"' > "$VU_SC_STATE/detectors.ack"
        ok "Reviewed: void-update will warn again when a program changes how it calls systemd or asks something new"
        return 0
    fi

    step "systemd-compat"
    if [ -e "$VU_SC_LIB/systemctl" ]; then
        ok "Installed (%s)" "$(sed -n 's/^# systemd-compat, installed //p' "$VU_SC_LIB/MANIFEST" 2>/dev/null)"
        problems=$(vu_sc_problems)
        if [ -n "$problems" ]; then while read -r l; do echo "${c_yellow}⚠ $l${c_off}"; done <<< "$problems"; else ok "Links, files, packages and units.d in order"; fi
    else
        warn "Not installed: %s" 'sudo sh <repo>/common/systemd-compat/install-systemd-compat.sh'
    fi

    step "Programs that call systemd (%s)" "${systemd_compat_scan}"
    local any=0 state
    while IFS=$'\t' read -r name path; do
        lines=$(vu_sc_lines "$path"); [ -n "$lines" ] || continue
        any=1; key=$(vu_sc_key "$name"); old="$VU_SC_STATE/consumers/$key"; ver=$(vu_sc_version "$path")
        if [ ! -f "$old" ]; then state=$(t "new: not reviewed yet")
        elif [ "$lines" != "$(cat "$old")" ]; then state=$(t "CHANGED since the last review")
        else state=$(t "as reviewed"); fi
        echo "${c_bold}$name${c_off}${ver:+ $ver} — $(t "%s line(s) that call systemd" "$(printf '%s\n' "$lines" | grep -c .)"); $state"
        if [ -f "$old" ] && [ "$lines" != "$(cat "$old")" ]; then
            diff <(cat "$old") <(printf '%s\n' "$lines") | sed -nE 's/^> /   + /p; s/^< /   - /p' | cut -c1-160
        fi
        while read -r u; do [ -n "$u" ] && printf '   %-28s %s\n' "$u" "$(vu_sc_what "$u")"; done < <(vu_sc_units "$path")
    done < <(vu_sc_consumers)
    [ $any = 1 ] || info "None found"

    step "Scripts that decide whether there is systemd by systemctl existing"
    local det_all; det_all=$(vu_sc_detectors)
    if [ -z "$det_all" ]; then ok "None"
    else
        while IFS=$'\t' read -r f cls lines; do
            if [ "$cls" = safe ]; then printf '   ✓ %s — %s\n' "$f" "$(t "also checks that systemd runs, or runs in the initramfs: not affected")"
            elif grep -qxF "$f"$'\t'"$cls"$'\t'"$lines" "$VU_SC_STATE/detectors.ack" 2>/dev/null; then printf '   ✓ %s — %s\n' "$f" "$(t "reviewed")"
            else printf '   %s⚠ %s%s — %s\n      %s\n' "$c_yellow" "$f" "$c_off" "$(t "with systemd-compat it takes its systemd path: check that it still does the right thing")" "$lines" | cut -c1-200; fi
        done <<< "$det_all"
    fi

    step "Requests not served since the last review (this boot)"
    reqs=$(vu_sc_new_requests)
    if [ -z "$reqs" ]; then ok "None"
    else
        while IFS=$'\t' read -r n what detail caller; do
            printf ' %3s× %s\n' "$n" "$what" | cut -c1-170
            printf '       %s%s\n' "${detail:+$detail — }" "$caller"
        done <<< "$reqs"
        info "not-found: a unit that does not exist here (normal for other hardware's services); unsupported/partial: something systemd-compat does not do (yet): add it to units.d or to systemd-compat"
    fi
    echo
    info "Once reviewed: %s" 'void-update --systemd --ack'
}
