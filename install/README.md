# install/

Tools to put the Legion back exactly as it was, following [`../docs/void-legion-go2.md`](../docs/void-legion-go2.md).
Run them **as the user, from the clone** (not from `build/`, and not with `sudo`: they ask for it where needed).

| Script | What |
|---|---|
| `fetch-assets.sh [--check]` | downloads the binaries of the GitHub Release (packages built here, official binaries, fonts, themes) to the paths where the scripts look for them, checking each sha256 (`assets.tsv`). Needs `gh auth login` (the repository is private) or `GH_TOKEN` |
| `render.sh [--check]` | makes `build/`: the clone with every `@NAME@` filled in from `local.env` ([`../docs/sanitization.md`](../docs/sanitization.md)) |
| `install.sh [--list \| --from N \| --only N \| --dry-run]` | the reinstall list (points A–M of the recipe) as 19 stages: runs the scripted ones, shows the manual ones and waits, stops at each reboot and goes on afterwards from where it was (`~/.local/state/void-legion-install.stage`) |
| `migrate.sh [--dry-run]` | a machine installed with the original Spanish-named pieces (Common) → this repository's: runs only the installers of what is installed (each one removes its old pieces), fixes the personal folders in their current language (`enabled=False` in `~/.config/user-dirs.conf`: no `Downloads` next to `Descargas`), sudo once, then reboot |
| `install-i18n.sh` | installs the translations of the messages (as user, and with `sudo` for the system) ([`../docs/i18n.md`](../docs/i18n.md)) |
| `aliases.sh [--remove]` | optional: the old Spanish command names as links to the new ones ([`../docs/glossary.md`](../docs/glossary.md)) |
| `verify.sh [--secrets]` | checks: syntax, catalogs, paths of the recipe, binaries, and that no private value is in the clone or its history |
| `assets.tsv` | list of the Release's binaries: name, sha256, destination, and the release tag |

First time on a freshly installed Void (recipe, point B):

```bash
sudo xbps-install -S git github-cli
gh auth login
gh repo clone <owner>/void-legion-go2 ~/src/void-legion-go2
cd ~/src/void-legion-go2
bash install/install.sh --list
bash install/install.sh            # stage 1 is the installation itself (already done): Enter
```

A system installed with the original Spanish scripts is migrated with `bash install/migrate.sh` (from the
graphical session; `--dry-run` shows the plan first): it runs each piece's installer from this repository; every
installer removes the old Spanish-named pieces it replaces and keeps the chosen settings (the Game Mode/desktop
mode, for example). Personal folders (Descargas, Documentos…) are never touched.
