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

It must print nothing but "no private values found". New logs (`logs/…`) are the usual source of leaks
(serial numbers, MACs in `dmesg`, UUIDs in `fstab`): add the value to `local.env`, replace it with `@NAME@`,
and run the check again.
