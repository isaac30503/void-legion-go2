#!/bin/sh
# install-decky.sh — Decky Loader (plugins for Steam's Game Mode) on Void, with runit.
# It does the same as the official installer (decky-installer/install_release.sh) and as Bazzite
# (ujust setup-decky), changing the systemd service for a runit one:
#   - ~/homebrew/{services,plugins} and ~/.steam/steam/.cef-enable-remote-debugging (Decky
#     connects to Steam's interface through its debugging port; Steam reads it on start);
#   - the PluginLoader binary of the latest stable version (GitHub), in ~/homebrew/services;
#   - /etc/sv/decky: PluginLoader as root with the same variables as its systemd service
#     (PLUGIN_PATH, LOG_LEVEL) plus UNPRIVILEGED_USER/PATH and KEEP_SYSTEMD_SERVICE=1 (without it, when
#     updating itself from its menu it tries to write /etc/systemd/system/plugin_loader.service);
#   - psmisc (killall: Decky restarts steamwebhelper with it); lsof already comes;
#   - /home/deck -> the user's home, like Bazzite: some plugins take that path for granted.
# Decky detects the init through /sbin/init (here runit-init, which it does not know): its service commands
# do nothing. It looks for updates by itself (every 6 h) and they are applied with a click from its menu: it writes
# the new version in .loader.version, changes the binary and asks to restart, which it cannot do here.
# That is why the service waits, EVENT-DRIVEN (inotify, without querying anything meanwhile), for the sign
# that Decky finished updating itself (updater.py, download_decky_binary): it downloads to
# PluginLoader.new, writes the version in .loader.version, deletes PluginLoader, renames
# .new → PluginLoader and, as the last step, gives it execute permission. "different version,
# PluginLoader.new does not exist and PluginLoader is executable" = finished. Then it closes
# PluginLoader and runit starts it again with the new version. (inotify-tools: inotifywait.)
# Its output goes to /var/log/decky/current (svlogd: 1 MB × 2 files; 2026-10-17): systemd-compat's journalctl reads it
# for "journalctl -u plugin_loader" (common/systemd-compat, docs/2-base-system/4-systemd-compat.md). Repeating the
# installer with the latest version already there does not download it again.
# Previous (Spanish) name: instalar-decky.sh (its FIFO was /run/decky-avisos).
#   sudo sh common/steam/install-decky.sh            installs or updates
#   sudo sh common/steam/install-decky.sh --remove   removes it (leaves ~/homebrew/plugins)
# docs/6-game-mode/5-decky.md.
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
U=$TARGET_USER
H=$TARGET_HOME
HB="$H/homebrew"
SV=/etc/sv/decky
CEF="$H/.steam/steam/.cef-enable-remote-debugging"

if is_remove "${1:-}"; then
    rm -f /var/service/decky
    sleep 2
    rm -rf "$SV" "$HB/services"
    rm -f "$CEF"
    [ -L /home/deck ] && rm -f /home/deck
    t "== removed (the plugins stay in %s/plugins; restart Steam)" "$HB"
    exit 0
fi

t "== 1. packages"
command -v killall >/dev/null || xbps-install -Sy psmisc
command -v inotifywait >/dev/null || xbps-install -Sy inotify-tools

t "== 2. folders and Steam's remote debugging"
sudo -u "$U" mkdir -p "$HB/services" "$HB/plugins" "$H/.steam/steam"
sudo -u "$U" touch "$CEF"
[ -e /home/deck ] || ln -s "$H" /home/deck

t "== 3. PluginLoader (latest stable version)"
INFO=$(curl -fsSL https://api.github.com/repos/SteamDeckHomebrew/decky-loader/releases | python3 -c '
import json, sys
for r in json.load(sys.stdin):
    if not r["prerelease"]:
        url = [a["browser_download_url"] for a in r["assets"] if a["browser_download_url"].endswith("PluginLoader")][0]
        print(r["tag_name"], url); break')
VER=${INFO% *}; URL=${INFO#* }
echo "   $VER"
if [ "$(cat "$HB/services/.loader.version" 2>/dev/null)" = "$VER" ] && [ -x "$HB/services/PluginLoader" ]; then
    t "   already installed"
else
    [ -e /var/service/decky ] && sv stop decky >/dev/null 2>&1 || true
    curl -fL --progress-bar "$URL" -o "$HB/services/PluginLoader.download"
    mv "$HB/services/PluginLoader.download" "$HB/services/PluginLoader"
    chmod 755 "$HB/services/PluginLoader"
    echo "$VER" > "$HB/services/.loader.version"
fi

t "== 4. runit service"
mkdir -p "$SV/log"
cat > "$SV/run" <<EOF
#!/bin/sh
# Decky Loader (installed by common/steam/install-decky.sh; docs/6-game-mode/5-decky.md). Equivalent to its
# systemd plugin_loader.service, plus the restart after updating itself (see install-decky.sh).
# Event-driven: a FIFO where inotifywait writes (each change in services/: the version, the binary
# renamed, its chmod) and PluginLoader when it ends ("EXITED"); the service waits blocked.
exec 2>&1
cd "$HB/services" || exit 1
v0=\$(cat .loader.version 2>/dev/null)
FIFO=/run/decky-events; rm -f "\$FIFO"; mkfifo -m 600 "\$FIFO"; exec 3<>"\$FIFO"
( env PLUGIN_PATH="$HB/plugins" UNPRIVILEGED_PATH="$HB" UNPRIVILEGED_USER="$U" \\
      LOG_LEVEL=INFO KEEP_SYSTEMD_SERVICE=1 "$HB/services/PluginLoader"
  echo EXITED >&3 ) &
decky=\$!
inotifywait -q -m -e close_write,moved_to,attrib --format '%e %f' "$HB/services" >&3 &
ino=\$!
finish() { pkill -P \$decky 2>/dev/null; kill \$ino 2>/dev/null; wait; exec 3<&-; rm -f "\$FIFO"; }
trap 'finish; exit 0' TERM INT
while read -r ev f <&3; do
    [ "\$ev" = EXITED ] && break                      # Decky closed by itself: runit restarts it
    v=\$(cat .loader.version 2>/dev/null)
    [ -n "\$v" ] && [ "\$v" != "\$v0" ] || continue    # it is not an update
    [ ! -e PluginLoader.new ] && [ -x PluginLoader ] || { echo "Decky: new version \$v; waiting for the binary"; continue; }
    echo "Decky: binary \$v ready; restarting"
    break
done
finish
EOF
cat > "$SV/log/run" <<'EOF'
#!/bin/sh
# Decky's output, for "journalctl -u plugin_loader" (systemd-compat). Without syslog, vlogger lost it.
exec svlogd -tt /var/log/decky
EOF
mkdir -p /var/log/decky
printf 's1000000\nn2\n' > /var/log/decky/config      # 1 MB per file, 2 files
chmod 755 "$SV/run" "$SV/log/run"
[ -e /var/service/decky ] && sv restart /var/service/decky/log >/dev/null 2>&1 || true   # the new log/run
rm -f /run/decky-avisos                     # the old FIFO name, if it is left over
if [ -e /var/service/decky ]; then sv restart decky >/dev/null; else ln -s "$SV" /var/service/; fi
sleep 6
sv status decky

t "== 5. check"
pgrep -a -f "$HB/services/PluginLoader" | head -1 || t "!! PluginLoader is not running"
t "   Close Steam and open it again (or enter Game Mode) so that it reads %s." "$CEF"
t "   In Game Mode: quick menu (Ctrl+Shift+Tab) → plug icon = Decky."
