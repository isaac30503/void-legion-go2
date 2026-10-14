# shellcheck shell=bash
# Start fish from bash instead of setting it as the login shell.
#
# Reason: the login shell lives in /etc/passwd and the list of valid shells in
# /etc/shells. If the fish binary or its line in /etc/shells is ever lost
# separately, a login shell pointing there would leave the account unable to
# log in (it is what happened on the Legion with SteamOS). On Void the risk is
# lower -- /etc is not rebuilt and xbps registers fish in /etc/shells when
# installing it -- but the machines of the network are configured the same. With /bin/bash
# as the login shell the configuration fails on the safe side: in the worst case
# a usable bash session remains instead of a broken login.
#
# Void does not ship ~/.bashrc.d: it is created by hand and ~/.bashrc goes through it at the end
# (see the block added there, common/shell/bashrc-block.sh).
# Previous name: 99-exec-fish.sh (unchanged).

# Void's .bashrc already has its non-interactive guard, but this file does not
# depend on it: without it the exec would fire in scp, rsync and in the single
# commands over SSH, and would break them all.
case $- in
    *i*) ;;
    *) return ;;
esac

# BASH_EXEC_FISH avoids the loop if bash is opened again from fish: in that case
# bash stays as bash, on purpose. The test -x is the safety net.
if [ -z "$BASH_EXEC_FISH" ] && [ -x /usr/bin/fish ]; then
    export BASH_EXEC_FISH=1
    exec /usr/bin/fish
fi
