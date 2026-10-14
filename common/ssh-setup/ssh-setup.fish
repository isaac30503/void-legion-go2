# Redoes the access to the Legion Go 2 after a reinstall.
#   legion-setup                 locates, installs the key, installs claude
#   ssh-setup --ip 192.168.1.70
#   legion-setup --diagnosis     only looks, touches nothing
#   legion-setup --no-claude
# (legion-setup: its old name; today it is ssh-setup [alias], see --help and docs/ssh-setup.md.)
#
# Its texts follow the system's language (__vl_t, translations in ~/.local/share/void-legion; the Spanish
# ones are the original texts). The x-ray (ssh-survey.sh) runs on the other machine: it is sent there, through
# the same stdin, with the local catalog and lib/i18n.sh in front, so it comes out in this language too.
# Previous name: herramientas/ssh-setup.fish (function ssh-setup, unchanged). Installed in
# ~/.config/fish/functions/ssh-setup.fish, with ssh-survey.sh in ~/.config/fish/ssh-survey.sh.

function __sshsetup_port --argument-names ip port wait
    # 0 = open | 1 = refused (nothing filters) | 124 = silence (firewall)
    test -z "$wait"; and set wait 5
    command timeout $wait bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
    return $status
end

function __sshsetup_networks
    # The /24s where it makes sense to search: mine, plus the usual ethernet one.
    set -l nets
    for addr in (command ip -4 -o addr show scope global | string replace -rf '.*inet ([0-9.]+)/.*' '$1')
        set -a nets (string join . (string split . $addr)[1..3])
    end
    set -a nets 192.168.1
    printf '%s\n' $nets | command sort -u
end

function __sshsetup_mine
    command ip -4 -o addr show scope global | string replace -rf '.*inet ([0-9.]+)/.*' '$1'
    command ip route | string match -r '^default via ([0-9.]+)' | tail -n +2
end

function __sshsetup_sweep --argument-names net
    # ICMP and not TCP: with sshd stopped there is no port to give the machine away.
    set -l script "for i in \$(seq 1 254); do (ping -c1 -W1 $net.\$i >/dev/null 2>&1 && echo $net.\$i) & done; wait"
    command bash -c $script 2>/dev/null
end

function __sshsetup_locate
    set -l mine (__sshsetup_mine)
    set -l alive
    for net in (__sshsetup_networks)
        echo "  "(__vl_t "sweeping %s ..." $net.0/24) >&2
        for h in (__sshsetup_sweep $net)
            contains -- $h $mine; or set -a alive $h
        end
    end
    if test (count $alive) -eq 0
        echo "  "(__vl_t "no machine answers the ping") >&2
        return 1
    end
    set -l withssh
    for h in $alive
        __sshsetup_port $h 22 3; and set -a withssh $h
    end
    if test (count $withssh) -eq 1
        echo $withssh[1]
        return 0
    end
    if test (count $withssh) -gt 1
        echo "  "(__vl_t "several machines with port 22 open: %s" "$withssh") >&2
        echo "  "(__vl_t "choose with: %s" "ssh-setup --ip <IP>") >&2
        return 1
    end
    echo "  "(__vl_t "alive but without port 22 open: %s" "$alive") >&2
    echo "  "(__vl_t "none accepts SSH yet; look at the diagnosis with %s" "--ip <IP>") >&2
    return 1
end

function __sshsetup_diagnosis --argument-names ip
    # It tells the three causes apart with a single extra test: a closed port.
    # A closed port refuses instantly if nothing filters; if it also stays silent,
    # the dropping is general and it is a firewall.
    __sshsetup_port $ip 22 6
    set -l s22 $status
    __sshsetup_port $ip 9999 6
    set -l sctl $status

    if test $s22 -eq 0
        if test $sctl -eq 124
            echo "  "(__vl_t "22 open, but there is a firewall with a targeted rule (port 9999 stays silent)")
        else
            # Careful: this does NOT prove there is no firewall. firewalld rejects
            # (immediate RST, same as a closed port) instead of dropping
            # silently like ufw. It only rules out ufw's pattern.
            echo "  "(__vl_t "22 open; the control port refuses instantly")
            echo "  "(__vl_t "(without a firewall, or with one that rejects instead of dropping)")
        end
        return 0
    end
    if test $sctl -eq 124
        set_color red; echo "  "(__vl_t "FIREWALL: ports 22 and 9999 are both silent"); set_color normal
        echo "  "(__vl_t "on the machine's console, type it by hand (do not paste it):")
        echo "      sudo ufw allow 22/tcp"
        echo "  "(__vl_t "or, if the active one is firewalld:")
        echo "      sudo firewall-cmd --permanent --add-service=ssh; sudo firewall-cmd --reload"
    else
        set_color red; echo "  "(__vl_t "SSHD STOPPED: port 22 refuses instantly, nothing filters"); set_color normal
        # Without SSH one cannot know which system the other side has: both are given.
        echo "  "(__vl_t "on the machine's console, the one that applies:")
        echo "      sudo systemctl enable --now sshd          # systemd: SteamOS, Arch, Fedora"
        echo "      sudo ln -s /etc/sv/sshd /var/service/     # runit: Void"
    end
    return 1
end

function __sshsetup_config --argument-names alias ip user
    set -l cfg ~/.ssh/config
    test -e $cfg; or command touch $cfg; and command chmod 600 $cfg
    if command grep -qE "^Host $alias\$" $cfg
        command cp $cfg $cfg.bak.(date +%F)
        command sed -i "/^Host $alias\$/,/^Host /{s/^\([[:space:]]*HostName[[:space:]]\+\).*/\1$ip/}" $cfg
        # The user also changes (SteamOS uses 'deck', CachyOS the user's own); if only
        # the IP is updated, ssh keeps trying to log in with the old user.
        command sed -i "/^Host $alias\$/,/^Host /{s/^\([[:space:]]*User[[:space:]]\+\).*/\1$user/}" $cfg
        echo "  ~/.ssh/config: '$alias' -> $user@$ip"
    else
        printf '\nHost %s\n    HostName %s\n    User %s\n    IdentityFile ~/.ssh/id_ed25519\n' $alias $ip $user >> $cfg
        echo "  ~/.ssh/config: "(__vl_t "block '%s' created" $alias)
    end
end

function __sshsetup_key --argument-names alias ip user
    if command ssh -o BatchMode=yes -o ConnectTimeout=8 $alias true 2>/dev/null
        echo "  "(__vl_t "the key already gets in, no password needed")
        return 0
    end
    if not test -f ~/.ssh/id_ed25519
        echo "  "(__vl_t "you had no ed25519 key, I generate it")
        command ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 -q
    end
    # The password goes in a separate file that the askpass reads, never embedded
    # in the script nor through the same stdin as a script: sudo -S would eat the
    # lines as attempts and faillock locks the account for 10 minutes.
    read -s -P "  "(__vl_t "password of %s: " $user@$ip) secret
    echo
    set -l tmp (command mktemp -d)
    command chmod 700 $tmp
    printf '%s\n' $secret > $tmp/pw
    printf '#!/bin/sh\n' > $tmp/askpass.sh
    printf 'cat %s\n' $tmp/pw >> $tmp/askpass.sh
    command chmod 700 $tmp/askpass.sh
    command env SSH_ASKPASS=$tmp/askpass.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
        setsid -w ssh-copy-id -o StrictHostKeyChecking=accept-new \
        -o PreferredAuthentications=password -o NumberOfPasswordPrompts=1 \
        -i ~/.ssh/id_ed25519.pub $user@$ip 2>&1 \
        | command grep -E 'Number of key|ERROR|Permission denied'
    set -l result $status
    command shred -u $tmp/pw $tmp/askpass.sh 2>/dev/null
    command rm -rf $tmp
    set -e secret
    echo "  "(__vl_t "[password file destroyed]")
    return $result
end

# What is sent to the other machine's "bash -s": the local catalog (if this language has one) and lib/i18n.sh,
# so that t() translates there too, and then ssh-survey.sh. The catalog goes to a temporary folder there
# that is deleted when the x-ray ends.
function __sshsetup_survey_input
    set -l survey ~/.config/fish/ssh-survey.sh
    set -l lib ~/.local/share/void-legion/lib/i18n.sh
    __vl_t "" >/dev/null   # finds this language's catalog (__vl_t_catalog)
    if set -q __vl_t_catalog; and test -n "$__vl_t_catalog"; and test -r $lib
        set -l lang (basename (dirname $__vl_t_catalog))
        echo '_VL_D=$(mktemp -d); trap '\''rm -rf "$_VL_D"'\'' EXIT; mkdir -p "$_VL_D/'$lang'"'
        echo 'cat > "$_VL_D/'$lang'/messages.po" <<'\''__VL_PO_END__'\'''
        command cat $__vl_t_catalog
        echo '__VL_PO_END__'
        echo 'export VOID_LEGION_LOCALE_DIR="$_VL_D" LANGUAGE='$lang
        command cat $lib
    end
    command cat $survey
end

function ssh-setup --description "Set up or redo SSH access to a machine of the local network"
    functions -q __vl_t; or function __vl_t; printf "$argv[1]\n" $argv[2..-1]; end
    argparse h/help i/ip= u/user= a/alias= d/diagnosis 'no-claude' -- $argv
    or return 1

    if set -q _flag_help
        echo "ssh-setup [alias] [--ip IP] [--user U] [--diagnosis] [--no-claude]"
        echo
        echo "  "(__vl_t "Sets up or redoes SSH access to a machine of the local network.")
        echo "  "(__vl_t "It looks for the machine, diagnoses the port, fixes known_hosts, installs")
        echo "  "(__vl_t "the key, writes the block in ~/.ssh/config, installs Claude Code and")
        echo "  "(__vl_t "shows an x-ray of the system.")
        echo
        echo "  "(__vl_t "The alias is the first argument. Without it, %s is used" '$ssh_setup_default_host')
        echo "  "(__vl_t "(set with: %s), and if that is not there either," 'set -U ssh_setup_default_host <alias>')
        echo "  "(__vl_t "'lego'. The user and the IP come from ~/.ssh/config if the alias already exists.")
        echo
        echo "  ssh-setup                                     # "(__vl_t "the Legion Go 2")
        echo "  ssh-setup fedora --ip 192.168.0.172 -u "(id -un)"  # "(__vl_t "setting up a new machine")
        echo "  ssh-setup fedora --diagnosis                  # "(__vl_t "only looks, touches nothing")
        return 0
    end

    # The alias is the first loose argument: ssh-setup fedora
    # When it is not given, it comes from $ssh_setup_default_host, which depends on the
    # machine: on the MSI and on the Fedora it is the console; on the console itself it
    # makes no sense to point at itself. It is set with:
    #     set -U ssh_setup_default_host <alias>
    set -l alias lego
    set -q ssh_setup_default_host; and test -n "$ssh_setup_default_host"; and set alias $ssh_setup_default_host
    test (count $argv) -gt 0; and set alias $argv[1]
    set -q _flag_alias; and set alias $_flag_alias
    # The user comes from ~/.ssh/config, not hardcoded here: it changes with the edition
    # (SteamOS uses 'deck', CachyOS the user's own) and the Host block already remembers the
    # last one that worked. --user rules over everything. Without either: the same name as here
    # (the original wrote the name of its owner, which is the same thing on their machines).
    set -l user (command ssh -G $alias 2>/dev/null | string replace -rf '^user (.*)' '$1')
    test -z "$user"; and set user (id -un)
    set -q _flag_user; and set user $_flag_user

    set_color --bold; echo (__vl_t "1. Locating the console"); set_color normal
    set -l ip
    if set -q _flag_ip
        set ip $_flag_ip
        echo "  "(__vl_t "using the IP you gave me: %s" $ip)
    else
        # First the usual one; the sweep only if that one does not answer.
        set -l previous (command ssh -G $alias 2>/dev/null | string replace -rf '^hostname (.*)' '$1')
        if test -n "$previous"; and command ping -c1 -W2 $previous >/dev/null 2>&1
            set ip $previous
            echo "  "(__vl_t "the usual one answers: %s" $ip)
        else
            test -n "$previous"; and echo "  "(__vl_t "%s no longer answers, time to sweep" $previous)
            set ip (__sshsetup_locate)
            or return 1
            echo "  "(__vl_t "found: %s" $ip)
        end
    end

    set_color --bold; echo; echo (__vl_t "2. Port diagnosis"); set_color normal
    if not __sshsetup_diagnosis $ip
        return 1
    end

    if set -q _flag_diagnosis
        set_color --bold; echo; echo (__vl_t "3. X-ray (I touch nothing else)"); set_color normal
        # BatchMode forced: without a key installed, ssh would try the password
        # three times and pam_faillock counts those failures to lock the
        # account. Diagnosing must never spend attempts.
        if not command ssh -o BatchMode=yes -o ConnectTimeout=10 $user@$ip true 2>/dev/null
            set_color yellow
            echo "  "(__vl_t "%s does not accept the key yet" $user@$ip)
            set_color normal
            echo "  "(__vl_t "the port is fine; the key still has to be installed. Run: %s" "ssh-setup --user $user")
            return 1
        end
        __sshsetup_survey_input | command ssh -o BatchMode=yes -o ConnectTimeout=10 $user@$ip bash -s
        return 0
    end

    set_color --bold; echo; echo (__vl_t "3. Host key"); set_color normal
    # A reinstall rotates the host's key: without deleting it, ssh shouts impersonation.
    command ssh-keygen -R $ip >/dev/null 2>&1
    set -l hostkey (command timeout 8 ssh-keyscan -t ed25519 $ip 2>/dev/null)
    if test -z "$hostkey"
        set_color red; echo "  "(__vl_t "the host hands over no key; is sshd still alive?"); set_color normal
        return 1
    end
    # Register it right away: otherwise, the passwordless access test of step 4
    # would fail because of an unknown host and would ask for a password needlessly.
    printf '%s\n' $hostkey >> ~/.ssh/known_hosts
    echo "  "(__vl_t "new fingerprint: %s" (printf '%s\n' $hostkey | command ssh-keygen -lf - 2>/dev/null))

    set_color --bold; echo; echo (__vl_t "4. Route and access key"); set_color normal
    __sshsetup_config $alias $ip $user
    __sshsetup_key $alias $ip $user
    or return 1

    if not command ssh -o BatchMode=yes -o ConnectTimeout=10 $alias true 2>/dev/null
        set_color red; echo "  "(__vl_t "the key does not get in; check the password"); set_color normal
        return 1
    end
    set_color green; echo "  "(__vl_t "'%s' gets in with the key" "ssh $alias"); set_color normal

    if not set -q _flag_no_claude
        set_color --bold; echo; echo "5. Claude Code"; set_color normal
        if command ssh $alias 'test -e ~/.local/bin/claude' 2>/dev/null
            echo "  "(__vl_t "it was already installed")
        else
            command ssh $alias 'curl -fsSL https://claude.ai/install.sh | bash' 2>&1 \
                | command grep -E 'Version|successfully|error'
        end
        # fish_add_path writes a universal variable; NEVER put 'export' in
        # config.fish, which is bash syntax and breaks every start of the shell.
        command ssh $alias "fish -c 'contains ~/.local/bin \$fish_user_paths; or fish_add_path ~/.local/bin'" 2>/dev/null
        echo "  "(__vl_t "fish's PATH: %s" (command ssh $alias "fish -c 'echo \$fish_user_paths'" 2>/dev/null))
    end

    set_color --bold; echo; echo (__vl_t "6. X-ray"); set_color normal
    __sshsetup_survey_input | command ssh -o ConnectTimeout=10 $alias bash -s
end
