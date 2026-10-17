# void-update and the everyday tools

## void-update

Updates Void and handles what comes before and after, modeled on CachyOS's **cachy-update**: a **panel icon**,
**checks without root** when the network connects and every 6 h, notifications, Void's news, services still running
old code, and a short **summary** at the end. Code in `common/void-update/`.

**Install** (without root; done by the [desktop's user part](../5-desktop/1-xfce.md)); after the panel exists, the icon:

```bash
bash "$B/common/void-update/install-void-update.sh" --no-tray   # also installs the patch test and the translations
void-update --tray --enable      # starts the icon now and at every login (~/.config/autostart/void-update-tray.desktop)
```

| Command | Does |
|---|---|
| `void-update` | full update: syncs; shows **Void's news** since the last update (`https://voidlinux.org/atom.xml`); the list (the changed part of each version colored) and the download size; warns if it would replace a package **built here** (testing its patch first); **one** confirmation; **xbps first**, then everything; restarts `sshd` if OpenSSH changed (the old one in memory cuts new connections); Flatpak; orphans **except kernels** (the fallback series is kept); cache; loose kernels (`vkpurge`); warns about `.new-*`; LazyVim; offers to restart **runit services still running replaced code** (a deleted library or executable in `/proc/<pid>/maps`, followed up to its `runsv`; never `lightdm`, `dbus` or the consoles); the **summary**; and **asks** whether to reboot if a new kernel or glibc came in (it never reboots by itself). A lock prevents two at once |
| `void-update -c`, `--check` | looks for updates **without root** (`xbps-install -Mun`: the index in memory, ~5–10 s; `flatpak remote-ls --updates`), updates the icon and notifies if the list changed |
| `void-update -l`, `--list` | the pending list (exit 7 if none) |
| `void-update -n [N]`, `--news [N]` | Void's latest N news (5 by default) |
| `void-update -s`, `--services` | services running old code (asks to restart them) |
| `void-update --summary [-v]` | only the summary, without syncing, `sudo` or changes (`-v`: the detail of every line) |
| `void-update --systemd [--ack]` | [systemd-compat](../2-base-system/4-systemd-compat.md): its installation, the programs that call systemd (what changed in their code since the last review) and the requests not served; `--ack` marks it reviewed |
| `void-update --tray [--enable\|--disable]` | the icon (Ayatana AppIndicator) |
| `void-update --gen-config` · `--show-config` · `--edit-config` | `~/.config/void-update/void-update.conf` (interval, notifications, Flatpak, news, icon style; see `void-update.conf.example`) |

Exit codes: 0 fine · 1 invalid option · 2 check failed · 3 icon error · 4 not confirmed · 5 update error · 7 nothing
pending · 8 configuration error. State in `~/.local/state/void-update/` (the date of the last full update is
fastfetch's "Actualizado").

**The icon:** Void's symbol in one color (white for the black panel; `tray_icon_style=dark` for black) with a badge:
✓ up to date, ↓ updates available, ··· checking, ! the check failed. Its menu: the list (packages, Flatpak, all),
last and next check, **Run void-update** (opens it in xterm, which waits for Enter at the end; also the middle click),
**Check for updates**, **Exit**. Checks happen when NetworkManager reports the network connected (D-Bus
`StateChanged`) if the last one is older than the interval, and every `check_interval_hours` (6; 0 = only on
connect). It follows void-update's state file event-driven. Not in Game Mode (no session autostart there).

**The summary** fits half a terminal: one line per check, `✓` OK, `↻` repaired, `⚠` warning, `ℹ` note; the detail is
printed under warnings, repairs and notes (or for all with `-v`). It repairs only what the piece's own installer
would (the TDP module for a new 6.18 kernel; gamescope's `cap_sys_nice`), and checks: TDP modules and the kernel hold,
the kernel series Void recommends, gamescope's capability, **each package built here against Void's** (testing its
patch: [own patches](2-own-patches.md)), InputPlumber's and the gamescope portal's libraries, steamos-manager (libraries,
reference sha256, which package, build dependencies, upstream's latest tag), `extest` (libraries and its build tools),
`.new-*`, [systemd-compat](../2-base-system/4-systemd-compat.md) (a program that changed how it calls systemd, or a request
not served) and whether to reboot. Without network it cannot know about upstream versions of what is not from xbps.

## Package tools

Adapted from Omarchy's scripts (pacman) to xbps, with `fzf`:

- **`install-pkg`:** the ~14,800 packages of the repository with their description, **✓** on the installed ones;
  searches name and description; installs with `sudo xbps-install -S` (**without `-y`**: xbps shows dependencies and
  size and asks). Keys: `tab`, `alt-p`, `alt-j/k`, `alt-d/u`, `alt-i` (information), **`alt-f`** (files).
- **`remove-pkg`:** what was installed by hand (`xbps-query -m`), removed with `sudo xbps-remove -R`; **refuses** 🔒
  `base-system`, `linux*`, `grub*`, `xbps`, `lightdm*`, `xfce4` and `xorg-minimal`; `alt-x` shows what depends on a
  package.
- **`disk-ops`:** disks with `lsblk` + `fzf`: mount/unmount with `udisksctl` (needs the graphical session) and repair
  NTFS with `ntfsfix` (`ntfs-3g`).
- **`ssh-setup [alias]`:** sets up or redoes SSH access to another machine (finds it, diagnoses the port, fixes
  `known_hosts`, installs the key, writes `~/.ssh/config`, installs Claude Code there and shows an x-ray of the system);
  `--diagnosis` only looks. Manual: [ssh-setup](../ssh-setup.md).
- **`audio-ctrl`**, **`audio-priority`:** [audio](../3-hardware-support/3-audio-bluetooth.md).

The previews of `fzf` run in bash (`--with-shell 'bash -c'`), so they work with any login shell.

## Problems

- **`xbps-install` installs nothing and asks to update xbps:** an old xbps; `sudo xbps-install -Syu xbps` first
  (`void-update` does it by itself).
- **SSH says "Connection reset by peer" right after an update:** a new OpenSSH with the old `sshd` in memory:
  `sudo sv restart sshd` (`void-update` does it by itself).
- **`sv status` says "access denied":** it needs root (`sudo sv status <service>`).
- **The summary ends with a warning:** each line says what to do; see the piece's page.
