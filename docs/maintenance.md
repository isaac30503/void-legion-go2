# Maintaining this repository

The rules of the original recipe apply (the recipe must be followable without inferring anything; each
change goes in its step, *Verification*, *Troubleshooting* if it applies, and *History*). On top of that:

## Changing a script or a configuration

1. Edit it in the clone (English; messages through `t` / `_` / `__vl_t`, see [i18n.md](i18n.md)). New
   message → add its translation to `locale/es/messages.po` (and any other catalog).
2. If it carries a private value, write `@NAME@` and add the key to `local.env` and `local.env.example`
   ([sanitization.md](sanitization.md)).
3. `bash install/verify.sh` (syntax, catalogs, paths of the recipe, private values).
4. Update `docs/void-legion-go2.md` (the step, and an entry in *History*), commit and push.
5. On the Legion: `git pull`, `bash install/render.sh`, and run the installer of that piece again from `"$B"`.

## Changing a binary (a rebuilt `.xbps`, a new InputPlumber, Orchis…)

Binaries are assets of the GitHub Release, listed in `install/assets.tsv` (name, sha256, destination).

```bash
# 1. put the new file where the scripts look for it (the destination of assets.tsv) and get its sha256
sha256sum common/xfce-wayland/xfdesktop-wallpaper/xfdesktop-4.20.2_3.x86_64.xbps
# 2. new release tag (date) with every asset, so old clones keep working with the old tag
gh release create assets-YYYY-MM-DD --title "Binaries YYYY-MM-DD" --notes "…" <all the files of assets.tsv>
# 3. in install/assets.tsv: "# release: assets-YYYY-MM-DD" and the changed line(s); commit and push
bash install/fetch-assets.sh --check
```

## Updating the Spanish original

This repository is the English, sanitized form of the Legion's part of `Backups Linux` on the external disk.
If something is changed on the disk first, bring it here translated (same content, English names) — or the
other way round — so both say the same. `docs/glossary.md` keeps the correspondence of names.
