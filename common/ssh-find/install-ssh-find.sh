#!/bin/bash
# install-ssh-find.sh — SSH between the home machines that does not depend on a single way of finding them
# (without root; 2026-10-16), the same on both machines:
#   ~/.local/bin/ssh-find               finds the machine by every way at once (see its header) and connects
#   ~/.config/ssh-find/hosts.conf       the machines: their names and the MACs known from local.env (it is only
#                                       created if missing: edit it to add a machine; the MACs of the other
#                                       interfaces are learned by themselves, in ~/.cache/ssh-find/state.json)
#   ~/.ssh/config                       a block at the top (between "# >>> ssh-find" and "# <<< ssh-find"):
#                                       ProxyCommand ssh-find and a fixed HostKeyAlias for every machine, so the
#                                       host key is checked whatever address it was found at
#   ~/.local/share/void-legion/         translations of the messages
# The Host blocks below (User, IdentityFile, HostName) stay as they are: with ssh-find, HostName is not used.
#   bash common/ssh-find/install-ssh-find.sh            installs or updates (keeps hosts.conf)
#   bash common/ssh-find/install-ssh-find.sh --remove   removes the block and the command (keeps hosts.conf)
# Check: ssh-find --list; ssh-find --where lego; ssh lego hostname. docs/2-base-system/2-network.md.
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
HERE=$(dirname "$(readlink -f "$0")")
BIN=~/.local/bin/ssh-find
CONF=~/.config/ssh-find/hosts.conf
SSHC=~/.ssh/config
BEGIN='# >>> ssh-find'; END='# <<< ssh-find'

strip_block() {   # the ssh config without our block
    [ -f "$SSHC" ] || return 0
    sed -i "/^$BEGIN\$/,/^$END\$/d" "$SSHC"
}

if is_remove "${1:-}"; then
    [ -f "$SSHC" ] && cp "$SSHC" "$SSHC.bak"
    strip_block
    rm -f "$BIN"
    t "ssh-find removed (hosts.conf and the learned addresses kept)"
    exit 0
fi

command -v python3 >/dev/null || { t "!! python3 is missing"; exit 1; }
install_i18n_user
mkdir -p ~/.local/bin ~/.config/ssh-find ~/.ssh
chmod 700 ~/.ssh
cp "$HERE/ssh-find" "$BIN.tmp" && chmod 755 "$BIN.tmp" && mv "$BIN.tmp" "$BIN"
t "== %s" "$BIN"

if [ ! -f "$CONF" ]; then
    load_local_env
    cat > "$CONF" <<EOF
# ssh-find's machines (common/ssh-find/install-ssh-find.sh). One section per alias of ~/.ssh/config:
#   names = names to resolve (mDNS, DNS, /etc/hosts) or fixed addresses, any number
#   macs  = MAC addresses of its interfaces (optional: the ones it connects through are learned)
#   key   = the HostKeyAlias: the name its host key is saved under in ~/.ssh/known_hosts
[lego]
names = Legion-Go-Gen-2.local Legion-Go-Gen-3.local
macs = ${LEGION_WIFI_MAC:-}
key = legion-go-gen-2.local

[ideapad]
names = ideapad-100.local
macs = ${IDEAPAD_WIFI_MAC:-}
key = ideapad-100.local

[deck]
names = steamdeck.local
key = steamdeck.local

[msi]
names = 192.168.0.115
key = msi
EOF
    t "== %s created" "$CONF"
else
    t "== %s kept" "$CONF"
fi

# The block: one Host per section of hosts.conf, with its HostKeyAlias, and ProxyCommand for all of them.
# At the top: in ~/.ssh/config the first value found wins.
ALIASES=$(sed -n 's/^\[\(.*\)\]$/\1/p' "$CONF" | tr '\n' ' ')
TMP=$(mktemp)
{
    echo "$BEGIN"
    echo "# Written by void-legion-go2's common/ssh-find/install-ssh-find.sh: do not edit between these lines"
    echo "# (it is rewritten; the machines are in ~/.config/ssh-find/hosts.conf)."
    for a in $ALIASES; do
        key=$(awk -v s="[$a]" '$0==s{f=1;next} /^\[/{f=0} f && $1=="key"{sub(/^[^=]*= */,""); print; exit}' "$CONF")
        echo "Host $a"
        echo "    HostKeyAlias ${key:-$a}"
    done
    echo "Host $ALIASES"
    echo "    ProxyCommand $BIN %n %p"
    echo "    CheckHostIP no"
    echo "$END"
    echo
} > "$TMP"
[ -f "$SSHC" ] && cp "$SSHC" "$SSHC.bak"
strip_block
[ -f "$SSHC" ] && cat "$SSHC" >> "$TMP"
mv "$TMP" "$SSHC"; chmod 600 "$SSHC"
t "== %s: block for %s" "$SSHC" "$ALIASES"
ssh -G lego >/dev/null 2>&1 || { t "!! ssh does not accept %s: the previous one is %s.bak" "$SSHC" "$SSHC"; exit 1; }
"$BIN" --list
