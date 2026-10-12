#!/bin/bash
# migrate.sh — moves a machine installed with the original (Spanish-named) pieces of Common to this repository's
# (English names, translated messages), on the IdeaPad and on the Legion (2026-10-11). It does not reinstall
# anything new: it only runs the installer of each piece that IS installed; every installer removes the old
# Spanish-named files of its piece and keeps the chosen settings (Game Mode/desktop mode…).
#   bash install/migrate.sh             shows the plan, asks, and runs it (sudo once; it keeps it alive)
#   bash install/migrate.sh --dry-run   only the plan
# Run it as the user, from the graphical session (Xfce X11 or Wayland), with Steam closed or ready to be closed
# (like-steamos.sh closes it cleanly). At the end: reboot (renamed runit services and sessions).
#
# Personal folders: the XDG ones (Descargas, Documentos, Escritorio…) are NOT touched and are fixed in their
# current language: "enabled=False" in ~/.config/user-dirs.conf, so that xdg-user-dirs-update never creates the
# English ones (Downloads…) next to them, even if the session's language changes one day. If there already is a
# pair (e.g. Downloads and Descargas) it only says so: files are never moved.
set -uo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
DRY=; [ "${1:-}" = --dry-run ] && DRY=1
REPO=$REPO_ROOT; B=$REPO/build
H=$HOME

# ---- the plan: "kind|description|command" (kind: user or root) ----------------------------------------
PLAN=()
add() { PLAN+=("$1|$2|$3"); }
has() { [ -e "$1" ]; }
inblock() { grep -qs "$2" "$1"; }

# User pieces
if ls "$H"/.config/fish/functions/{install-pkg,remove-pkg,audio-ctrl,audio-priority,disk-ops,ssh-setup}.fish >/dev/null 2>&1; then
    add user "fish functions (translated messages)" \
        'cp "$B/common/fish/functions/"{__vl_t,fish_prompt,fish_greeting,disk-ops,install-pkg,remove-pkg,audio-ctrl,audio-priority}.fish ~/.config/fish/functions/ && cp "$B/common/ssh-setup/ssh-setup.fish" ~/.config/fish/functions/ && cp "$B/common/ssh-setup/ssh-survey.sh" ~/.config/fish/ && chmod +x ~/.config/fish/ssh-survey.sh'
fi
add user "update-system → void-update (panel icon, patch test, fastfetch)" \
    'bash "$B/common/void-update/install-void-update.sh"'
if has "$H/.local/bin/ventana-acoplar" || has "$H/.local/bin/window-snap"; then
    add user "window scripts: ventana-acoplar/foco, ventanas-nuevas → window-snap/focus, new-windows (and their Xfce shortcuts)" \
        'cp "$B/common/xfce/"{window-snap,window-focus,new-windows} ~/.local/bin/ && chmod +x ~/.local/bin/{window-snap,window-focus,new-windows} && cp "$B/common/xfce/new-windows.desktop" ~/.config/autostart/ && rm -f ~/.local/bin/{ventana-acoplar,ventana-foco,ventanas-nuevas} ~/.config/autostart/ventanas-nuevas.desktop && fix_shortcuts'
fi
if has "$H/.config/autostart/steam-segundo-plano.desktop"; then
    add user "Steam in the background: steam-segundo-plano.desktop → steam-background.desktop" \
        'cp "$B/legion/steam/steam-background.desktop" ~/.config/autostart/ && rm -f ~/.config/autostart/steam-segundo-plano.desktop'
fi
if has "$H/.local/bin/compartir-pantalla"; then
    add user "screen-share chooser: compartir-pantalla → screen-share" 'bash "$B/legion/screen-share/install.sh"'
fi

# Root pieces (sudo), in the recipe's order
if has /usr/local/bin/steam-modo-juego || has /usr/local/bin/steam-game-mode; then
    lsflag=--no-loading-screen; { has /usr/local/bin/steam-cargando || has /usr/local/bin/steam-loading; } && lsflag=
    add root "Game Mode: steam-modo-juego → steam-game-mode $lsflag" "sudo sh \"\$B/common/steam/install-game-mode.sh\" $lsflag"
fi
if has /usr/share/wayland-sessions/steam-modo-juego-directo.desktop || has /usr/share/wayland-sessions/steam-game-mode-direct.desktop; then
    add root "Game Mode direct session" 'sudo sh "$B/common/steam/test-direct-session.sh"'
fi
if has /usr/local/bin/cambiar-modo-root || has /usr/local/bin/switch-mode-root; then
    add root "mode switch: cambiar-modo-root → switch-mode-root (keeps the current mode)" 'sudo sh "$B/common/steam/install-passwordless-switch.sh"'
fi
if has /usr/share/applications/escritorio-wayland.desktop || has /usr/share/applications/desktop-wayland.desktop; then
    add root "Xfce on Wayland: brillo, fondo-vigilante → brightness, wallpaper-watcher; labwc configuration" 'sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"'
fi
if has /etc/sysctl.d/30-como-steamos.conf || has /etc/sysctl.d/30-like-steamos.conf; then
    add root "SteamOS settings: como-steamos → like-steamos (closes Steam cleanly if open)" 'sudo bash "$B/legion/like-steamos.sh"'
fi
if has /etc/sv/udev-red || has /etc/sv/udev-net; then
    add root "service udev-red → udev-net" 'sudo sh "$B/legion/udev-net.sh"'
fi
if inblock /etc/NetworkManager/conf.d/wifi-sin-ahorro.conf . || has /etc/NetworkManager/conf.d/wifi-no-powersave.conf; then
    add root "Wi-Fi without power saving: wifi-sin-ahorro.conf → wifi-no-powersave.conf" 'sudo sh "$B/legion/wifi-no-powersave.sh"'
fi
if has /etc/elogind/system-sleep/brillo || has /etc/elogind/system-sleep/brightness; then
    add root "brightness on wake: hook brillo → brightness" 'sudo sh "$B/legion/brightness-on-wake.sh"'
fi
if has /usr/local/share/inputplumber-void/manifiesto || has /usr/local/share/inputplumber-void/manifest; then
    add root "InputPlumber (list manifiesto → manifest)" 'sudo bash "$B/legion/install-inputplumber.sh"'
fi
if has /usr/local/share/steamos-manager-void/manifiesto || has /usr/local/share/steamos-manager-void/manifest; then
    add root "steamos-manager (manifiesto, paquete → manifest, package)" 'sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"'
fi
if has /etc/sv/decky; then
    add root "Decky Loader (its service, with the English names)" 'sudo sh "$B/common/steam/install-decky.sh"'
fi
if inblock /etc/fstab "microSD de la Legion"; then
    add root "microSD at boot (its fstab comment)" 'sudo sh "$B/legion/microsd-at-boot.sh"'
fi
if inblock /etc/rc.local "bluetooth al arrancar"; then
    add root "Bluetooth at boot (its rc.local block)" 'sudo sh "$B/common/bluetooth/bluetooth-at-boot.sh"'
fi
if inblock /etc/rc.conf "arranque silencioso"; then
    add root "silent boot (its rc.conf block)" 'sudo sh "$B/common/boot/silent-boot.sh"'
fi
if has /usr/local/share/grub-tema || has /usr/local/share/grub-theme; then
    add root "GRUB theme: grub-tema → grub-theme (regenerates the menu)" 'sudo bash "$B/common/grub-theme/install-theme.sh"'
fi

# Rewrites the Xfce X11 shortcuts that call the old window scripts (xfconf, live; needs the session's bus)
fix_shortcuts() {
    command -v xfconf-query >/dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || { t "   (shortcuts: no Xfce session here; run again from the session)"; return 0; }
    local p v
    xfconf-query -c xfce4-keyboard-shortcuts -lv 2>/dev/null | grep -E 'ventana-(acoplar|foco)' | while read -r p v; do
        v=${v//ventana-acoplar/window-snap}; v=${v//ventana-foco/window-focus}
        xfconf-query -c xfce4-keyboard-shortcuts -p "$p" -s "$v" && t "   shortcut %s → %s" "$p" "$v"
    done
}

# ---- personal folders ---------------------------------------------------------------------------------
xdg_dirs() {
    local conf=~/.config/user-dirs.conf pair a b
    if grep -qs '^enabled=False' "$conf"; then t "   already fixed (%s)" "$conf"
    elif [ -n "$DRY" ]; then t "   would write enabled=False in %s" "$conf"
    else mkdir -p ~/.config; { grep -vs '^enabled=' "$conf"; echo "enabled=False"; } > "$conf.new" && mv "$conf.new" "$conf" && t "   fixed: enabled=False in %s" "$conf"; fi
    for pair in Desktop:Escritorio Downloads:Descargas Documents:Documentos Music:Música Pictures:Imágenes Videos:Vídeos Templates:Plantillas Public:Público; do
        a=${pair%%:*}; b=${pair#*:}
        [ -d ~/"$a" ] && [ -d ~/"$b" ] && t "!! both ~/%s and ~/%s exist: move the files by hand and delete the one you do not want" "$a" "$b"
    done
    return 0
}

# ---- run ----------------------------------------------------------------------------------------------
t "== Migration of %s to this repository's pieces" "$(uname -n)"
t "== personal folders (Descargas, Documentos…): kept, in their current language"
xdg_dirs
echo
t "== plan (%s steps):" "${#PLAN[@]}"
i=0; for p in "${PLAN[@]}"; do i=$((i+1)); IFS='|' read -r kind desc _ <<< "$p"; printf '  %2d. [%-4s] %s\n' "$i" "$kind" "$desc"; done
[ -n "$DRY" ] && exit 0
echo
read -r -p "$(t "Go on? It asks for the sudo password once [Y/n] ")" ans
case "$ans" in [nN]*) t "Canceled."; exit 4 ;; esac

t "== preparing the clone (binaries of the Release, build/)"
bash "$REPO/install/fetch-assets.sh" >/dev/null || { t "!! install/fetch-assets.sh failed"; exit 1; }
bash "$REPO/install/render.sh" >/dev/null || exit 1
sudo -v || exit 1
mark=$(mktemp)
bash -c 'while [ -e "$1" ]; do sudo -n true 2>/dev/null || exit 0; sleep 60; done' _ "$mark" & disown
export B
failed=()
i=0
for p in "${PLAN[@]}"; do
    i=$((i+1)); IFS='|' read -r kind desc cmd <<< "$p"
    echo; t "==== %s/%s %s" "$i" "${#PLAN[@]}" "$desc"
    if eval "$cmd"; then t "   ok"; else t "!! failed: %s" "$desc"; failed+=("$desc"); fi
done
rm -f "$mark"
echo
if [ ${#failed[@]} -eq 0 ]; then t "== migration done: reboot now (sudo reboot) so that the renamed services and sessions start"
else t "!! %s step(s) failed (above); fix them and run this again (it only repeats what applies)" "${#failed[@]}"; fi
t "   Old Spanish-named pieces still on the system, if any: bash install/migrate.sh --dry-run"
