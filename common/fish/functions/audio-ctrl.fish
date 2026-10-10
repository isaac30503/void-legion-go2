# Choose audio Output or Input, then which device, and edit its
# volume with an interactive bar (arrows + text). Before choosing the
# device, it detects live (via `pactl list sinks`/`sources`) all those
# connected right now -- if there is only one for that category, it uses it
# directly without asking. From there, two ways of editing, always
# in sync with each other:
#   - Bar: left/right arrows raise/lower in steps.
#   - Text: the number is typed directly with the keyboard.
# Up selects the bar, down selects the text -- that is where
# left/right (bar) or the digits/backspace (text) act. Each change is
# applied right away with pactl, to hear the effect at the moment. Enter
# confirms and leaves, Ctrl-C or "q" cancels and goes back to the volume there was before
# opening the bar.
#
# The detection uses `pactl list sinks`/`sources` (not pw-dump like
# audio-priority.fish): on the Legion with SteamOS the "real" nodes of pw-dump
# were not controllable by pactl (one had to operate with the
# `alsa_loopback_device.*` that wrapped them). On Void (2026-10-05) there are none of
# those wrappers and pactl sees the alsa_output.*/alsa_input.* directly;
# with pactl the function works the same in both cases.
#
# Version for Void (Legion and IdeaPad), adapted on 2026-10-05 from
# fish/arch/brew/audio-ctrl.fish (the SteamOS one): only this
# comment changes. It needs pactl and fzf (both are already on both machines).
#
# It also lists the pci/usb cards that are "off" (current profile without
# output/input, for example "Off") like KDE's Sound panel --
# choosing them goes straight to the profile chooser to turn them on again,
# instead of leaving them invisible until their profile is changed by hand. If
# instead you choose on purpose a profile without output/input (e.g. "Off"), it is
# applied anyway -- the next time audio-ctrl opens, that card will
# show as off with the option to turn it on again.
#
# It reads the keys byte by byte with `dd` instead of fish's builtin `read`: if
# stdin is a terminal, `read` enters its own interactive mode (with
# its own prompt and its arrow/history bindings) that does not let through the
# raw escape sequences -- `dd` does a plain read(2), so with the
# terminal in raw mode (`stty raw -echo`) an arrow
# (ESC [ A/B/C/D) can be told apart from a normal key.
#
# The fill color of the bar marks the level (green/yellow/red, like
# a VU meter) to warn when the volume/gain gets close to the top,
# where it starts to distort.
#
# Its texts follow the system's language (__vl_t, translations in ~/.local/share/void-legion; the Spanish
# ones are the original texts). Previous name: audio-ctrl (unchanged).
function audio-ctrl --description "Choose audio output or input and edit its volume with an interactive bar (arrows + text)"
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    if not command -q pactl
        __vl_t "Error: pactl is needed." >&2
        return 1
    end
    if not command -q fzf
        __vl_t "Error: fzf is needed." >&2
        return 1
    end
    if not isatty stdin
        __vl_t "Error: audio-ctrl needs an interactive terminal." >&2
        return 1
    end

    set -l label_output (__vl_t "Output")
    set -l label_input (__vl_t "Input")
    set -l category (printf '%s\n' $label_output $label_input | fzf --prompt="audio-ctrl > " --header=(__vl_t "Choose what to control: Output or Input"))
    if test -z "$category"
        __vl_t "Canceled, nothing was touched."
        return 1
    end

    # Everything that changes between Output (sinks) and Input (sources) stays
    # parameterized here -- the rest of the function does not ask again which
    # of the two it is.
    set -l pactl_list sources
    set -l pactl_get_default get-default-source
    set -l pactl_get_vol get-source-volume
    set -l pactl_set_vol set-source-volume
    set -l record_marker 'Source #'
    set -l cap_field sources
    set -l filter_monitor 1
    set -l node_icon \uf130    # Nerd Font icon (written as an escape so that it is not lost when copying)
    set -l word (__vl_t "audio input")
    if test "$category" = "$label_output"
        set pactl_list sinks
        set pactl_get_default get-default-sink
        set pactl_get_vol get-sink-volume
        set pactl_set_vol set-sink-volume
        set record_marker 'Sink #'
        set cap_field sinks
        set filter_monitor 0
        set node_icon \uf028
        set word (__vl_t "audio output")
    end

    set -l default_node (pactl $pactl_get_default)
    set -l node_names
    set -l node_labels
    set -l node_cards
    set -l node_buses
    set -l node_needs_profile
    set -l default_suffix (__vl_t "(default)")

    # It gathers the data of a node (they get filled in little by little: Name
    # appears first, Description right after, but device.bus/device.name
    # only show further down in the Properties section of the same block) --
    # that is why they are dumped into the arrays only when the next node
    # starts (or when the last block ends).
    set -l cur_name ""
    set -l cur_label ""
    set -l cur_bus ""
    set -l cur_card ""
    set -l has_record 0

    function _audio_ctrl_flush_node --no-scope-shadowing
        if test $has_record -eq 0
            return
        end
        # In Input, those ending in ".monitor" are the internal loopback
        # of an output (to record what plays through the speakers), not a
        # microphone -- it makes no sense to offer them here. In Output this
        # case does not exist (sinks have no ".monitor" version of themselves).
        if test $filter_monitor -eq 1; and string match -qr '\.monitor$' -- $cur_name
            return
        end
        set -l label $cur_label
        if test "$cur_name" = "$default_node"
            set label "$label $default_suffix"
        end
        set -a node_names $cur_name
        set -a node_labels $label
        set -a node_cards $cur_card
        set -a node_buses $cur_bus
        set -a node_needs_profile 0
    end

    for line in (pactl list $pactl_list | string match -r 'Name: .*|Description: .*|device\.bus = .*|device\.name = .*')
        switch $line
            case 'Name: *'
                _audio_ctrl_flush_node
                set cur_name (string replace -r '^Name: ' '' -- $line)
                set cur_label ""
                set cur_bus ""
                set cur_card ""
                set has_record 1
            case 'Description: *'
                set cur_label (string replace -r '^Description: ' '' -- $line)
            case 'device.bus = *'
                set cur_bus (string match -rg -- '"([^"]*)"' $line)
            case 'device.name = *'
                set cur_card (string match -rg -- '"([^"]*)"' $line)
        end
    end
    _audio_ctrl_flush_node

    # Returns, one per line, "id\tdescription\tsinks\tsources\tis_current(0/1)"
    # of each available profile of a card -- it is used both to detect
    # cards that are off (current profile without capacity in $cap_field, further
    # down) and to build the real menu of profiles.
    function _audio_ctrl_card_profiles --no-scope-shadowing
        set -l card_block (pactl list cards | awk -v RS='Card #' -v want="Name: $argv[1]" '$0 ~ want {print; exit}')
        set -l active (string match -rg -- 'Active Profile: (\S+)' $card_block)
        for line in $card_block
            set -l m (string match -rg -- '^\s*([a-zA-Z0-9_:+.-]+): (.+) \(sinks: ([0-9]+), sources: ([0-9]+), priority: [0-9]+, available: yes\)$' $line)
            if test (count $m) -eq 4
                set -l is_active 0
                test "$m[1]" = "$active"; and set is_active 1
                printf '%s\t%s\t%s\t%s\t%s\n' $m[1] $m[2] $m[3] $m[4] $is_active
            end
        end
    end

    # Column of _audio_ctrl_card_profiles that corresponds to $cap_field
    # (3 = sinks, 4 = sources).
    set -l col_cap 3
    test "$cap_field" = sources; and set col_cap 4

    # pci/usb cards that already have a real node stayed above. Those that
    # do not -- for example, a card whose profile was left at "Off" and that is why it does not
    # appear in `pactl list sinks/sources` -- are offered anyway, as an "off"
    # node: choosing it goes straight to the profile chooser further below,
    # to be able to turn it on again without having to guess the card's name
    # by hand (like KDE's Sound panel).
    set -l cn ""
    set -l cl ""
    set -l cb ""
    set -l hc 0

    function _audio_ctrl_flush_card --no-scope-shadowing
        if test $hc -eq 0
            return
        end
        if test "$cb" = bluetooth
            return
        end
        if contains -- $cn $node_cards
            return
        end
        set -l profs (_audio_ctrl_card_profiles $cn)
        set -l active_desc ""
        set -l active_cap 1
        set -l some_profile_works 0
        for p in $profs
            if test (echo -e $p | cut -f$col_cap) -gt 0
                set some_profile_works 1
            end
            if test (echo -e $p | cut -f5) = 1
                set active_desc (echo -e $p | cut -f2)
                set active_cap (echo -e $p | cut -f$col_cap)
            end
        end
        # If no profile of this card can give $word (e.g. a pure
        # output card in the Input case), it makes no sense to
        # offer it as "off" here.
        if test "$active_cap" -eq 0; and test "$some_profile_works" -eq 1
            set -a node_names ""
            set -a node_labels (__vl_t "%s (no active %s -- profile: %s)" "$cl" "$word" "$active_desc")
            set -a node_cards $cn
            set -a node_buses $cb
            set -a node_needs_profile 1
        end
    end

    for line in (pactl list cards | string match -r 'Name: .*|device\.description = .*|device\.bus = .*')
        switch $line
            case 'Name: *'
                _audio_ctrl_flush_card
                set cn (string replace -r '^Name: ' '' -- $line)
                set cl ""
                set cb ""
                set hc 1
            case 'device.description = *'
                set cl (string match -rg -- '"([^"]*)"' $line)
            case 'device.bus = *'
                set cb (string match -rg -- '"([^"]*)"' $line)
        end
    end
    _audio_ctrl_flush_card

    if test (count $node_names) -eq 0
        __vl_t "Error: no %s was detected." "$word" >&2
        return 1
    end

    set -l node_id
    set -l node_label
    set -l node_card
    set -l node_bus
    set -l needs_profile
    if test (count $node_names) -eq 1
        set node_id $node_names[1]
        set node_label $node_labels[1]
        set node_card $node_cards[1]
        set node_bus $node_buses[1]
        set needs_profile $node_needs_profile[1]
    else
        set -l fzf_lines
        for i in (seq (count $node_names))
            set -a fzf_lines (printf '%s\t%s' $i $node_labels[$i])
        end
        set -l picked (printf '%s\n' $fzf_lines | fzf --delimiter='\t' --with-nth=2 \
            --prompt="$word > " --header=(__vl_t "Choose which %s to edit" "$word"))
        if test -z "$picked"
            __vl_t "Canceled, nothing was touched."
            return 1
        end
        set -l idx (echo -e $picked | cut -f1)
        set node_id $node_names[$idx]
        set node_label $node_labels[$idx]
        set node_card $node_cards[$idx]
        set node_bus $node_buses[$idx]
        set needs_profile $node_needs_profile[$idx]
    end

    # If the chosen node is internal (pci bus, not usb/bluetooth) or is an
    # "off" card (needs_profile), the profile of that card can also be chosen
    # (Pro Audio, Analog Stereo Duplex, etc, the same that
    # appear in System Settings > Sound) and applied right away --
    # different profiles expose different sink/source, so after
    # changing the real node has to be detected again to keep editing
    # its volume.
    if test "$node_bus" = pci; or test "$needs_profile" = 1
        set -l active_profile (string match -rg -- 'Active Profile: (\S+)' (pactl list cards | awk -v RS='Card #' -v want="Name: $node_card" '$0 ~ want {print; exit}'))

        set -l profile_ids
        set -l profile_labels
        set -l current_suffix (__vl_t "(current)")
        for p in (_audio_ctrl_card_profiles $node_card)
            set -a profile_ids (echo -e $p | cut -f1)
            set -l plabel (echo -e $p | cut -f2)
            if test (echo -e $p | cut -f5) = 1
                set plabel "$plabel $current_suffix"
            end
            set -a profile_labels $plabel
        end

        if test $needs_profile = 1; and test (count $profile_ids) -le 1
            __vl_t "Error: '%s' has no profiles with %s." "$node_label" "$word" >&2
            return 1
        end

        if test (count $profile_ids) -gt 1
            set -l fzf_lines
            for i in (seq (count $profile_ids))
                set -a fzf_lines (printf '%s\t%s' $i $profile_labels[$i])
            end
            set -l picked (printf '%s\n' $fzf_lines | fzf --delimiter='\t' --with-nth=2 \
                --prompt=(__vl_t "profile > ") --header=(__vl_t "Choose profile for %s" "$node_label"))
            if test -z "$picked"
                if test "$needs_profile" = 1
                    __vl_t "Canceled -- '%s' is still without %s." "$node_label" "$word" >&2
                    return 1
                end
            else
                set -l idx (echo -e $picked | cut -f1)
                set -l new_profile $profile_ids[$idx]
                if test "$new_profile" = "$active_profile"
                    if test "$needs_profile" = 1
                        __vl_t "Error: that is the current profile and it has no %s -- choose another one." "$word" >&2
                        return 1
                    end
                else
                    pactl set-card-profile $node_card $new_profile
                    sleep 0.3
                    set -l new_node
                    for candidate in (pactl list $pactl_list | awk -v RS="$record_marker" -v card="device.name = \"$node_card\"" '$0 ~ card {print}' | string match -r 'Name: .*' | string replace -r '^Name: ' '')
                        if test $filter_monitor -eq 1; and string match -qr '\.monitor$' -- $candidate
                            continue
                        end
                        set -a new_node $candidate
                    end
                    if test (count $new_node) -eq 0
                        # Choosing a profile without $word here is intentional --
                        # as in KDE's panel, it is applied anyway. The
                        # next time audio-ctrl opens, this card will
                        # show as "off" with the option to choose a
                        # profile again to turn it on.
                        __vl_t "'%s' now on '%s' -- without %s for now." "$node_label" "$profile_labels[$idx]" "$word"
                        return 0
                    end
                    set node_id $new_node[1]
                    set node_label "$node_label ($profile_labels[$idx])"
                end
            end
        else if test "$needs_profile" = 1
            __vl_t "Error: there is no other profile with %s to choose." "$word" >&2
            return 1
        end
    end

    if test -z "$node_id"
        __vl_t "Error: no %s could be determined." "$word" >&2
        return 1
    end

    set -l orig_vol (pactl $pactl_get_vol $node_id | string match -r -- '[0-9]+%')[1]
    set orig_vol (string replace '%' '' -- $orig_vol)
    set -l vol $orig_vol
    set -l text "$vol"
    set -l focus bar
    set -l step 5
    set -l width 30

    set -l reset \x1b\x5b0m
    set -l dim \x1b\x5b2m
    set -l bold \x1b\x5b1m
    set -l green \x1b\x5b1\x3b32m
    set -l yellow \x1b\x5b1\x3b33m
    set -l red \x1b\x5b1\x3b31m
    set -l pencil_icon \uf040
    set -l text_label (__vl_t "text:")

    # Decodes a raw key (possibly a multi-byte escape sequence)
    # to a symbolic name: left/right/up/down/enter/
    # backspace/cancel/digit:N/ignore.
    function _audio_ctrl_readkey --no-scope-shadowing
        set -l b1 (dd bs=1 count=1 2>/dev/null)
        set -l h1 (printf '%s' "$b1" | od -An -tx1 | string trim)
        switch "$h1"
            case 1b
                set -l b2 (dd bs=1 count=1 2>/dev/null)
                set -l h2 (printf '%s' "$b2" | od -An -tx1 | string trim)
                if test "$h2" = 5b
                    set -l b3 (dd bs=1 count=1 2>/dev/null)
                    set -l h3 (printf '%s' "$b3" | od -An -tx1 | string trim)
                    switch "$h3"
                        case 41
                            echo up
                        case 42
                            echo down
                        case 43
                            echo right
                        case 44
                            echo left
                        case '*'
                            echo ignore
                    end
                else
                    echo ignore
                end
            case 0d 0a
                echo enter
            case 7f 08
                echo backspace
            case 03 ''
                echo cancel
            case '*'
                if string match -qr '^[0-9]$' -- "$b1"
                    echo "digit:$b1"
                else if string match -qi -- q "$b1"
                    echo cancel
                else
                    echo ignore
                end
        end
    end

    set -l first 1

    function _audio_ctrl_draw --no-scope-shadowing
        set -l filled (math --scale=0 "$vol * $width / 100")
        set -l empty (math $width - $filled)
        set -l fill_str (string repeat -n $filled '█')
        set -l empty_str (string repeat -n $empty '░')
        set -l bar_body "$fill_str$empty_str"

        set -l level $green
        if test $vol -ge 85
            set level $red
        else if test $vol -ge 60
            set level $yellow
        end

        set -l focus_bar $dim
        set -l focus_text $dim
        if test "$focus" = bar
            set focus_bar $bold
        else
            set focus_text $bold
        end

        if test "$first" -eq 0
            printf '\x1b[1A\r\x1b[0J'
        end
        set first 0

        set -l pct (printf '%3d' $vol)
        set -l bar_line "$focus_bar▏$reset$level$bar_body$dim$reset$focus_bar▕$reset $level$pct%$reset"
        printf '%s\n' "$bar_line"

        set -l cursor ''
        test "$focus" = text; and set cursor "$bold▏$reset"
        set -l text_line "$focus_text$pencil_icon $text_label $text$reset$cursor"
        printf '%s' "$text_line"
    end

    set -l old_stty (stty -g)

    function _audio_ctrl_restore --no-scope-shadowing
        stty $old_stty
        printf '\n'
    end

    function _audio_ctrl_onsig --on-signal INT --on-signal TERM --no-scope-shadowing
        _audio_ctrl_restore
        exit 130
    end

    echo "$node_icon$bold $node_label$reset"
    echo "$dim"(__vl_t "← → adjust   ↕ bar/text   ↵ confirm   ^C/q cancel")"$reset"

    stty raw -echo
    _audio_ctrl_draw

    while true
        set -l key (_audio_ctrl_readkey)
        switch $key
            case up
                set focus bar
                if test -z "$text"
                    set text "$vol"
                end
            case down
                set focus text
                set text ""
            case left
                if test "$focus" = bar
                    set vol (math --scale=0 "max($vol - $step, 0)")
                    set text "$vol"
                    pactl $pactl_set_vol $node_id "$vol%"
                end
            case right
                if test "$focus" = bar
                    set vol (math --scale=0 "min($vol + $step, 100)")
                    set text "$vol"
                    pactl $pactl_set_vol $node_id "$vol%"
                end
            case 'digit:*'
                if test "$focus" = text
                    set -l d (string replace 'digit:' '' $key)
                    set -l new "$text$d"
                    if test "$new" -le 100 2>/dev/null
                        set text $new
                        set vol $new
                        pactl $pactl_set_vol $node_id "$vol%"
                    end
                end
            case backspace
                if test "$focus" = text
                    set -l len (string length -- "$text")
                    if test $len -gt 0
                        set text (string sub -l (math $len - 1) -- "$text")
                    end
                    if test -n "$text"
                        set vol $text
                        pactl $pactl_set_vol $node_id "$vol%"
                    end
                end
            case enter
                if test -z "$text"
                    set text "$vol"
                end
                _audio_ctrl_draw
                break
            case cancel
                pactl $pactl_set_vol $node_id "$orig_vol%"
                set vol $orig_vol
                set text "$vol"
                _audio_ctrl_draw
                break
        end
        _audio_ctrl_draw
    end

    _audio_ctrl_restore
    echo "$node_label: $vol%"
end
