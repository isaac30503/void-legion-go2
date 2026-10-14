#!/bin/sh
# Legion Go 2: when coming back from hibernation, the built-in screen was left with another brightness (at
# 100 % before, ~32 % = 151040/472000 after; 2026-10-04). elogind hook that saves the brightness of each
# screen right before sleeping and sets it again on wake (hibernate and suspend).
# elogind runs whatever is in /etc/elogind/system-sleep/ with "pre|post" and "suspend|hibernate|…".
# /run works to keep it: it goes into the hibernation image (it is memory) and is lost on power-off.
# Previous (Spanish) name: brillo-al-despertar.sh (hook /etc/elogind/system-sleep/brillo; --remove also
# removes that old hook).
# Usage: sudo sh legion/brightness-on-wake.sh [--remove]     
set -e
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_root
G=/etc/elogind/system-sleep/brightness
OLD=/etc/elogind/system-sleep/brillo
if is_remove "${1:-}"; then rm -f "$G" "$OLD"; t "removed"; exit 0; fi
mkdir -p "${G%/*}"
cat > "$G.tmp" <<'G_EOF'
#!/bin/sh
# Installed by legion/brightness-on-wake.sh (Legion recipe, step 14). elogind: $1 = pre|post, $2 = type.
F=/run/brightness-before-sleep
case "$1" in
    pre)  for b in /sys/class/backlight/*; do
              [ -r "$b/brightness" ] && echo "${b##*/} $(cat "$b/brightness")"
          done > "$F" ;;
    post) [ -r "$F" ] || exit 0
          while read -r n v; do
              [ -w "/sys/class/backlight/$n/brightness" ] && echo "$v" > "/sys/class/backlight/$n/brightness"
          done < "$F"
          echo "$(date '+%F %T') $2: brightness restored ($(tr '\n' ' ' < "$F"))" >> /run/brightness-on-wake.log ;;
esac
exit 0
G_EOF
chmod 755 "$G.tmp"; mv "$G.tmp" "$G"; rm -f "$OLD"; ls -l "$G"
t "Check after hibernating or suspending: cat /run/brightness-on-wake.log"
