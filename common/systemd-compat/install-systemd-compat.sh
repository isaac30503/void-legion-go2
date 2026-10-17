#!/bin/sh
# install-systemd-compat.sh — systemd-compat: the systemctl, journalctl, systemd-run and systemd-inhibit that programs
# written for systemd call (Decky plugins made for SteamOS: Panel de Control, Colores…), answered on Void with runit,
# the session's processes and elogind. Nothing stays running (docs/2-base-system/4-systemd-compat.md).
#   /usr/local/lib/systemd-compat/   compat.sh, systemctl, journalctl, systemd-run, requires, MANIFEST
#   /usr/bin/systemctl, journalctl, systemd-run → those; /usr/bin/systemd-inhibit → elogind-inhibit (the same program,
#                                    renamed by elogind). Only on a free path or one already ours: never over a file of
#                                    a package or of someone else.
#   /etc/systemd-compat/units.d/50-void-legion.conf   replaced; the other files of units.d are yours and stay
#   the packages of "requires" that are missing
# Then it restarts Decky, if it runs: its plugins look for systemd only when they start.
#   sudo sh common/systemd-compat/install-systemd-compat.sh
#   sudo sh common/systemd-compat/install-systemd-compat.sh --remove   (keeps your files of units.d)
# Maintenance: void-update --systemd (what was asked and not served, plugins that changed how they call systemd).
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
HERE=$(dirname "$(readlink -f "$0")")
LIB=/usr/local/lib/systemd-compat
ETC=/etc/systemd-compat
CMDS="systemctl journalctl systemd-run"

ours() {   # PATH: a link of systemd-compat
    [ -L "$1" ] || return 1
    case $(readlink "$1") in "$LIB"/*|elogind-inhibit|/usr/bin/elogind-inhibit) return 0 ;; esac
    return 1
}
restart_decky() {
    if [ -e /var/service/decky ]; then sv restart decky >/dev/null 2>&1 && t "   Decky restarted (its plugins look for systemd again)"; fi
    return 0
}

if is_remove "${1:-}"; then
    for n in $CMDS systemd-inhibit; do ours "/usr/bin/$n" && rm -f "/usr/bin/$n"; done
    rm -rf "$LIB"
    rm -f "$ETC/units.d/50-void-legion.conf"
    rmdir "$ETC/units.d" "$ETC" 2>/dev/null || true
    rm -rf /run/systemd-compat
    restart_decky
    t "== systemd-compat removed (your files of %s stay)" "$ETC/units.d"
    exit 0
fi

t "== 1. the paths in /usr/bin"
for n in $CMDS systemd-inhibit; do
    p=/usr/bin/$n
    if [ -e "$p" ] || [ -L "$p" ]; then
        ours "$p" && continue
        owner=$(xbps-query -o "$p" 2>/dev/null | head -1)
        t "!! %s already exists and is not systemd-compat's (%s): nothing was installed" "$p" "${owner:-$(t "of no package")}"
        exit 1
    fi
done
[ -e /run/systemd/system ] && { t "!! /run/systemd/system exists: this machine runs systemd; systemd-compat is not for it"; exit 1; }
t "   free (or already systemd-compat's)"

t "== 2. packages"
missing=''
while read -r pkg _; do
    case $pkg in ''|\#*) continue ;; esac
    xbps-query "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
done < "$HERE/requires"
if [ -n "$missing" ]; then
    t "   installing:%s" "$missing"
    # shellcheck disable=SC2086  # a list of package names
    xbps-install -Sy $missing
else
    t "   all there"
fi

t "== 3. the commands (%s)" "$LIB"
mkdir -p "$LIB"
# One by one, each with a rename: a call that comes in the middle finds the old or the new file, never half of one
for f in compat.sh systemctl journalctl systemd-run requires; do
    case $f in compat.sh|requires) m=644 ;; *) m=755 ;; esac
    install -m "$m" "$HERE/$f" "$LIB/.$f.new" && mv -f "$LIB/.$f.new" "$LIB/$f"
done
{
    echo "# systemd-compat, installed $(date '+%Y-%m-%d %H:%M') from $REPO_ROOT"
    echo "repo=$REPO_ROOT"
    echo "commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    (cd "$LIB" && sha256sum compat.sh systemctl journalctl systemd-run requires)
    (cd "$HERE/units.d" && sha256sum 50-void-legion.conf | sed "s|  |  $ETC/units.d/|")
} > "$LIB/MANIFEST.new" && mv -f "$LIB/MANIFEST.new" "$LIB/MANIFEST"

t "== 4. the units (%s)" "$ETC/units.d"
mkdir -p "$ETC/units.d"
install -m 644 "$HERE/units.d/50-void-legion.conf" "$ETC/units.d/.50-void-legion.conf.new"
mv -f "$ETC/units.d/.50-void-legion.conf.new" "$ETC/units.d/50-void-legion.conf"
for f in "$ETC"/units.d/*.conf; do [ "$f" = "$ETC/units.d/50-void-legion.conf" ] || t "   yours, kept: %s" "$f"; done

t "== 5. links"
for n in $CMDS; do ln -sfn "$LIB/$n" "/usr/bin/$n"; done
ln -sfn elogind-inhibit /usr/bin/systemd-inhibit
ls -l /usr/bin/systemctl /usr/bin/journalctl /usr/bin/systemd-run /usr/bin/systemd-inhibit | sed 's/^/   /'

t "== 6. Decky's log (journalctl -u plugin_loader)"
if [ -f /etc/sv/decky/log/run ] && ! grep -q svlogd /etc/sv/decky/log/run; then
    t "   Decky still logs to syslog (vlogger), which nothing collects here: repeat %s so that it writes %s" "sudo sh $REPO_ROOT/common/steam/install-decky.sh" /var/log/decky/current
elif [ -f /etc/sv/decky/log/run ]; then
    t "   svlogd: %s" /var/log/decky/current
fi

t "== 7. check"
fail=0
v=$(systemctl is-system-running 2>/dev/null || true)
[ "$v" = offline ] && t "   ok  systemctl is-system-running = offline (programs still see that systemd is not running)" || { t "!!  systemctl is-system-running = %s" "$v"; fail=1; }
if [ -n "$TARGET_USER" ] && [ -d "/run/user/$(id -u "$TARGET_USER")" ]; then
    if sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" systemctl --user list-jobs >/dev/null 2>&1; then
        t "!!  systemctl --user list-jobs answers: Xfce's xinitrc would believe there is a systemd user session"; fail=1
    else t "   ok  systemctl --user list-jobs fails (Xfce's xinitrc: no systemd user session)"; fi
fi
if [ -e /var/service/inputplumber ]; then
    v=$(systemctl is-active inputplumber.service 2>/dev/null || true)
    [ "$v" = active ] && t "   ok  systemctl is-active inputplumber.service = active" || { t "!!  systemctl is-active inputplumber.service = %s" "$v"; fail=1; }
fi
if [ -e /var/service/decky ]; then
    v=$(systemctl is-active plugin_loader.service 2>/dev/null || true)
    [ "$v" = active ] && t "   ok  systemctl is-active plugin_loader.service = active (Decky)" || { t "!!  systemctl is-active plugin_loader.service = %s" "$v"; fail=1; }
fi
systemd-inhibit --list --no-pager >/dev/null 2>&1 && t "   ok  systemd-inhibit (elogind)" || { t "!!  systemd-inhibit --list fails"; fail=1; }
restart_decky
[ $fail = 0 ] && t "== done: void-update --systemd shows what programs ask for" || { t "!! something failed: see above"; exit 1; }
