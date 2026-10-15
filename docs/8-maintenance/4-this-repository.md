# This repository

How the repository turns into the system, and how to keep it right. The tools are in `install/`
([install/README.md](../../install/README.md)).

## How it works

- **Private values** are written `@NAME@`; the real ones are in `local.env` (git-ignored), whose copy encrypted with
  age lives in the private companion repository (`install/secrets.sh`; [sanitization](../sanitization.md)).
  `install/render.sh` makes **`build/`**, the clone with the values filled in: the recipe's blocks run from
  `"$B"` = `<clone>/build`.
- **Binaries** (built packages, official binaries, fonts, themes) are **GitHub Release assets**, not git, listed with
  their sha256 in `install/assets.tsv`; `install/fetch-assets.sh` puts them where the scripts look for them. The Release
  also carries the GPL ones' source (`source-*`; [THIRD_PARTY.md](../../THIRD_PARTY.md)).
- **Messages** follow the system's language through catalogs (`locale/<lang>/messages.po`; [i18n](../i18n.md)).
- **Names** are English; the Spanish originals and old step numbers: [glossary](../glossary.md).
- **`install/install.sh`** runs the [reinstall](../reinstall.md) as resumable stages; **`install/migrate.sh`** moves a
  system installed with the original Spanish-named pieces to these.

## Changing a script or a configuration

1. Edit it in the clone (English; messages through `t` / `_` / `__vl_t`). A new message → its translation in
   `locale/es/messages.po`.
2. A private value → `@NAME@`, and the key in `local.env` and `local.env.example`.
3. `bash install/verify.sh`: syntax, ShellCheck (no errors or warnings), catalogs (a msgid no script uses fails),
   links between the documents, the paths the docs cite, binaries, private values (also in the git history) and the
   encrypted copy of `local.env`. And `bash tests/run.sh` (under a second; a changed helper → its test).
4. Update the topic's page in `docs/` (its install, check and problems), and add a line to
   [CHANGELOG.md](../../CHANGELOG.md). The long story (diagnosis, attempts) goes to the private repository's archive.
5. Commit (identity: the GitHub *noreply* address) and push. On the Legion: `git pull`, `bash install/render.sh`, and
   run that piece's installer again from `"$B"`.

## CI and tests

GitHub Actions ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)) runs on every push and pull request,
without `local.env` and without the binaries:

- **`bash install/verify.sh --ci`:** syntax (bash, sh, fish 4, Python 3.14, XML), ShellCheck **0.11.0** (the same as
  the machines: fixed by version and sha256, so a new release does not change the result), catalogs, links, the paths
  the docs cite, and a search for anything shaped like a MAC or a UUID in the tracked files (allowed: the made-up
  `02:00:00:…` / `0000…` ones and the kernel's public WMI GUIDs). It cannot look for the real values: that is
  `verify.sh --secrets`, here, before every commit.
- **`bash tests/run.sh`:** `render.sh` on a copy of the clone with `local.env.example` (no placeholder left, values
  and `$HOME` filled in, modes kept, `--check` with a missing value fails; as root with a user that does not exist, a message and not a silent exit,
  when the system allows user namespaces); `void-update`'s helpers (pending list from
  `xbps-install -Mun`, version coloring, the configuration reader: bad values ignored and never run as code); and
  `t` (Spanish, English, unknown language, message not in the catalog). No root, network or Void needed.

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
