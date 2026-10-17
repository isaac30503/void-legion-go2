# shellcheck shell=sh
# shellcheck disable=SC3043,SC2034  # "local": dash (Void's /bin/sh) has it; SC_* are read by the commands
# compat.sh — shared by systemd-compat's systemctl, journalctl and systemd-run (common/systemd-compat;
# docs/2-base-system/4-systemd-compat.md). Programs written for systemd (Decky plugins made for SteamOS, scripts)
# call those three with absolute paths; on Void (runit + elogind) they did not exist and the request failed.
# These answer them with the real thing underneath: runit services, processes of the session, elogind.
#
# POSIX sh (dash), sourced on every call: the frequent paths (is-active, show, a start or stop) use only
# builtins and the files they read; external programs only where the work needs them (sv, flock, setsid,
# a log line). Nothing stays running: a unit started here is the program itself, holding a lock (flock)
# that tells whether it is active; when it ends, the kernel releases the lock. No daemon, no polling.
#
# A unit name (".service" optional) resolves, in this order:
#   system scope: an entry of units.d (runit alias, exec unit or deny) → a transient unit of systemd-run →
#                 the runit service of the same name (/etc/sv/<unit>) → not found
#   user scope:   an entry of units.d → a transient unit → not found
# What is not emulated answers like systemctl on a machine not booted with systemd. Nothing here creates
# /run/systemd: programs that check whether "systemd is running" (dracut, mdadm, resolvconf…) still see it is not.
#
# Every request that is not fully served (unit not found, option not supported, partial answer) leaves one line
# in requests.log (root: /run/systemd-compat; a user: $XDG_RUNTIME_DIR/systemd-compat), for "void-update --systemd".
# Values of --setenv / Environment= are hidden there.

SC_VERSION=1
SC_ETC=${SYSTEMD_COMPAT_ETC:-/etc/systemd-compat}
SC_SV_DIR=${SYSTEMD_COMPAT_SV_DIR:-/etc/sv}
SC_SERVICE_DIR=${SYSTEMD_COMPAT_SERVICE_DIR:-/var/service}
SC_RUN=${SYSTEMD_COMPAT_RUN:-/run/systemd-compat}
SC_SV=${SYSTEMD_COMPAT_SV:-sv}
SC_KILL=${SYSTEMD_COMPAT_KILL:-/usr/bin/kill}   # util-linux: dash's kill cannot signal a process group
SC_DEFAULT_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Variables a unit started here receives from the caller, like systemd's service manager environment
SC_PASS_ENV="HOME USER LOGNAME SHELL LANG XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP"

SC_UID=
while read -r _k _v _; do [ "$_k" = Uid: ] && { SC_UID=$_v; break; }; done < /proc/self/status

# ---- the request, for the log ---------------------------------------------------------------------------
sc_req() {
    SC_REQ='' _hide=0
    for _a in "$@"; do
        if [ $_hide = 1 ]; then _a="${_a%%=*}=…"; _hide=0
        else
            case $_a in
                --setenv=*=*) _a=${_a#--setenv=}; _a="--setenv=${_a%%=*}=…" ;;
                -E|--setenv) _hide=1 ;;
                *Environment=*) _a="${_a%%Environment=*}Environment=…" ;;
            esac
        fi
        SC_REQ="$SC_REQ${SC_REQ:+ }$_a"
    done
}

# sc_log STATUS [DETAIL] — STATUS: not-found | unsupported | partial | failed
# shellcheck disable=SC3067  # test -O: dash has it
sc_log() {
    local d f c
    if [ "$SC_UID" = 0 ]; then d=$SC_RUN
    elif [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -O "$XDG_RUNTIME_DIR" ]; then d=$XDG_RUNTIME_DIR/systemd-compat
    else return 0; fi
    [ -d "$d" ] || mkdir -p "$d" 2>/dev/null || return 0
    f=$d/requests.log
    if [ -s "$f" ] && [ "$(wc -c < "$f")" -gt 262144 ]; then mv -f "$f" "$f.1"; fi
    c=$(tr '\0\n\t' '   ' < "/proc/$PPID/cmdline" 2>/dev/null | cut -c1-200)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$SC_UID" "$SC_TOOL" "$1" "$SC_REQ" "${c% }" "${2:-}" >> "$f" 2>/dev/null
    return 0
}

# ---- names and quoting ----------------------------------------------------------------------------------
sc_norm() { case $1 in *.service) SC_U=${1%.service} ;; *) SC_U=$1 ;; esac; }
# A unit name that is safe as a file name (no "/", no "..", no leading dot)
sc_valid() {
    case $1 in ''|.*|*/*|*..*) return 1 ;; *[!A-Za-z0-9:_.@-]*) return 1 ;; esac
    return 0
}
sc_is_pattern() { case $1 in *[*?[]*) return 0 ;; esac; return 1; }
# sc_q STRING → SC_Q, single-quoted for sh
sc_q() {
    local s o=
    s=$1
    while :; do
        case $s in
            *\'*) o="$o${s%%\'*}'\\''"; s=${s#*\'} ;;
            *) SC_Q="'$o$s'"; return 0 ;;
        esac
    done
}

# ---- units.d --------------------------------------------------------------------------------------------
# The commands turn globbing off while they handle unit names (a name may be a pattern); the folders here need it
sc_glob_on() { SC_NOGLOB=0; case $- in *f*) SC_NOGLOB=1; set +f ;; esac; }
sc_glob_restore() { [ "$SC_NOGLOB" = 1 ] && set -f; return 0; }
# sc_lookup SCOPE UNIT → the last matching line: SC_KIND (runit | exec | deny, or empty) and SC_REST
sc_lookup() {
    local f u s k r
    SC_KIND='' SC_REST=''
    sc_glob_on
    for f in "$SC_ETC"/units.d/*.conf; do
        [ -r "$f" ] || continue
        while read -r u s k r; do
            case $u in ''|\#*) continue ;; esac
            [ "$s" = "$1" ] || continue
            # shellcheck disable=SC2254  # the name in units.d may be a pattern (hhd@*)
            case $2 in $u) SC_KIND=$k SC_REST=$r ;; esac
        done < "$f"
    done
    sc_glob_restore
}

# sc_alias SERVICE → SC_ALIAS: the unit name of units.d that points to that runit service (or the service's name)
sc_alias() {
    local f u s k r
    SC_ALIAS=$1
    sc_glob_on
    for f in "$SC_ETC"/units.d/*.conf; do
        [ -r "$f" ] || continue
        while read -r u s k r; do
            case $u in ''|\#*) continue ;; esac
            [ "$s" = system ] && [ "$k" = runit ] && [ "${r%% *}" = "$1" ] && sc_valid "$u" && SC_ALIAS=$u
        done < "$f"
    done
    sc_glob_restore
}

# sc_base SCOPE → SC_BASE, the state folder of that scope (false: a user scope without its runtime folder)
sc_base() {
    if [ "$1" = system ]; then SC_BASE=$SC_RUN; return 0; fi
    [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ] || return 1
    SC_BASE=$XDG_RUNTIME_DIR/systemd-compat
}

# sc_resolve SCOPE UNIT → SC_TYPE: runit | proc | deny | none
#   runit: SC_SVC (the service), SC_LOGFILE (its log for journalctl, if known)
#   proc:  SC_DIR (state folder), SC_CMD (the command of an exec unit; empty for a transient one)
sc_resolve() {
    local scope=$1 unit=$2 o
    SC_TYPE=none SC_SVC='' SC_LOGFILE='' SC_DIR='' SC_CMD=''
    sc_lookup "$scope" "$unit"
    case $SC_KIND in
        deny) SC_TYPE=deny; return 0 ;;
        runit)
            # shellcheck disable=SC2086  # "SERVICE [log=FILE]": split on purpose
            set -- $SC_REST
            SC_SVC=${1:-}; [ $# -gt 0 ] && shift
            for o in "$@"; do case $o in log=*) SC_LOGFILE=${o#log=} ;; esac; done
            [ "$scope" = system ] && sc_valid "$SC_SVC" && [ -f "$SC_SV_DIR/$SC_SVC/run" ] && SC_TYPE=runit
            [ -n "$SC_LOGFILE" ] || SC_LOGFILE=/var/log/$SC_SVC/current
            return 0 ;;
        exec) SC_CMD=$SC_REST ;;
    esac
    sc_valid "$unit" || return 0
    sc_base "$scope" || return 0
    SC_DIR=$SC_BASE/units/$unit
    if [ -n "$SC_CMD" ] || [ -f "$SC_DIR/transient" ]; then SC_TYPE=proc; return 0; fi
    if [ "$scope" = system ] && [ -f "$SC_SV_DIR/$unit/run" ]; then
        SC_TYPE=runit SC_SVC=$unit SC_LOGFILE=/var/log/$unit/current
    fi
    return 0
}

# ---- runit ----------------------------------------------------------------------------------------------
# sc_runit_state SERVICE → SC_ACTIVE (active | inactive | activating | deactivating | unknown), SC_SUB, SC_PID
sc_runit_state() {
    local w rest st=$SC_SERVICE_DIR/$1/supervise
    SC_PID=0
    if [ ! -e "$SC_SERVICE_DIR/$1" ]; then SC_ACTIVE=inactive SC_SUB=dead; return 0; fi
    if [ ! -r "$st/stat" ]; then SC_ACTIVE=unknown SC_SUB=unknown; return 0; fi   # supervise/ is root's only
    read -r w rest < "$st/stat" || w=
    case $w in
        run*) SC_ACTIVE=active SC_SUB=running; read -r SC_PID < "$st/pid" || SC_PID=0; [ -n "$SC_PID" ] || SC_PID=0 ;;
        finish*) SC_ACTIVE=deactivating SC_SUB=stop-post ;;
        down*) case $rest in *"want up"*) SC_ACTIVE=activating SC_SUB=auto-restart ;; *) SC_ACTIVE=inactive SC_SUB=dead ;; esac ;;
        *) SC_ACTIVE=unknown SC_SUB=unknown ;;
    esac
}
sc_runit_enabled() { [ -e "$SC_SERVICE_DIR/$1" ] && [ ! -e "$SC_SV_DIR/$1/down" ]; }

# sc_ancestor PID: PID is this process or one of its ancestors
sc_ancestor() {
    local p=$$ n k v
    while [ "$p" -gt 1 ] 2>/dev/null; do
        [ "$p" = "$1" ] && return 0
        [ -r "/proc/$p/status" ] || return 1
        n=
        while read -r k v _; do [ "$k" = PPid: ] && { n=$v; break; }; done < "/proc/$p/status"
        [ -n "$n" ] || return 1
        p=$n
    done
    return 1
}

# sc_runit_do start|stop|restart|reload SERVICE NOBLOCK — sv waits for the result (SVWAIT, 7 s). Detached when
# asked (--no-block) or when the caller runs inside that service: a Decky plugin restarting Decky would be killed
# halfway; systemd does it as a job of its own, and so does this.
sc_runit_do() {
    local pid detach=$3
    if [ -r "$SC_SERVICE_DIR/$2/supervise/pid" ]; then
        read -r pid < "$SC_SERVICE_DIR/$2/supervise/pid" || pid=
        [ -n "$pid" ] && sc_ancestor "$pid" && detach=1
    fi
    if [ "$detach" = 1 ]; then setsid -f "$SC_SV" "$1" "$SC_SERVICE_DIR/$2" >/dev/null 2>&1; return 0; fi
    "$SC_SV" "$1" "$SC_SERVICE_DIR/$2" >/dev/null 2>&1
}

# ---- process units (exec units of units.d and transient units of systemd-run) ---------------------------
# Folder: lock (held by the running program), pid, invocation, log, run (the command), transient, description.
sc_proc_active() { [ -f "$1/lock" ] && ! flock -n -s "$1/lock" true 2>/dev/null; }
sc_proc_state() {
    SC_PID=0 SC_INV=
    if sc_proc_active "$1"; then
        SC_ACTIVE=active SC_SUB=running
        read -r SC_PID < "$1/pid" 2>/dev/null || SC_PID=0
        read -r SC_INV < "$1/invocation" 2>/dev/null || SC_INV=
    else SC_ACTIVE=inactive SC_SUB=dead; fi
}

# sc_envline → SC_ENV: "env -i" with the variables of SC_PASS_ENV the caller has, and PATH
sc_envline() {
    local n v
    SC_ENV="env -i"
    for n in $SC_PASS_ENV; do
        eval "v=\${$n-}"; eval "[ -n \"\${$n+x}\" ]" || continue
        sc_q "$n=$v"; SC_ENV="$SC_ENV $SC_Q"
    done
    sc_q "PATH=${PATH:-$SC_DEFAULT_PATH}"; SC_ENV="$SC_ENV $SC_Q"
}

# sc_write_exec_run DIR COMMAND: the run script of an exec unit (the command of units.d, a shell line)
sc_write_exec_run() {
    sc_envline
    sc_q "exec $2"
    printf '#!/bin/sh\nexec %s /bin/sh -c %s\n' "$SC_ENV" "$SC_Q" > "$1/run.new" && chmod 700 "$1/run.new" && mv -f "$1/run.new" "$1/run"
}

# sc_proc_start DIR — starts DIR/run in a session of its own (its process group is the unit), with the lock held
# from before it exists until its last process ends. Already active: nothing.
sc_proc_start() {
    local d=$1 i inv='' rest
    exec 9>>"$d/lock"
    if ! flock -w 1 9; then exec 9>&-; return 0; fi
    if [ -s "$d/log" ] && [ "$(wc -c < "$d/log")" -gt 1048576 ]; then mv -f "$d/log" "$d/log.1"; fi
    read -r i < /proc/sys/kernel/random/uuid
    rest=$i
    while :; do case $rest in *-*) inv=$inv${rest%%-*}; rest=${rest#*-} ;; *) inv=$inv$rest; break ;; esac; done
    printf '%s\n' "$inv" > "$d/invocation"
    printf -- '-- start %s %s\n' "$(date +%s)" "$inv" >> "$d/log"
    setsid "$d/run" >> "$d/log" 2>&1 < /dev/null &
    printf '%s\n' "$!" > "$d/pid"
    exec 9>&-
    return 0
}

# sc_proc_stop DIR NOBLOCK — SIGTERM to its process group, then waits for the lock (the kernel releases it when the
# last process ends: no polling); after 10 s, SIGKILL.
sc_proc_stop() {
    local d=$1 pid
    sc_proc_active "$d" || return 0
    read -r pid < "$d/pid" 2>/dev/null || return 0
    "$SC_KILL" -s TERM -- "-$pid" 2>/dev/null || "$SC_KILL" -s TERM "$pid" 2>/dev/null
    if [ "$2" = 1 ]; then
        setsid -f sh -c 'flock -w 10 "$1" true || "$3" -s KILL -- "-$2"' sh "$d/lock" "$pid" "$SC_KILL" >/dev/null 2>&1
        return 0
    fi
    flock -w 10 "$d/lock" true 2>/dev/null && return 0
    "$SC_KILL" -s KILL -- "-$pid" 2>/dev/null
    flock -w 5 "$d/lock" true 2>/dev/null
}
