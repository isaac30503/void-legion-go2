# `ssh-setup` — set up or redo SSH access to a machine of the network

Backup of 2026-09-25. These two files are the tool with which access to the other machines is
recovered, so they should survive any reinstall.

> In this repository: `common/ssh-setup/ssh-setup.fish` and `common/ssh-setup/ssh-survey.sh`.
> Previous (Spanish) location and name: `Backups Linux/herramientas/` on the external disk, with this
> manual as `LEEME-ssh-setup.md`. The function is still called `ssh-setup`; its options are the English ones
> (`--user`, `--diagnosis`, `--no-claude`; the old Spanish `--usuario`, `--diagnostico` and `--sin-claude` were
> removed on 2026-10-13).

## Where they go

| File | Destination |
|---|---|
| `ssh-setup.fish` | `~/.config/fish/functions/ssh-setup.fish` |
| `ssh-survey.sh` | `~/.config/fish/ssh-survey.sh` (with execute permission) |

Fish autoloads the functions in `functions/`, so nothing has to be added to
`config.fish`. The x-ray goes **separately and in bash** on purpose: it is sent with
`ssh <alias> bash -s < file`, and that way it works even if the remote machine's shell is fish.

Their messages follow the system's language (see [i18n.md](i18n.md)): they need
`~/.config/fish/functions/__vl_t.fish` and the catalogs in `~/.local/share/void-legion/` (both installed
by `install/install.sh`; without them, English). The x-ray runs on the other machine, which may not have
the catalogs: `ssh-setup` sends in front of it, through the same `stdin`, the local catalog and
`lib/i18n.sh` (they go to a temporary folder there that is deleted at the end), so it comes out in the
language of whoever reads it. Run alone (`ssh <alias> bash -s < ssh-survey.sh`), it comes out in English.

## Usage

```fish
ssh-setup                                       # default machine (alias 'lego')
ssh-setup ideapad --ip 192.168.0.172 -u <user>  # setting up a new machine
ssh-setup lego --diagnosis                      # only looks, touches nothing
ssh-setup --help
```

The alias is the first loose argument. The user and the IP come from `~/.ssh/config` if the
alias already exists, so from the first time on `ssh-setup <alias>` is enough. Without a user in
`~/.ssh/config` nor `--user`, the same user name as on this machine is used (the original wrote its
owner's name there, which on their machines is the same thing).

**Default machine, when no alias is given.** It comes from the universal variable
`$ssh_setup_default_host`, which is set **once per machine**:

```fish
set -U ssh_setup_default_host <alias>
```

It depends on where it is installed, because a machine does not diagnose itself:

| Installed on | Value | Reason |
|---|---|---|
| MSI Thin 15 | `lego` | the console is what gets debugged the most |
| IdeaPad (Void) | `lego` | same (without the variable: the fallback applies) |
| Legion Go 2 | `ideapad` | from the console, the useful destination is the IdeaPad |

If the variable is not set, the fallback value is `lego`.

## Where it is installed (2026-09-25)

On the three machines, with the same content (verified by `md5sum`). When touching one, copy
to the other two and to the backup of this folder, or they get out of sync without warning.

**2026-10-01:** `ssh-survey.sh` changed (Void support). Copied to the backup, to the Legion and
to the IdeaPad; **the MSI still has the previous version** (its `sshd` is turned off). On
SteamOS the new output is identical to the previous one (checked with `diff`).

**2026-10-01, `ssh-setup.fish`:** with the destination's `sshd` stopped it no longer suggests only
`systemctl`: without SSH one does not know which system is on the other side, so it gives both commands,
`sudo systemctl enable --now sshd` (systemd) and `sudo ln -s /etc/sv/sshd /var/service/`
(runit, Void). The messages say "the machine's console" instead of "the Legion's".
Copied to the backup, to the Legion and to the IdeaPad; **the MSI keeps the previous version**.

**2026-10-09, this repository:** English version with translated messages (same behavior; with the
Spanish catalog the output is identical to the previous one, checked with `diff`, including the x-ray
sent to a machine with another language).

## What it does, in order

1. **Locates** the machine: it tries the saved IP and only sweeps the network if it does not answer. The
   sweep is by **ICMP, not TCP**, because with `sshd` stopped there is no port
   that gives the machine away. It excludes its own addresses and the gateway.
2. **Diagnoses the port** with the control-port test (see below) and, if it fails,
   prints the exact command that has to be typed on the machine's console. It stops there:
   that cannot be fixed from outside.
3. **Host key**: it deletes the old one and registers the new one in the same step.
4. **Route and access**: it updates or creates the `Host` block in `~/.ssh/config` (with a
   backup), including IP **and user**, and installs the public key if needed.
5. **Claude Code** and its PATH with `fish_add_path`.
6. **X-ray** of the system: distribution, edition, firewall, network, root's files
   in `$HOME` and whether Claude Code has a session logged in. It works on Arch/CachyOS, SteamOS,
   Fedora (including Atomic) and Void (xbps + runit, since 2026-10-01: services through the
   links in `/var/service`, `sshd` active through `pgrep` because `sv status` asks for root,
   updates with `xbps-install -un`).

## The control-port test

When port 22 does not answer, **also test any closed port** (9999). The
comparison between the two answers gives the diagnosis without guessing:

| Port 22 | Control port | Means |
|---|---|---|
| silence ~6 s | silence ~6 s | firewall that **drops** (`ufw` style) |
| *no route to host* | *no route to host* | firewall that **rejects** (`firewalld` style) |
| *connection refused* | *connection refused* | there is no firewall and **`sshd` is stopped** |
| *connection refused* | *no route to host* | there is a firewall, **port 22 is already allowed**, the service is missing |

That last row is a real case: that is how the IdeaPad was diagnosed on 2026-09-25.

## Dependencies

Only base tools: `ssh`, `ssh-copy-id`, `ssh-keyscan`, `ssh-keygen`, `setsid`,
`shred`, `ping`, `curl`. Nothing to install.

## Two details that are not obvious

- **The password never travels through the same `stdin` as a script.** It goes to a separate file
  that an askpass reads, and it is destroyed with `shred` at the end. Mixing them makes `sudo -S`
  eat the script's lines as password attempts, and `pam_faillock` locks the
  account for ten minutes.
- **`--diagnosis` forces `BatchMode=yes`.** Without it, diagnosing a machine where the key
  is not installed yet spent **three password attempts** per diagnosis. It really happened
  on 2026-09-11. For the same reason `ssh-copy-id` carries `NumberOfPasswordPrompts=1`.
