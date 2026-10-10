#!/usr/bin/env bash
# X-ray of a machine of the network after setting it up over SSH.
# It runs via: ssh <alias> bash -s < this-file   (ssh-setup does it, installed in ~/.config/fish/ssh-survey.sh)
# It is in bash on purpose: on some machines the remote shell is fish and it would not
# understand this syntax. It works for Arch/CachyOS, SteamOS, Fedora (including
# Atomic/Silverblue) and Void (xbps + runit), so each query goes behind a
# command -v.
# Its texts follow the language of whoever reads it: ssh-setup sends before it, through the same stdin, the
# local catalog and lib/i18n.sh (the other machine may not have them); run alone, English.
# Previous name: herramientas/ssh-survey.sh (unchanged).

declare -F t >/dev/null 2>&1 || t() { _f=$1; shift; printf -- "$_f\n" "$@"; }
title() { printf '\n\033[1m%s\033[0m\n' "$1"; }
# %-22s aligns by bytes and accents misalign the column; ${#var}
# counts real characters, so the padding is calculated by hand.
item() {
  local label="$1" gap
  gap=$(( 24 - ${#label} ))
  [ "$gap" -lt 1 ] && gap=1
  printf '  %s%*s%s\n' "$label" "$gap" '' "$2"
}

# Void uses runit, not systemd: systemctl does not exist and the active services are the
# links in /var/service. sv status requires root, so it is not used here.
runit=""
if [ -d /var/service ] && command -v sv >/dev/null 2>&1 && ! command -v systemctl >/dev/null 2>&1; then
  runit=1
fi

NONE=$(t "none")
title "$(t "System")"
. /etc/os-release 2>/dev/null
item "$(t "distribution")" "${PRETTY_NAME:-$(t "not known")}"
item "kernel"       "$(uname -r)"
if command -v pacman >/dev/null 2>&1; then
  item "$(t "packages")" "$(pacman -Q 2>/dev/null | wc -l)"
elif command -v rpm >/dev/null 2>&1; then
  item "$(t "packages")" "$(rpm -qa 2>/dev/null | wc -l)"
elif command -v xbps-query >/dev/null 2>&1; then
  item "$(t "packages")" "$(xbps-query -l 2>/dev/null | wc -l)"
fi
item "shell"        "$(getent passwd "$USER" | cut -d: -f7)"
item "hostname"     "$(uname -n)"   # SteamOS does not bring the hostname binary

title "$(t "Edition")"
# The Handheld edition brings gamescope-session and the -deckify kernel; the
# desktop ones bring their own environment. Knowing it predicts whether there will be a firewall.
pattern='plasma-desktop|plasma-workspace|hyprland|cosmic-session|gnome-shell|omarchy|gamescope-session-cachyos|gnome-shell-.*|kde-desktop|xfce4-session|niri|sway'
if command -v pacman >/dev/null 2>&1; then
  envs=$(pacman -Qq 2>/dev/null | grep -xE "$pattern" | tr '\n' ' ')
elif command -v rpm >/dev/null 2>&1; then
  envs=$(rpm -qa --qf '%{NAME}\n' 2>/dev/null | grep -xE "$pattern" | tr '\n' ' ')
elif command -v xbps-query >/dev/null 2>&1; then
  # xbps-query -l gives "ii pkgver description"; the name is the pkgver without the version
  envs=$(xbps-query -l 2>/dev/null | awk '{print $2}' | sed 's/-[^-]*$//' | grep -xE "$pattern" | tr '\n' ' ')
fi
item "$(t "graphical environment")" "${envs:-$NONE}"
if [ -d /ostree ] || command -v rpm-ostree >/dev/null 2>&1; then
  # Fedora Atomic (Silverblue/Kinoite/Bazzite): / is immutable and packages
  # are layered with rpm-ostree, not with dnf. The ones the user adds show up as
  # "LayeredPackages" and are reapplied on each update.
  item "$(t "looks like")" "$(t "%s — atomic (ostree)" "${PRETTY_NAME:-Fedora}")"
  if command -v rpm-ostree >/dev/null 2>&1; then
    item "$(t "deployment")" "$(rpm-ostree status -b --json 2>/dev/null | grep -o '"version" : "[^"]*"' | head -1 | cut -d'"' -f4)"
    layers=$(rpm-ostree status 2>/dev/null | sed -n 's/^ *LayeredPackages: *//p' | head -1)
    item "$(t "layered packages")" "${layers:-$NONE}"
  fi
else
  case "${ID:-}${VARIANT_ID:-}" in
    *steamos*) item "$(t "looks like")" "SteamOS" ;;
    void*)
      # Rolling, without versions: what distinguishes an installation is the libc
      case "$(ldd --version 2>&1 | head -1)" in
        *musl*) libc=musl ;;
        *)      libc=glibc ;;
      esac
      item "$(t "looks like")" "Void Linux — rolling, runit, $libc" ;;
    *) case "$(uname -r)" in
         *deckify*) item "$(t "looks like")" "CachyOS Handheld (kernel -deckify)" ;;
         *)         item "$(t "looks like")" "${PRETTY_NAME:-$(t "generic")}" ;;
       esac ;;
  esac
fi
# On SteamOS the root is read-only and pacman does not work until it is released
# with steamos-readonly disable; besides, an OS update rewrites /
# and wipes out what was installed outside /home.
if command -v steamos-readonly >/dev/null 2>&1; then
  # DO NOT look at the mount options: / shows as rw even if it is protected.
  # The real protection is a btrfs property (ro=true) and the one that knows how to
  # read it is steamos-readonly status. Verified on 2026-09-11.
  case "$(steamos-readonly status 2>&1)" in
    *enabled*)  item "$(t "root")" "$(t "READ-ONLY (%s for pacman)" "sudo steamos-readonly disable")" ;;
    *disabled*) item "$(t "root")" "$(t "WRITING ENABLED (it is reverted when the OS updates)")" ;;
    *)          item "$(t "root")" "$(t "undetermined state: %s" "$(btrfs property get / ro 2>&1)")" ;;
  esac
fi

title "$(t "Access")"
if [ -n "$runit" ]; then
  # Enabled = linked in /var/service. Active: pgrep, because sv status asks for root.
  if [ -e /var/service/sshd ]; then
    item "$(t "sshd enabled")" "$(t "yes (link in /var/service)")"
  else
    item "$(t "sshd enabled")" "$(t "NO — %s" "sudo ln -s /etc/sv/sshd /var/service/")"
  fi
  if pgrep -x sshd >/dev/null 2>&1; then
    item "$(t "sshd active")" "$(t "running")"
  else
    item "$(t "sshd active")" "$(t "stopped")"
  fi
  # Void brings no firewall; if one is installed, its service shows up in /etc/sv
  for f in ufw firewalld nftables iptables; do
    if [ -e "/var/service/$f" ]; then
      item "$f" "$(t "ACTIVE (runit)")"
    elif [ -d "/etc/sv/$f" ]; then
      item "$f" "$(t "installed — not enabled")"
    else
      item "$f" "$(t "not installed")"
    fi
  done
else
item "$(t "sshd enabled")" "$(systemctl is-enabled sshd 2>/dev/null)"
item "$(t "sshd active")"  "$(systemctl is-active sshd 2>/dev/null)"
for f in ufw firewalld; do
  # systemctl knows whether the unit exists without asking the package manager,
  # which changes from one distro to another.
  if systemctl list-unit-files "$f.service" 2>/dev/null | grep -q "^$f"; then
    state="$(systemctl is-active "$f" 2>/dev/null)"
    if [ "$state" = active ] && [ "$f" = firewalld ] && command -v firewall-cmd >/dev/null 2>&1; then
      zone="$(firewall-cmd --get-default-zone 2>/dev/null)"
      # --list-services requires polkit or root and returns "Authorization failed"
      # which, redirected, looks like an empty list: it would lie saying that it
      # allows nothing. The zone's XML is read without permissions. What is in /etc overrides
      # what is in /usr when the user has touched the zone.
      for xml in "/etc/firewalld/zones/$zone.xml" "/usr/lib/firewalld/zones/$zone.xml"; do
        [ -r "$xml" ] || continue
        svc=$(grep -o '<service name="[^"]*"' "$xml" | cut -d'"' -f2 | tr '\n' ' ')
        break
      done
      item "$f" "$(t "ACTIVE — zone %s, allows: %s" "$zone" "${svc:-$(t "I could not read it")}")"
    else
      item "$f" "$(t "installed — active: %s" "$state")"
    fi
  else
    item "$f" "$(t "not installed")"
  fi
done
for f in nftables iptables; do
  item "$f" "$(systemctl is-active "$f" 2>/dev/null)"
done
fi

title "$(t "Network")"
ip -4 -o addr show scope global | while read -r _ ifz _ addr _; do item "$ifz" "$addr"; done
item "$(t "gateway")" "$(ip route | grep -m1 '^default' | cut -d' ' -f3)"

title "$(t "Health")"
# ~/homebrew is Decky Loader and is root's ON PURPOSE: a chown there breaks it.
# It only alarms about what is OUTSIDE that folder, which usually does mean
# an installer run with sudo (it happened to Omarchy on the Legion).
rootf=$(find "$HOME" -xdev -user root 2>/dev/null | grep -cv "^$HOME/homebrew/")
decky=$(find "$HOME/homebrew" -xdev -user root 2>/dev/null | wc -l)
if [ "$rootf" -gt 0 ]; then
  item "$(t "root's files in HOME")" "$(t "%s  <-- careful: installer run as root" "$rootf")"
else
  item "$(t "root's files in HOME")" "$(t "0 outside what is expected")"
fi
[ "$decky" -gt 0 ] && item "  $(t "of them, Decky")" "$(t "%s in ~/homebrew (normal, do not touch)" "$decky")"
if command -v checkupdates >/dev/null 2>&1; then
  item "$(t "updates")" "$(checkupdates 2>/dev/null | wc -l)"
elif command -v rpm-ostree >/dev/null 2>&1; then
  # Without --check because it goes out to the network and takes long; the local state already says whether there is
  # a new deployment waiting for the reboot.
  if rpm-ostree status 2>/dev/null | grep -q '^ *Staged'; then
    item "$(t "updates")" "$(t "there is a staged deployment — a reboot is missing")"
  else
    item "$(t "updates")" "$(t "no pending deployment (%s to check)" "rpm-ostree upgrade")"
  fi
elif command -v xbps-install >/dev/null 2>&1; then
  # Against the repodata of the last sync: syncing asks for root and goes out to the network
  item "$(t "updates")" "$(t "%s according to the last sync (%s to refresh)" "$(xbps-install -un 2>/dev/null | wc -l)" "sudo xbps-install -S")"
elif command -v steamos-update >/dev/null 2>&1; then
  # It is not run: "steamos-update check" goes out to the network and would take too long in
  # an x-ray that must be instant.
  item "$(t "updates")" "$(t "SteamOS — check with: %s" "steamos-update check")"
else
  item "$(t "updates")" "$(t "I do not know how to check it on this distro")"
fi

title "Claude Code"
if [ -e "$HOME/.local/bin/claude" ]; then
  item "$(t "binary")" "$(readlink -f "$HOME/.local/bin/claude" 2>/dev/null || echo "$HOME/.local/bin/claude")"
  item "$(t "version")"  "$("$HOME/.local/bin/claude" --version 2>&1 | head -1)"
  if [ -f "$HOME/.claude/.credentials.json" ]; then
    item "$(t "session")" "$(t "logged in")"
  else
    item "$(t "session")" "$(t "NOT LOGGED IN — run claude and log in")"
  fi
else
  item "$(t "binary")" "$(t "not installed")"
fi
echo
