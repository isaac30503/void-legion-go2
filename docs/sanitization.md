# Private values: `@NAME@` and `local.env`

The original documentation and pieces contain values that identify the user's home, devices and accounts.
None of them is in git: each one is written as **`@NAME@`**, and the real value lives only in
**`local.env`** at the root of the clone (git-ignored, `chmod 600`). `local.env.example` lists every key with
a made-up value.

| Kind | Keys |
|---|---|
| Wi-Fi network name | `WIFI_SSID` |
| MACs (mesh router and nodes, Wi-Fi and Bluetooth of the machines, paired devices) | `MESH_ROUTER_MAC`, `MESH_NODE_A_BSSID`, `MESH_NODE_B_BSSID`, `LEGION_WIFI_MAC`, `LEGION_BT_MAC`, `IDEAPAD_WIFI_MAC`, `HEADPHONES_BT_MAC`, `KEYBOARD_BT_MAC`, `MOUSE_BT_MAC`, `XBOX_CONTROLLER_BT_MAC` |
| Filesystem UUIDs | `LEGION_ROOT_UUID`, `LEGION_SWAP_UUID`, `LEGION_EFI_UUID`, `MICROSD_UUID`, `IDEAPAD_ROOT_UUID`, `IDEAPAD_EFI_UUID`, `XS1000_EFI_UUID` |
| USB serial numbers (in logs and audio device names) | `UGREEN_MIC_SERIAL`, `USB_SERIAL_1` … `USB_SERIAL_4` |
| Accounts and identity | `STEAM_ACCOUNT_ID`, `USER_FULL_NAME`, `CLAUDE_SESSION_ID` |
| E-mail | replaced by the GitHub noreply address (`PERSONAL_EMAIL` is kept only to scan for it) |

Besides, `local.env` holds **settings** of the machine that the scripts read (not private):
`KEYBOARD_LAYOUT`, `KEYBOARD_VARIANT`, `CONSOLE_KEYMAP`, `WIFI_INTERFACE`, `TARGET_USER`. `@TARGET_HOME@` and
`@TARGET_USER@` are filled with the home and name of whoever installs.

## How the values get back to the system

- `install/render.sh` makes `build/` = the clone with every `@NAME@` filled in (git-ignored). The recipe's
  blocks copy and run from `"$B"` = `build/`, so files land on the system exactly as on the original machine.
- Installers that write a template use `render SRC DST` (`lib/common.sh`), which does the same per file.
- `install/render.sh --check` lists placeholders that `local.env` lacks.

## What was kept on purpose

- Private (RFC 1918) IP addresses of the home network (`192.168.0.x`): not reachable from outside.
- The user name `isaac` and the hostnames (`ideapad-100`, `Legion-Go-Gen-2`): they are part of paths and of
  the GitHub account name.
- SSH **public** keys (`authorized_keys` lines): public by design.
- Public identifiers of hardware and software (Lenovo WMI GUIDs, PCI ids, package maintainers' addresses).
- The public default password of the Void live ISO (`voidlinux`).

## Before every commit

```bash
bash install/verify.sh --secrets     # looks for every value of local.env (and MAC variants) in the clone,
                                     # including .bak files, logs and the contents of Release archives
```

It must print "no private values found" and, for the encrypted copy, "local.env and local.env.age say the
same". New logs (`logs/…`) are the usual source of leaks
(serial numbers, MACs in `dmesg`, UUIDs in `fstab`): add the value to `local.env`, replace it with `@NAME@`,
and run the check again.

## Encrypted copy: `local.env.age` (2026-10-13)

`local.env` exists only on the machines, so losing them would mean gathering every value again by hand. It is
kept **in the repository, encrypted** with [age](https://age-encryption.org) and a **passphrase**
(`local.env.age`, ASCII-armored, committed): without the passphrase it says nothing, even to someone who sees
the repository. With the passphrase and the GitHub account, the clone is enough to rebuild everything. The
user's decision (2026-10-13): age with a passphrase, rather than `sops` (made for teams, per-value), `git-crypt`
or GPG keys (keys are what usually gets lost), or a GitHub secret (its value cannot be read back).

- **The passphrase is never written anywhere by the scripts.** Keep it in a password manager and on paper;
  long (4–5 random words), in case the repository ever stops being private.
- `install/secrets.sh` (as the user; needs `age`: `sudo xbps-install -S age`):

```bash
bash install/secrets.sh seal      # local.env → local.env.age: passphrase twice, then once more to check the copy
git add local.env.age && git commit -m "local.env.age: …" && git push
bash install/secrets.sh open      # local.env.age → local.env (chmod 600); a different local.env is kept as local.env.old-<epoch>
bash install/secrets.sh status    # whether both say the same (part of verify.sh)
```

- **After editing `local.env`, seal again and commit** (`verify.sh --secrets` fails until then: "local.env changed
  after the last copy"). After a `git pull` that brings a new `local.env.age`, `open` (the check says "is newer").
- How it knows which one changed: `.local.env.stamp` (git-ignored) keeps the sha256 of both files after the last
  `seal` or `open`. A clone that already had `local.env` before the first `seal` has no stamp: "unknown"
  (not a failure) until `open` once (it keeps the current `local.env` aside if it differs: compare with `diff`).
- `install/render.sh` runs `open` by itself when `local.env` is missing and `local.env.age` exists (a fresh
  clone: recipe, point B).
- Git ignores every `local.env.*` except `local.env.example` and `local.env.age`.

