# This repository

How the repository turns into the system, and how to keep it right. The tools are in `install/`
([install/README.md](../../install/README.md)).

## How it works

- **Private values** are written `@NAME@`; the real ones are in `local.env` (git-ignored), whose copy encrypted with
  age lives in the private companion repository (`install/secrets.sh`; [sanitization](../sanitization.md)).
  `install/render.sh` makes **`build/`**, the clone with the values filled in: the blocks of docs/ run from
  `"$B"` = `<clone>/build`.
- **Binaries** (built packages, official binaries, fonts, themes) are **GitHub Release assets**, not git, listed with
  their sha256 in `install/assets.tsv`; `install/fetch-assets.sh` puts them where the scripts look for them. The Release
  also carries the GPL ones' source (`source-*`; [THIRD_PARTY.md](../../THIRD_PARTY.md)).
- **Messages** follow the system's language through catalogs (`locale/<lang>/messages.po`; [i18n](../i18n.md)).
- **Names** are English; the Spanish originals and old step numbers: [glossary](../glossary.md).
- **`install/install.sh`** runs the [reinstall](../reinstall.md) as resumable stages; **`install/migrate.sh`** moves a
  system installed with the original Spanish-named pieces to these.

## The inventory: `install/pieces.tsv`

**Everything this repository installs, one piece per line** (2026-10-17): its machines (L, I, LI), the stage of the
[reinstall](../reinstall.md), how it is installed (`root`/`user` at that stage, `manual` from its page, `via:<piece>`
from another installer, or `tool`), its installer, its page, its files in the repository and the paths it leaves on the
machine. It exists because pieces slipped through: systemd-compat, Plymouth and `ssh-find` were installed but missing
from `install/install.sh`, and the wallpaper patches from the whole reinstall, and the maintenance agents had no list of
what to keep. Now:

- **`install/verify.sh` (and the CI) enforces it** through `install/pieces.py`: every tracked file of `common/`,
  `legion/`, `lib/` and `install/` belongs to a piece; a `root`/`user` piece's installer is in `install/install.sh` and in
  `docs/reinstall.md` or its page; a `manual` one is named in its page; a `via:` one is named by the other installer;
  pages, installers and files exist. A new piece without its line, or forgotten in the reinstall, fails.
- **The audit** (`common/agent/audit-void.sh`, section 3) checks on each machine that what its pieces install is there.
- **The maintenance agents** read it as the list of what to maintain (`python3 install/pieces.py --list`).

## Adding or changing a piece

The rules are those of a Void package (an xbps template), because a piece is the same idea one level up: something
installed and removed as a unit, whose files nobody else owns, and that says what it leaves on the system.

1. **One piece = one function, installed and undone as a unit.** Its installer puts it in place, its `undo` takes it
   away. A new file that only makes sense with an existing piece (one more labwc setting, a new runit `conf`) goes into
   that piece's `sources`, not into a new line. **Split** (as xbps splits subpackages) when parts are installed at
   different stages, on different machines, or by different hands (a script and a setting made in Steam): each part is
   its line. Do not split one installer into several pieces.
2. **Every file of the repository has exactly one owner** (`verify.sh` fails on none or on two), as a file belongs to one
   package. Tools that are not installed (diagnostics, generators, the repository's own scripts) also have an owner, with
   `how` = `tool`; diagnostic and test scripts live in `legion/diag/` and `common/diag/` (owned by `diagnostics`), so
   that nothing next to the installers looks installable.
3. **`installs` lists what proves the piece is there**, as `xbps-query -f` would, but only the identifying paths: the
   program it puts in the `PATH` (`/usr/local/bin/…`, `~/.local/bin/…`), its runit service (`/etc/sv/<name>/run`, and
   `/var/service/<name>` when it is enabled), its own configuration (`/etc/…/conf.d/…`, `/etc/sudoers.d/…`, `~/.config/…`)
   and links it creates in `/usr/bin`. Not shared folders, logs, caches or state (they come and go). A pattern with `*`
   for versioned names; no spaces (`~/homebrew/plugins/Panel*`). When no file of its own proves it: **`grep:<file>:<regex>`**
   for a setting written into a shared file (`grep:/etc/default/grub:^GRUB_TIMEOUT=0`), and **`xbps-local:<package>`** for
   our patched builds (installed, and from a local repository rather than Void's: a version would change with every
   rebuild). Every installed piece has at least one, except a `manual` setting nothing on disk proves. The audit checks
   each on its machines; `verify.sh` checks the forms.
4. **Every installed piece says how it is undone (`undo`)**, as every package can be removed: `--remove` if its installer
   takes it (preferred for scripts; `verify.sh` checks that it does), `rm` for plain copies in `~`, the command when undoing
   means going back to Void's package (`sudo xbps-install -Sf <package>`, for the patched ones), or, for the base system,
   saying so. An installer must also be **idempotent** (running it again leaves the same state) and must **never write
   over a file of a package or of someone else** (it checks with `xbps-query -o` and stops): its files go in `/usr/local`,
   in `conf.d`-style folders, in its own `/etc/sv/<name>`, or in `~`, never over what an update would replace.
5. **Settings made by hand are pieces too** (`how` = `manual`, `installer` = `-`): Steam's settings, Firefox's, Decky's
   plugins, Bluetooth pairings, Flatpak apps. Their page says how; `installs` has a path that proves them when there is
   one (`~/homebrew/plugins/Colores`, `/var/lib/bluetooth`), otherwise `-`. A reinstall that forgets them is not the
   same system.
6. **What is only on the IdeaPad and not in this repository** stays in its recipe in Common (in Spanish); `machines`
   says where the repository's pieces are installed (`I`, `LI`), not more.
7. **Removing or renaming a piece:** run its `undo` on each machine, delete its line, its installer from `install.sh` and
   `docs/reinstall.md`, its **Check** lines, and what the agents' contexts say about it, in the same commit. A rename keeps
   the old name working until both machines moved (`install/migrate.sh`, `docs/glossary.md`).

**Example (2026-10-17): systemd-compat.** One function (systemctl and friends for programs written for systemd), one
installer that takes `--remove` → one line: `L` (only the Legion has Decky), stage 15 (after InputPlumber, which it
answers for), `root`, `common/systemd-compat/install-systemd-compat.sh`, its page, `common/systemd-compat/` (every file
of the folder), `installs` = its commands in `/usr/local/lib/systemd-compat/`, its table in `/etc/systemd-compat/` and
its four links in `/usr/bin`, `undo` = `--remove`. Decky's log moving to svlogd belongs to the `decky` piece (its
installer changed), not to this one.

## Changing a script or a configuration

1. Edit it in the clone (English; messages through `t` / `_` / `__vl_t`). A new or changed message → its entry in
   `locale/es/messages.po`, then `python3 install/catalog.py refs` ([i18n](../i18n.md#rules-for-writing-messages)).
2. A private value → `@NAME@`, and the key in `local.env` and `local.env.example`.
3. `bash install/verify.sh`: syntax, ShellCheck (no errors or warnings), catalogs (a msgid no script uses fails),
   links between the documents, the paths the docs cite, binaries, private values (also in the git history) and the
   encrypted copy of `local.env`. And `bash tests/run.sh` (a few seconds; as your user, not root; a changed helper → its test).
4. Update the topic's page in `docs/` (its install, check and problems), its line in `install/pieces.tsv` (a new
   piece: a new line, and its installer in `install/install.sh` and `docs/reinstall.md`), and add a line to
   [CHANGELOG.md](../../CHANGELOG.md). The long story (diagnosis, attempts) goes to the private repository's archive.
5. Commit (identity: the GitHub *noreply* address) and push. On the Legion: `git pull`, `bash install/render.sh`, and
   run that piece's installer again from `"$B"`.

## CI and tests

GitHub Actions ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)) runs on every push and pull request,
without `local.env` and without the binaries:

- **`bash install/verify.sh --ci`:** syntax (bash, sh, fish 4, Python 3.14, XML), ShellCheck **0.11.0** (the same as
  the machines: fixed by version and sha256, so a new release does not change the result), catalogs, the inventory, links, the paths
  the docs cite, and a search for anything shaped like a MAC or a UUID in the tracked files (allowed: the made-up
  `02:00:00:…` / `0000…` ones and the kernel's public WMI GUIDs). It cannot look for the real values: that is
  `verify.sh --secrets`, here, before every commit.
- **`bash tests/run.sh`:** `render.sh` on a copy of the clone with `local.env.example` (no placeholder left, values
  and `$HOME` filled in, modes kept, `--check` with a missing value fails; as root with a user that does not exist, a message and not a silent exit,
  when the system allows user namespaces); `void-update`'s helpers (pending list from
  `xbps-install -Mun`, version coloring, the configuration reader: bad values ignored and never run as code);
  `install/pieces.py` (a file without owner or with two, an installer missing from the reinstall, a piece without
  proof); systemd-compat (systemd's answers and exit codes, runit through a fake `sv`, real session units, `journalctl`);
  `ssh-find` (`tests/ssh_find_test.py`: candidates, the neighbour table, simultaneous connections to the loopback, the
  order of the ways, a remembered address that is another machine's today, discovery rounds and the deadline, the MACs
  it learns, `--list`); and `t` (Spanish, English, unknown language, message not in the catalog). No root, network or
  Void needed.

The actions are pinned by commit (`@<sha>  # vX.Y.Z`); to update one, take the commit of its new tag
(`gh api repos/actions/checkout/git/ref/tags/vX.Y.Z --jq .object.sha`). A red CI on `main` is fixed before anything
else.

## Versions

The repository is one system, so its versions are **dates**: an annotated tag **`vYYYY.MM.DD`** on the commit that
closes a [CHANGELOG.md](../../CHANGELOG.md) entry (with CI green), whose message is that entry:

```bash
git tag -a v2026.10.14 -m "$(sed -n '/^## 2026-10-14/,/^## /p' CHANGELOG.md | sed '1d;$d')"
git push origin v2026.10.14
```

**A published tag is never moved** (whoever fetched it would have two different versions with one name): changes after
it, the same day, get **`vYYYY.MM.DD.N`** (`.1`, `.2`…), whose message is what the entry gained since the previous tag.

Two kinds of tags, not to be mixed: `vYYYY.MM.DD` (the system and its docs) and `assets-YYYY-MM-DD` (the Release of
binaries, read by `fetch-assets.sh`). `recipe-single-file` marks the last commit with the old single-file recipe.

## Changing a binary

```bash
# 1. put the new file at its destination (install/assets.tsv) and get its sha256
sha256sum common/xfce-wayland/xfdesktop-wallpaper/xfdesktop-4.20.2_3.x86_64.xbps
# 2. a new release tag (date) with every asset, so that old clones keep working with the old tag
gh release create assets-YYYY-MM-DD --title "Binaries YYYY-MM-DD" --notes "…" <all the files of assets.tsv>
# 3. in install/assets.tsv: "# release: assets-YYYY-MM-DD" and the changed lines; commit and push
bash install/fetch-assets.sh --check
```

A GPL binary needs its corresponding source in the same Release (`source-*`), listed in THIRD_PARTY.md.

## Changing `local.env`

`bash install/secrets.sh seal` (uploads the encrypted copy to the private repository; asks the passphrase), and on the
other machine `bash install/secrets.sh open`. `verify.sh --secrets` fails while they differ.

## Before every commit

```bash
bash install/verify.sh --secrets     # no private value in the clone or its history; local.env and its copy match
bash tests/run.sh                    # the same tests as the CI
```

New logs or captures are the usual source of leaks (serial numbers, MACs, UUIDs): replace them with `@NAME@`. Logs
and diagnosis captures belong to the private repository's archive, not here.
