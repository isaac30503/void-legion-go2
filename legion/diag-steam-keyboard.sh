#!/bin/bash
# diag-steam-keyboard.sh — Legion, desktop (Xfce Wayland or X11), as the user, without root.
# Captures (read-only) why the controller stops moving the pointer after closing Steam's on-screen
# keyboard (2026-10-09): Steam stays with "Set OSK active 1" without its "0" and the controller
# stays in the keyboard's action set (basicui_neptune.vdf).
# Previous (Spanish) name: diag-teclado-steam.sh.
#
# Usage:  cp "<repo>/legion/diag-steam-keyboard.sh" /tmp/ && bash /tmp/diag-steam-keyboard.sh
#         bash /tmp/diag-steam-keyboard.sh --stop       
#         Results in /tmp/diag-steam-keyboard/ (deleted on reboot).
# Everything is event-driven (tail -F, xprop -spy): it spends nothing while nothing happens. When the
# session closes (e.g. Game Mode) the X part is cut; it has to be launched again.
# (It works copied to /tmp on its own: without the repository its messages are in English.)

S=/tmp/diag-steam-keyboard
L=$HOME/.local/share/Steam/logs
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
if [ -f "$R/lib/common.sh" ]; then . "$R/lib/common.sh"; else t() { _f=$1; shift; printf -- "$_f\n" "$@"; }; fi

stop() {
  pkill -f 'diag-steam-keyboard.sh --loop'
  pkill -f "tail -n0 -F $L/controller"
  pkill -f 'xprop -root -spy _NET_ACTIVE_WINDOW'
}

case "$1" in
  --stop) stop; t "Stopped. Results in %s/" "$S"; exit 0 ;;
  --loop) ;;
  *) stop; nohup setsid bash "$0" --loop >/dev/null 2>&1 &
     t "Capturing in %s/ (stop: bash %s --stop)" "$S" "$0"; exit 0 ;;
esac

export DISPLAY=${DISPLAY:-:0}
mkdir -p "$S"
tail -n0 -F "$L/controller.txt"    >> "$S/controller.txt"    2>/dev/null &
tail -n0 -F "$L/controller_ui.txt" >> "$S/controller_ui.txt" 2>/dev/null &
# X window with the focus (Wayland ones show as 0x0).
xprop -root -spy _NET_ACTIVE_WINDOW 2>&1 | while read -r l; do
  w=${l##* }
  c=$(xprop -id "$w" WM_CLASS _NET_WM_NAME _NET_WM_WINDOW_TYPE 2>/dev/null | tr '\n' ' ')
  echo "$(date +%T.%N | cut -c1-12) $w $c"
done >> "$S/focus.txt" &
wait
