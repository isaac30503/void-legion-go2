#!/bin/bash
# install.sh — the Legion's reinstall list (docs/void-legion-go2.md, "Full list, in order", points A–M) as
# numbered stages. Run it as the user (not with sudo): it asks for sudo where the recipe does. The stages that
# are done by hand (Steam, desktop, log in…) are shown and it waits for Enter; at a reboot it stops and says
# how to go on. The recipe is the reference: each stage says which point/step it is, and its commands are the
# recipe's.
#   bash install/install.sh --list            the stages
#   bash install/install.sh                   from the next pending stage (remembered in ~/.local/state)
#   bash install/install.sh --from N          from stage N
#   bash install/install.sh --only N          only stage N
#   bash install/install.sh --dry-run [...]   shows the commands without running them
set -euo pipefail
R=$(dirname "$(readlink -f "$0")"); until [ -f "$R/lib/common.sh" ] || [ "$R" = / ]; do R=$(dirname "$R"); done
. "$R/lib/common.sh"
need_user
REPO="$REPO_ROOT"
B="$REPO/build"
STATE="$HOME/.local/state/void-legion-install.stage"
DRY=; FROM=; ONLY=; LIST=
while [ $# -gt 0 ]; do
    case "$1" in
        --list) LIST=1 ;; --dry-run) DRY=1 ;;
        --from) FROM=$2; shift ;; --only) ONLY=$2; shift ;;
        *) t "unknown option: %s" "$1" >&2; exit 2 ;;
    esac; shift
done

# Each stage (its title is a translatable message: no "%" in it): title | kind (run, manual, reboot) | commands (run in bash, with REPO
# and B set and the translation function t loaded: messages to the user go with t, not echo). A line of the commands that starts
# with "#" is an instruction for a person: it is shown through the catalog (no "%" in it either).
S_TITLE=(); S_KIND=(); S_CMD=()
stage() { S_TITLE+=("$1"); S_KIND+=("$2"); S_CMD+=("$3"); }

stage "A. Installation with void-installer (steps 0–1)" manual \
'# By hand, from the Void live ISO: sudo void-installer with the table of step 1 (and its two traps).
# Then the authorized_keys line of step 1, and: sudo rmdir /mnt/home /mnt/steamos-home (if they exist).'
stage "B. The repository: binaries, local.env (from local.env.age), build/" run \
'bash "$REPO/install/fetch-assets.sh"
[ -s "$REPO/local.env" ] || bash "$REPO/install/secrets.sh" open    # asks the passphrase (docs/sanitization.md)
bash "$REPO/install/render.sh" --check
bash "$REPO/install/render.sh"'
stage "C1. System, keyboard and SSH (steps 2–3)" reboot \
'sudo bash "$B/legion/steps-1-to-3.sh"'
stage "C2. avahi only over Wi-Fi, Wi-Fi without power saving, udev-net (steps 2–3)" run \
'sudo sh "$B/legion/avahi-wifi-only.sh"
sudo sh "$B/legion/wifi-no-powersave.sh"
sudo sh "$B/legion/udev-net.sh"'
stage "D. SSH in both directions (step 4)" run \
'[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C "isaac@Legion-Go-Gen-2" -f ~/.ssh/id_ed25519
mkdir -p ~/.ssh && cp "$B/legion/ssh-config" ~/.ssh/config && chmod 600 ~/.ssh/config
cat ~/.ssh/id_ed25519.pub
t "-> add that line to the IdeaPad'"'"'s ~/.ssh/authorized_keys; on the IdeaPad: ssh-keygen -R Legion-Go-Gen-2.local"'
stage "E1. X11 desktop, root part 1 (steps 5–12)" run \
'sudo bash "$B/legion/desktop-1-root.sh"'
stage "E2. X11 desktop, user part (steps 5–12)" run \
'V="$B/common"
mkdir -p ~/.bashrc.d && cp "$V/shell/99-exec-fish.sh" ~/.bashrc.d/
grep -q "bashrc.d" ~/.bashrc || { cp ~/.bashrc ~/.bashrc.bak && cat "$V/shell/bashrc-block.sh" >> ~/.bashrc; }
mkdir -p ~/.config/fish/functions ~/.local/bin
bash "$B/install/install-i18n.sh"
cp "$V/fish/functions/"{__vl_t,fish_prompt,fish_greeting,disk-ops}.fish ~/.config/fish/functions/
cp "$V/fish/functions/"{install-pkg,remove-pkg,audio-ctrl,audio-priority}.fish ~/.config/fish/functions/
cp "$V/ssh-setup/ssh-setup.fish" ~/.config/fish/functions/
cp "$V/ssh-setup/ssh-survey.sh" ~/.config/fish/ && chmod +x ~/.config/fish/ssh-survey.sh
fish -c "fish_add_path -U ~/.local/bin"
bash "$V/void-update/install-void-update.sh" --no-tray   # void-update + patch test (the icon, after step 13)
mkdir -p ~/.local/share/fonts ~/.themes ~/.local/share/icons
cp "$V/fonts/"*.ttf ~/.local/share/fonts/
cp -r "$V/xterm/jetbrains-blocks" ~/.local/share/fonts/ && chmod +x ~/.local/share/fonts/jetbrains-blocks/regenerate.sh
fc-cache -f ~/.local/share/fonts
tar xzf "$V/xfce/orchis-themes.tar.gz" -C ~/.themes/
tar xzf "$V/xfce/volantes-cursors.tar.gz" -C ~/.local/share/icons/
X="$V/xterm"; mkdir -p ~/.config/xfce4
cp "$X/Xresources" ~/.Xresources && cp "$X/xterm-papirus.xpm" ~/.local/share/icons/
cp "$X/helpers.rc" ~/.config/xfce4/helpers.rc && cp "$X/xprofile" ~/.xprofile
cp "$X/xdg-terminal-exec" ~/.local/bin/ && chmod +x ~/.local/bin/xdg-terminal-exec
mkdir -p ~/.config/fastfetch && cp "$V/fastfetch/gen-config.py" ~/.config/fastfetch/ && python3 ~/.config/fastfetch/gen-config.py'
stage "E3. X11 desktop, root part 2: login screen (step 10)" run \
'sudo bash "$B/legion/desktop-2-root.sh"'
stage "F. Xfce configuration (step 13) — WITH THE SESSION CLOSED: run this stage from a text console (Ctrl+Alt+F2)" run \
'pkill -u "$(id -un)" -x xfconfd || true
L="$B/legion"; X="$B/common/xfce"
mkdir -p ~/.config/xfce4/xfconf ~/.config/gtk-3.0 ~/.local/bin ~/.config/autostart
cp -r "$L/xfce/xfce-perchannel-xml" ~/.config/xfce4/xfconf/
cp -r "$L/xfce/panel" ~/.config/xfce4/
cp "$L/xfce/gtk.css" ~/.config/gtk-3.0/gtk.css
cp "$X/"{window-snap,window-focus,new-windows} ~/.local/bin/ && chmod +x ~/.local/bin/{window-snap,window-focus,new-windows}
cp "$X/new-windows.desktop" ~/.config/autostart/
rm -f ~/.local/bin/{ventana-acoplar,ventana-foco,ventanas-nuevas} ~/.config/autostart/ventanas-nuevas.desktop   # the old Spanish names, if they are there (otherwise two watchers run)'
stage "G. Claude Code (step 7)" run \
'command -v claude >/dev/null || [ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash
mkdir -p ~/Work ~/.claude/projects/-home-isaac-Work/memory ~/Work/.claude/agents
cp "$B/claude/CLAUDE-void-legion.md" ~/Work/CLAUDE.md
cp "$B/claude/memory/"*.md ~/.claude/projects/-home-isaac-Work/memory/
cp "$B/claude/agents/void-maintainer.md" ~/Work/.claude/agents/
t "-> log in: cd ~/Work && claude   (on the Legion itself)"'
stage "H. GRUB without Plymouth (step 8): XS1000 connected" reboot \
'sudo bash "$B/legion/grub-root.sh"
sudo sh "$B/legion/grub-hidden.sh"
t "-> unmount Common if it is mounted (udisksctl unmount -b /dev/sda4) before the reboot"'
stage "I1. Steam (step 14)" run \
'sudo sh "$B/common/steam/install-steam.sh"
mkdir -p ~/.local/share/applications ~/.local/lib/extest
cp "$B/legion/steam/steam-extest.desktop" ~/.local/share/applications/steam.desktop
install -m 755 "$B/legion/steam/extest/libextest.so" ~/.local/lib/extest/'
stage "I2. By hand: log out and back in; open Steam FROM THE MENU, let it update, log in, close it" manual \
'# (list, point I)'
stage "I3. Game Mode and Xfce Wayland (steps 14–15)" reboot \
'sudo sh "$B/common/steam/install-game-mode.sh" --no-loading-screen
sudo sh "$B/common/steam/test-direct-session.sh"
sudo sh "$B/common/steam/install-passwordless-switch.sh"
sudo sh "$B/common/xfce-wayland/install-xfce-wayland.sh"'
stage "J. The Legion's own things (step 14)" reboot \
'sudo bash "$B/legion/install-inputplumber.sh"
sudo bash "$B/legion/tdp/install-tdp.sh"
sudo sh "$B/common/steam/steamos-manager/install-steamos-manager.sh"
sudo xbps-pkgdb -m manual speech-dispatcher
sudo sh "$B/legion/gpu-overdrive.sh"
sudo sh "$B/legion/brightness-on-wake.sh"
sudo bash "$B/legion/like-steamos.sh"
sudo xbps-pkgdb -m hold linux linux-headers'
stage "J2. microSD (step 14) — with Steam CLOSED" run \
'sudo sh "$B/legion/microsd-at-boot.sh"
t "-> in Steam, add /mnt/microsd as a library"'
stage "K. By hand in Steam and on the desktop (list, point K: developer mode and Wi-Fi power management, keyboard, xterm and Firefox as games, Decky, art, controller layout, Bluetooth, VRR, Vesktop and portals, audio order)" manual \
'# Follow point K of the list in docs/void-legion-go2.md, item by item (1–12). The scripted parts of it:
#   install -m 755 "$B/common/steam/xterm-steam" "$B/common/steam/firefox-steam" ~/.local/bin/
#   sudo sh "$B/common/steam/install-decky.sh"
#   python3 "$B/common/steam/art-xterm/generate.py"            (Steam closed)
#   cp "$B/legion/steam/steam-background.desktop" ~/.config/autostart/; rm -f ~/.config/autostart/steam-segundo-plano.desktop
#   bash "$B/legion/portal-wlr-patch/build-portal-wlr.sh"; bash "$B/legion/screen-share/install.sh"
#   sudo sh "$B/common/steam/portal-gamescope/install-portal-gamescope.sh"; bash "$B/common/steam/gamescope-patch/build-gamescope.sh"
#   cp "$B/legion/wireplumber/51-audio-priority.conf" ~/.config/wireplumber/wireplumber.conf.d/'
stage "L. Check (Verification block of the recipe and void-update)" manual \
'# void-update   → must end in "All in order" ("Todo en orden" in Spanish); then: void-update --tray --enable (panel icon)'
stage "M. Clean up: archive the logs of ~ in logs/legion/ (check them for private values) and delete them" run \
'mkdir -p "$REPO/logs/legion" && cp ~/*.log "$REPO/logs/legion/" 2>/dev/null || true
t "-> review %s (bash %s --secrets), commit; then: rm -f ~/*.log" "$REPO/logs/legion/" "$REPO/install/verify.sh"'

N=${#S_TITLE[@]}
if [ -n "$LIST" ]; then
    for i in $(seq 0 $((N-1))); do printf '%2d  [%-6s] %s\n' $((i+1)) "${S_KIND[$i]}" "$(t "${S_TITLE[$i]}")"; done
    exit 0
fi
start=1
[ -r "$STATE" ] && start=$(( $(cat "$STATE") + 1 ))
[ -n "$FROM" ] && start=$FROM
end=$N
[ -n "$ONLY" ] && { start=$ONLY; end=$ONLY; }
export REPO B
for i in $(seq "$start" "$end"); do
    k=$((i-1))
    echo; t "==== %s/%s %s" "$i" "$N" "$(t "${S_TITLE[$k]}")"
    while IFS= read -r line; do
        case "$line" in
            "# "*) printf '   | # %s\n' "$(t "${line#\# }")" ;;
            *)     printf '   | %s\n' "$line" ;;
        esac
    done <<< "${S_CMD[$k]}"
    [ -n "$DRY" ] && continue
    case "${S_KIND[$k]}" in
        manual)
            read -r -p "$(t "Done? Enter to go on, Ctrl+C to stop: ")" _ ;;
        run|reboot)
            read -r -p "$(t "Run it? [Y/n] ")" ans
            case "$ans" in [nN]*) t "stopped; to go on: bash install/install.sh --from %s" "$i"; exit 0 ;; esac
            I18N_REPO_DIR=$REPO bash -euo pipefail -c '. "$REPO/lib/i18n.sh"; eval "$1"' _ "${S_CMD[$k]}" || { t "!! stage %s failed; fix it and: bash install/install.sh --from %s" "$i" "$i"; exit 1; } ;;
    esac
    mkdir -p "$(dirname "$STATE")"; echo "$i" > "$STATE"
    if [ "${S_KIND[$k]}" = reboot ]; then
        t "-> reboot now (sudo reboot); afterwards: bash install/install.sh   (it goes on at stage %s)" "$((i+1))"
        exit 0
    fi
done
[ -z "$DRY" ] && t "all stages done"
exit 0
