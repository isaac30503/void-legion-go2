# Own patches and packages built here

Five pieces run with a patch, because the fix is not in Void (or upstream) yet:

| Piece | Patch | Built with | Page |
|---|---|---|---|
| `xfdesktop` 4.20.2_2 | upstream commit `ed26b06a` | `common/xfce-wayland/xfdesktop-wallpaper/build-xfdesktop.sh` | [wallpaper](../5-desktop/4-wallpaper.md) |
| `Thunar` 4.20.10_2 | ours: the monitor's connector name | `common/xfce-wayland/thunar-wallpaper/build-thunar.sh` | [wallpaper](../5-desktop/4-wallpaper.md) |
| `gamescope` 3.17.0_2 | ours: PipeWire use-after-free | `common/steam/gamescope-patch/build-gamescope.sh` | [screen sharing](../7-apps/1-screen-sharing.md#in-game-mode) |
| `xdg-desktop-portal-wlr` 0.8.4_2 | ours: 3, session restore for windows | `legion/portal-wlr-patch/build-portal-wlr.sh` | [screen sharing](../7-apps/1-screen-sharing.md) |
| `steamos-manager` v26.4.1-void-2 | ours: `set_clocks` only in `manual` | `common/steam/steamos-manager/build-steamos-manager.sh` | [steamos-manager](../6-game-mode/3-steamos-manager.md) |

The `.xbps` packages are built with Void's own templates (`xbps-src`, without root: user namespaces) with Void's
revision + 1, so xbps keeps them until Void publishes a newer one (`void-update` compares them with `xbps-uhelper cmpver`). Built packages also go to the Release
([this repository](4-this-repository.md)). After a build, `~/src/void-packages` (≈1 GB) can be deleted. **Not
patched, only built or brought from outside xbps** (and so outside the test below): InputPlumber, `extest`, the TDP
modules (DKMS) and the gamescope portal.

## Is each patch still needed? `patch-still-needed`

Instead of guessing from version numbers, the patch is **tested against the real new code**. `void-update`
(summary, and before confirming an update that would replace one) and every `build-*.sh` (before building) run it.

```bash
patch-still-needed void <package> <patch>…            # Void's current template (void-packages master)
patch-still-needed git <url> <ref> <name> <patch>…    # a tag or branch upstream (steamos-manager)
```

`~/.local/bin/patch-still-needed` (`common/patch-test/patch-still-needed.sh`), installed by `install-void-update.sh`
(or alone: `bash "$B/common/patch-test/install-patch-test.sh"`, without root), with the patches it tests in
`~/.local/share/void-update/patches/<package>/`. It clones only that template (`git clone --depth 1 --filter=blob:none
--sparse`), reads **only plain assignments** from it (`version`, `revision`, `distfiles`, `checksum`, `patch_args`,
`_*`; nothing with `$(` or backquotes), downloads the first distfile into a new temporary directory, **checks its
sha256** against the template's, applies Void's own patches and tests ours in order with `git apply --check` (then
`--reverse --check`), first with full context and then with 1 line (`-C1`, like xbps-src's fuzz; reported as
`reduced_context`).

| Result | Means | Then |
|---|---|---|
| `STILL_NEEDED` | the patch applies: the new code lacks the fix | keep it; rebuild when Void's version changes |
| `ALREADY_INCLUDED` | it applies in reverse: the code has it | go back to Void's package: `sudo xbps-install -Sf <package>` (plus `thunar -q`, or restarting the portal; gamescope: `sudo xbps-install -Sf gamescope && sudo setcap cap_sys_nice=eip /usr/bin/gamescope`) |
| `PARTIAL` | some patches included, some not | drop the included ones and rebuild |
| `CONFLICT` | neither: upstream rewrote that part | review the patch by hand |
| `UNCHECKED` | no network or could not verify | nothing (exit 0: it does not break callers) |

Output: one line `PATCH <file> <state>` per patch and one `RESULT <name> <tested version> <state> <detail>`. Cache:
`~/.cache/void-update/patches/` (not for `UNCHECKED`); `--version <version_revision>` answers from it without network;
`--no-cache` ignores it.

## When Void updates a patched package

`void-update` warns **before confirming** ("Void will replace … patched") with the test's result. Choices: let it
(if the patch is already included), or answer no and rebuild with the piece's script (if `~/src/void-packages`
exists from before, delete it first: the scripts do not update it), or keep the current one with
`sudo xbps-pkgdb -m hold <package>` (losing Void's other fixes). If Void publishes **the same version and revision** as
the one built here, xbps does not install it but it is a newer build of Void's: the summary warns to rebuild. Whether a package is still the one built here: `xbps-query -p repository gamescope` (a local `hostdir/binpkgs` path, not `http`).
