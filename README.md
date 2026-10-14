# void-legion-go2

**Void Linux + Xfce on the Lenovo Legion Go 2**, set up like SteamOS: the complete reinstall recipe, every
script and configuration it uses, and the tools to apply it — so that a reinstall gives **the same
system**, step by step, without inferring anything.

What the machine ends up with: Void (glibc, runit) with Xfce on Wayland (labwc) and Xfce X11 as a backup;
**Game Mode like SteamOS** (gamescope on the screen, Steam's SteamOS interface, autologin into the last
mode, switching without password, clean Steam shutdown); InputPlumber (Valve controller, gyroscope),
fine **TDP** through DKMS, **steamos-manager** (patched), Decky, screen sharing in both modes (patched
wlroots portal, own chooser, SteamOS's gamescope portal, patched gamescope), hidden GRUB with a themed
menu, and **`void-update`** (like CachyOS's cachy-update: panel icon, rootless checks, notifications, Void's
news, services to restart) that also **tests whether each own patch is still needed**.

> Private repository. Private values (MACs, UUIDs, Wi-Fi name, serial numbers, Steam account id) are
> written as `@NAME@`; the real ones live in `local.env`, which is in git only **encrypted** (`local.env.age`, age with a passphrase;
> [docs/sanitization.md](docs/sanitization.md)).

## Start here

| | |
|---|---|
| **The recipe** | [docs/void-legion-go2.md](docs/void-legion-go2.md) — starts with the full list in order (points A–M), then every step with its why and its check, *Troubleshooting*, *Verification*, *Pending*, *History* |
| The base recipe (IdeaPad), steps 1–15 | [docs/reference/void-ideapad-100-steps.md](docs/reference/void-ideapad-100-steps.md) — "same as the IdeaPad, step N" points here |
| Installing | [install/README.md](install/README.md) — `fetch-assets.sh`, `render.sh`, `install.sh` (the list as resumable stages) |
| Names | [docs/glossary.md](docs/glossary.md) — the original was in Spanish; old name → new name of every script, command, service and file |
| Language of the messages | [docs/i18n.md](docs/i18n.md) — the scripts speak the system's language (Spanish catalog included) |
| Claude Code | [claude/](claude/) — the machine's context (`~/Work/CLAUDE.md`), the `void-maintainer` agent and its memory |
| Maintaining | [docs/maintenance.md](docs/maintenance.md) |

## Layout

```
docs/       the recipe, the IdeaPad reference, glossary, i18n, sanitization, ssh-setup, history/
legion/     pieces only for the Legion (scripts of steps 2–15, Xfce config, TDP DKMS, portal patches, screen-share…)
common/     pieces shared with the IdeaPad (Game Mode, Xfce Wayland, GRUB theme, boot, fish functions, xterm…)
claude/     Claude Code context, agent and memory
install/    fetch-assets, render, install (stages), verify, i18n, aliases; assets.tsv
lib/        common.sh (helpers), i18n.sh and void_legion_i18n.py (translations)
locale/     message catalogs (es)
logs/       real logs of the installation, archived as they were (sanitized)
```

Binaries (built `.xbps` packages, InputPlumber, steamos-manager, `libextest.so`, fonts, Orchis and Volantes)
are assets of the GitHub Release, not git: `install/fetch-assets.sh` puts them where the scripts expect them.

## Quick start (on a freshly installed Void, as the user)

```bash
sudo xbps-install -S git github-cli && gh auth login
gh repo clone <owner>/void-legion-go2 ~/src/void-legion-go2 && cd ~/src/void-legion-go2
bash install/install.sh --list     # the 19 stages
bash install/install.sh            # runs them in order, stopping at reboots and manual steps
```

## Origin

Translated and organized from the Spanish documentation kept on an external disk (`Backups Linux/`),
with the same content: every command, path, version, check and dated note. Only the Legion's part is here
(plus the IdeaPad steps it builds on).
