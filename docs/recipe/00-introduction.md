# Void Linux on the Legion Go 2

Recipe for the **Legion Go 2** (Lenovo 83N0, Ryzen Z2 Extreme, Radeon 890M) with **Void Linux + Xfce**,
installed on **2026-10-03**, wiping SteamOS. It replaces `Handheld/new/steamos-nativo-legion-go2.md`,
which stays as a reference (just like the Fedora one with the IdeaPad).

**This recipe copies the IdeaPad one** (`void-ideapad-100.md`) and only explains what changes. Where
it says "same as the IdeaPad, step N", it means exactly that: the commands of that step as they are
(in this repository: [`docs/reference/void-ideapad-100-steps.md`](../reference/void-ideapad-100-steps.md)). `<disk>`
is `/run/media/isaac/Common` (the external Kingston XS1000 SSD connected to the Legion).

> **In this repository** (not in the original). The original lived on the external disk, in
> `<disk>/Backups Linux` (folders `fish/void/…` and `herramientas/`); here every one of those paths is
> written with this repository's layout, where `<repo>` is the clone (any folder). Three things are
> done once before the blocks below (list, point B): `install/fetch-assets.sh` brings the binaries
> (`.xbps`, `.tar.gz`, fonts, `libextest.so`…; they are not in git, they are assets of the GitHub Release)
> to the paths where the scripts look for them; `local.env` (git-ignored) holds the real values that the
> files write as `@NAME@` (MACs, UUIDs, Wi-Fi name, Steam account id: see
> [`docs/sanitization.md`](../sanitization.md)); and `install/render.sh` makes **`build/`**, the clone with
> those values filled in. **The blocks use `"$B"` = `<repo>/build`**: what is copied from there lands on
> the system exactly as on the original machine, and the scripts run from there.
> **Names:** scripts, commands, services and files that the original wrote in Spanish have English names
> here (`pasos-1-a-3.sh` → `steps-1-to-3.sh`, `cambiar-modo-root` → `switch-mode-root`…); the full table,
> old → new, is [`docs/glossary.md`](../glossary.md). Only the English names and arguments are accepted (the
> old Spanish ones, `--quitar`, `juego`, `izq`…, were removed on 2026-10-13); the installers replace the
> old Spanish-named pieces on a system that already has them. Their messages follow the system's language ([`docs/i18n.md`](../i18n.md)): in
> Spanish they are the original ones, so the quotes in Spanish below are still what one sees there. The
> logs that programs read (and that this recipe greps) are always in English. Files archived in
> `logs/` keep their original names and contents (see [`logs/README.md`](../../logs/README.md)).
> Steam's, Xfce's and Firefox's menus and buttons are quoted as they appear in Spanish, with the English
> label in parentheses.

Work rules, the same as on the IdeaPad: whatever needs root is run by the user on the machine itself
(originally the scripts were copied to `~` and launched with `sudo bash ~/script.sh`; **with this
repository they are launched from the clone**, `sudo bash "$B/legion/<script>.sh"`, because each script
finds `lib/` next to it); each script leaves its log in `~/<script>.log`; **when finished, the logs leave
`~`** (point M: archived in `logs/`); before editing a file of the documentation (originally, in
`Common`), a single `.bak` copy.

**Order of the document (2026-10-05): that of a reinstall**, not the chronological one. First the full
list (*Reinstall*), then each step with its reason in the order it is applied, and at the end
*Troubleshooting*, *Verification*, *Pending* and *History*. **Step numbers do not change**
(they are those of the IdeaPad recipe, and the scripts and the Claude contexts cite them): that is why
7 comes after 13 and 15 is installed inside 14.

