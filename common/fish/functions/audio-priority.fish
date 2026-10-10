# Menu to reorder the audio priority by hand: first it chooses
# Output or Input, then the list of devices of that case.
# Persisted by writing directly
# ~/.config/wireplumber/wireplumber.conf.d/51-audio-priority.conf -- there is no
# external state layer like with monitor-order.fish (WirePlumber does not
# support re-reading a state file on the fly), so the .conf itself
# is the source of truth, and this function reads it before writing so as not to
# touch the category (Output/Input) that the user did not choose this time.
#
# Version for Void (Legion and IdeaPad), adapted on 2026-10-05 from
# fish/arch/brew/audio-priority.fish (the SteamOS one). Changes: (1) pw-dump is
# read with python3 instead of jq (jq is not installed on Void; python3 is);
# (2) without systemd: WirePlumber is started by PipeWire when the session begins
# (/etc/pipewire/pipewire.conf.d/10-wireplumber.conf) and stays hanging from
# init, so to apply it is terminated and launched again in the background
# (setsid) from the session's terminal (not over SSH: it would lack the
# session bus). WirePlumber 0.5.18 reads ~/.config/wireplumber/wireplumber.conf.d/.
#
# Unlike a previous version with fixed hardcoded roles, this one
# discovers the devices LIVE via `pw-dump` (read with python3): it lists the real Audio/Sink and Audio/Source
# -- excluding the `alsa_loopback_*` and `filter-chain-*` nodes, which
# are PipeWire's internal plumbing on this machine, not real
# devices -- with their `node.description` as label.
#
# The devices already configured in previous runs but that right now
# are disconnected (e.g. METHOD 360 turned off) still show up in
# the menu, marked "(not connected now)", taking the label and
# priority saved the last time -- so as not to lose that configuration
# just because the device is not present at this moment. They are
# detected by the substring "input"/"output" in the `node.name` saved in the
# .conf, since the .conf does not tell Sink from Source explicitly (only
# alsa/bluez).
#
# Its texts follow the system's language (__vl_t, translations in ~/.local/share/void-legion; the Spanish
# ones are the original texts). The labels written in the .conf ("## label (connected)") come out in
# the language of the run that wrote them: they are only comments, nothing reads them as a key.
# Previous name: audio-priority (unchanged).
function audio-priority --description "Output/Input menu -> reorder the priority of those audio devices (dynamic detection via pw-dump)"
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    set -l conf_file $HOME/.config/wireplumber/wireplumber.conf.d/51-audio-priority.conf
    mkdir -p (dirname $conf_file)

    if not command -q pw-dump; or not command -q python3; or not command -q wireplumber
        __vl_t "Error: pw-dump, python3 and wireplumber are needed." >&2
        return 1
    end

    # Suffixes of the labels in the menu (translated once)
    set -l connected_suffix (__vl_t "(connected)")
    set -l not_connected_suffix (__vl_t "(not connected now)")

    # Current priority of a pattern: it reads it from the .conf if there is already a
    # rule for it, otherwise it uses the fallback (default position).
    function _audio_priority_current_prio --no-scope-shadowing
        set -l pattern $argv[1]
        set -l fallback $argv[2]
        if test -f $conf_file
            set -l found (grep -F -A4 -- "node.name = \"$pattern\"" $conf_file 2>/dev/null | grep -m1 'priority.session' | grep -oE '[0-9]+')
            if test -n "$found"
                echo $found
                return
            end
        end
        echo $fallback
    end

    # All the rules already written in the .conf, regardless of alsa/bluez:
    # "priority\tlabel\tpattern", one per line. The label comes from the
    # comment "## $label" that this function writes above each block.
    function _audio_priority_conf_all --no-scope-shadowing
        if not test -f $conf_file
            return
        end
        set -l label ""
        set -l pattern ""
        while read -l line
            if string match -qr '^\s*## ' -- $line
                set label (string replace -r '^\s*## ' '' -- $line)
            else if string match -qr 'node\.name = "[^"]+"' -- $line
                set pattern (string match -r 'node\.name = "([^"]+)"' -- $line)[2]
            else if string match -qr 'priority\.session = [0-9]+' -- $line
                set -l prio (string match -r 'priority\.session = ([0-9]+)' -- $line)[2]
                if test -n "$pattern"
                    printf '%s\t%s\t%s\n' $prio "$label" $pattern
                end
            end
        end < $conf_file
    end

    # Real devices connected right now for a given media.class
    # (Audio/Sink or Audio/Source): "pattern\tdescription", one per line.
    # It filters out the internal plumbing nodes (loopback/filter-chain).
    function _audio_priority_live_devices --no-scope-shadowing
        pw-dump 2>/dev/null | python3 -c '
import json, re, sys
media_class = sys.argv[1]
for o in json.load(sys.stdin):
    if o.get("type") != "PipeWire:Interface:Node":
        continue
    p = (o.get("info") or {}).get("props") or {}
    n = p.get("node.name")
    if p.get("media.class") != media_class or not n or re.match(r"^(alsa_loopback_|filter-chain-)", n):
        continue
    print(n + "\t" + (p.get("node.description") or p.get("node.nick") or n))
' "$argv[1]"
    end

    # Complete and sorted list (lowest to highest priority) of a category:
    # devices connected now + those saved in the .conf that are not
    # connected (filtered by whether the node.name contains $direction,
    # "output" or "input"). Returns "priority\tlabel\tsection\tpattern".
    function _audio_priority_category --no-scope-shadowing
        set -l media_class $argv[1]
        set -l direction $argv[2]

        set -l base 5000
        set -l step 1000
        set -l rank 0
        set -l lines
        set -l seen

        for d in (_audio_priority_live_devices $media_class)
            set rank (math $rank + 1)
            set -l pattern (echo -e $d | cut -f1)
            set -l label (echo -e $d | cut -f2)
            set -a seen $pattern
            set -l section alsa
            string match -q 'bluez_*' $pattern; and set section bluez
            set -l fallback (math $base + $step \* \( $rank - 1 \))
            set -l prio (_audio_priority_current_prio $pattern $fallback)
            set -a lines (printf '%s\t%s %s\t%s\t%s' $prio "$label" "$connected_suffix" $section $pattern)
        end

        for line in (_audio_priority_conf_all)
            set -l prio (echo -e $line | cut -f1)
            set -l label (echo -e $line | cut -f2)
            set -l pattern (echo -e $line | cut -f3)
            if contains -- $pattern $seen
                continue
            end
            if not string match -q "*$direction*" -- $pattern
                continue
            end
            set -l section alsa
            string match -q 'bluez_*' $pattern; and set section bluez
            set -a lines (printf '%s\t%s %s\t%s\t%s' $prio "$label" "$not_connected_suffix" $section $pattern)
        end

        printf '%s\n' $lines | sort -t \t -k1,1n
    end

    # Adds a WirePlumber rule block (from a line
    # "prio\tlabel\tsection\tpattern") to the parent's alsa_blocks/bluez_blocks.
    function _audio_priority_add_block --no-scope-shadowing
        for line in $argv
            set -l prio (echo -e $line | cut -f1)
            set -l label (echo -e $line | cut -f2)
            set -l section (echo -e $line | cut -f3)
            set -l pattern (echo -e $line | cut -f4)

            set -l block "  {
    ## $label
    matches = [ { node.name = \"$pattern\" } ]
    actions = {
      update-props = {
        priority.session = $prio
        priority.driver  = $prio
      }
    }
  }"
            if test "$section" = alsa
                set alsa_blocks $alsa_blocks $block
            else
                set bluez_blocks $bluez_blocks $block
            end
        end
    end

    set -l label_output (__vl_t "Output")
    set -l label_input (__vl_t "Input")
    set -l category (printf '%s\n' $label_output $label_input | fzf --prompt=(__vl_t "audio priority > ") \
        --header=(__vl_t "Choose what to reorder: Output or Input"))

    if test -z "$category"
        __vl_t "Canceled, nothing was touched."
        return 1
    end

    set -l media_class Audio/Sink
    set -l direction output
    set -l other_media_class Audio/Source
    set -l other_direction input
    set -l other_label $label_input
    if test "$category" = "$label_input"
        set media_class Audio/Source
        set direction input
        set other_media_class Audio/Sink
        set other_direction output
        set other_label $label_output
    end

    set -l sorted (_audio_priority_category $media_class $direction)

    if test (count $sorted) -eq 0
        __vl_t "No %s device was detected (neither connected now, nor saved before)." "$category" >&2
        return 1
    end

    __vl_t "%s -- current order (lowest to highest priority):" "$category"
    set -l n 0
    for line in $sorted
        set n (math $n + 1)
        echo "  $n. "(echo -e $line | cut -f2)
    end
    echo

    set -l fzf_lines
    set -l n 0
    for line in $sorted
        set n (math $n + 1)
        set -l label (echo -e $line | cut -f2)
        set fzf_lines $fzf_lines (printf '%s\t%s' $n $label)
    end

    set -l picked (printf '%s\n' $fzf_lines | fzf --multi --with-nth=2 --delimiter='\t' \
        --prompt="$category > " \
        --header=(__vl_t "Tab = mark in the order you want, from LOWEST to HIGHEST priority | Enter = confirm | Esc = cancel"))

    if test (count $picked) -ne (count $sorted)
        __vl_t "Canceled or incomplete -- nothing was touched."
        return 1
    end

    set -l base 5000
    set -l step 1000
    set -l new_lines
    set -l rank 0
    for p in $picked
        set rank (math $rank + 1)
        set -l idx (echo $p | cut -f1)
        set -l rest (echo -e $sorted[$idx] | cut -f2-4)
        set -l prio (math $base + $step \* \( $rank - 1 \))
        set new_lines $new_lines (printf '%s\t%s' $prio $rest)
    end

    # The other category (the one not touched this time) is kept as it is
    # -- same priority it already had in the .conf (or its fallback if there was
    # still no rule).
    set -l other_sorted (_audio_priority_category $other_media_class $other_direction)

    set -l alsa_blocks
    set -l bluez_blocks
    _audio_priority_add_block $new_lines
    _audio_priority_add_block $other_sorted

    set -l tmp "$conf_file.tmp.$fish_pid"
    begin
        echo "## "(__vl_t "Session priority (which device is chosen by default) for audio output and")
        echo "## "(__vl_t "input. Higher priority.session/priority.driver = more preferred.")
        echo "## "(__vl_t "Generated by the fish function audio-priority -- dynamic detection via")
        echo "## "(__vl_t "pw-dump (python3), see the function's header comment for the detail.")
        echo "##"
        echo "## "(__vl_t "Requires node.restore-default-targets=false so that the priority always rules")
        echo "## "(__vl_t "instead of remembering the last device used -- this function")
        echo "## "(__vl_t "reaffirms it every time it runs, in case something resets it.")
        echo
        echo "monitor.alsa.rules = ["
        for b in $alsa_blocks
            echo $b
        end
        echo "]"
        echo
        echo "monitor.bluez.rules = ["
        for b in $bluez_blocks
            echo $b
        end
        echo "]"
    end > $tmp

    mv $tmp $conf_file

    wpctl settings -s node.restore-default-targets false

    __vl_t "Restarting wireplumber to apply (Bluetooth disconnects for a moment and comes back by itself)..."
    # Without systemd (Void): terminate the one there is, wait by notification for it to exit and
    # launch another in the background, outside this terminal (setsid).
    # The WirePlumber that PipeWire starts at login inherits from it SIGINT and SIGTERM
    # BLOCKED (SigBlk 0x4002 in /proc/<pid>/status): the SIGTERM stays
    # pending forever and pidwait never returned (2026-10-05, Legion). That is
    # why: SIGTERM, up to 3 s of waiting by notification and, if it is still alive, SIGKILL.
    # The one launched here (setsid) no longer has anything blocked.
    pkill -u (id -u) -x wireplumber
    if not timeout 3 pidwait -u (id -u) -x wireplumber 2>/dev/null
        pkill -KILL -u (id -u) -x wireplumber
        timeout 3 pidwait -u (id -u) -x wireplumber 2>/dev/null
    end
    setsid -f wireplumber </dev/null >/dev/null 2>&1

    echo
    __vl_t "%s -- new order (lowest to highest priority):" "$category"
    for line in $new_lines
        echo "  "(echo -e $line | cut -f1)": "(echo -e $line | cut -f2)
    end
    __vl_t "%s -- unchanged." "$other_label"
end
