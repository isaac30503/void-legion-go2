# systemd-compat: programs written for systemd, on runit

Programs made for SteamOS or other systemd distributions call `systemctl`, `journalctl`, `systemd-run` or
`systemd-inhibit`, usually with **absolute paths** (`/usr/bin/systemctl restart plugin_loader`). On Void (runit +
elogind) those commands did not exist and the request failed without a word. The visible case (2026-10-17): Hooandee's
Decky plugins **Panel de Control** and **Colores** download their updates and then show a "restart Decky" button that
never restarts it. Reading their code turned up more:

| Plugin call | Without systemd-compat |
|---|---|
| `/usr/bin/systemctl restart plugin_loader` (both, after updating themselves) | the button does nothing |
| `systemctl is-active inputplumber.service` (Panel: which controller manager runs) | "none": **its controller section stays hidden**, although InputPlumber runs (runit) |
| `systemctl --user restart filter-chain.service` + `show -p InvocationID,MainPID` (Panel's equalizer) | the EQ never applies |
| `systemd-inhibit --what=sleep --mode=delay` (Colores: lights off before suspending) | "native suspend monitor failed" |
| `systemd-run --user --unit=pdc-kiosk …`, `journalctl --user …` (Panel's second screen, other hardware) | fails |
| `journalctl -b -u plugin_loader`, `-k`, `-t …` (both, for their bug reports) | those sections empty |

**systemd-compat** answers them with the real thing underneath, **without modifying any program** and **without
anything running**: each call is a short `sh` script (dash; ~4 ms on the IdeaPad's spinning disk, like a real
`systemctl` over D-Bus), and a unit it starts is the program itself, holding a lock (`flock`) that tells whether it is
active; the kernel releases it when the program ends. No daemon, no polling. Code in `common/systemd-compat/`.

```bash
sudo sh "$B/common/systemd-compat/install-systemd-compat.sh"   # --remove undoes it (keeps your units.d files)
sudo sh "$B/common/steam/install-decky.sh"                     # Decky's log to /var/log/decky (for journalctl -u)
```

The installer puts the commands in `/usr/local/lib/systemd-compat/` with links in `/usr/bin` (**only on free paths
or its own**: it stops if a package or someone else owns one), `/usr/bin/systemd-inhibit` → `elogind-inhibit` (the
same program: elogind is systemd's logind, renamed), the table `/etc/systemd-compat/units.d/50-void-legion.conf`, and
the packages of `requires` that are missing — also the ones SteamOS ships and the plugins take for granted:
**`python3-yaml`** (Panel's button remaps go through the system Python's PyYAML), **`caps`** (the equalizer's bass and
loudness) and `hidapi` (Colores). Then it restarts Decky: the plugins look for systemd only when they start.
Repeating `install-decky.sh` does not download Decky again if the latest version is there.

## How a unit name resolves

| Scope | Order |
|---|---|
| system | a line of `units.d` (runit alias, exec unit or `deny`) → a transient unit of `systemd-run` → **the runit service of the same name** (`/etc/sv/<name>`) → not found |
| `--user` | a line of `units.d` → a transient unit → not found |

So `inputplumber.service`, `sshd.service`, `steamos-manager.service`… work with no configuration. `units.d` is only for
names that differ, user units and exceptions:

```
# NAME          SCOPE   KIND   …
plugin_loader   system  runit  decky  log=/var/log/decky/current
filter-chain    user    exec   pipewire -c filter-chain.conf
```

- **runit SERVICE [log=FILE]:** start/stop/restart go to `sv` (they wait for the result, like systemd; `--no-block`
  detaches). **When the caller runs inside that service** (a Decky plugin restarting Decky), it is detached by itself:
  systemd does it as a job of its own, and a synchronous restart would kill the caller halfway. `is-active`, `status`,
  `show` read `supervise/` (root only: as a user, `unknown`). `journalctl -u` reads FILE (default
  `/var/log/<service>/current`, svlogd).
- **exec COMMAND:** a process unit, like a systemd user unit: started in a session of its own with a clean
  environment (the caller's `HOME`, `XDG_RUNTIME_DIR`, D-Bus, display…), its output in its folder for `journalctl`,
  stopped by signalling its process group (SIGTERM, SIGKILL after 10 s). `show` gives a new `InvocationID` and the
  `MainPID` on every start, as Panel's equalizer expects.
- **deny:** the unit does not exist even if a runit service has that name.

Your own lines go in another file (`90-local.conf`, read later: the last match wins); the installer only replaces
`50-void-legion.conf`. Changes apply on the next call (`daemon-reload` is a no-op on purpose).

## What it answers

- **`systemctl`:** `start stop restart try-restart reload reload-or-restart is-active is-failed is-enabled status show
  cat kill reset-failed list-units list-unit-files daemon-reload`, patterns (`hhd@*.service`), `--user`, `--quiet`,
  `--value`, `-p`, `--no-block`, `--state`, `--type`; `poweroff reboot suspend hibernate hybrid-sleep halt` →
  `loginctl` (elogind, with the same polkit rules). `is-system-running` = `offline`, what systemctl says on a machine
  not booted with systemd. `enable/disable/mask` are refused: runit services are enabled by hand.
- **`systemd-run`:** `--user`, `--unit`, `--description`, `--collect`, `--quiet`, `--nice`, `--setenv`, `--property`
  (`Nice=`, `Environment=`, `WorkingDirectory=`; resource limits like `CPUWeight=` are accepted but not applied — no
  cgroups — and noted), `--same-dir`, `--working-directory`, `--uid/--gid` (root), and in the foreground `--pipe`,
  `--wait`, `--pty`, `--scope`.
- **`journalctl`:** `-k` (dmesg, root), `-u` (svlogd log of the runit service), `--user -u` / `--user-unit` /
  `_SYSTEMD_USER_UNIT=` (output of an exec or transient unit), `-t` (that runit service's log, or socklog's if it is
  ever installed); `-b` (this boot), `--since/--until`, `-p` (kernel only), `-g` (PCRE, smart case), `-n`, `-r`,
  `-o cat`, `-f`. **Previous boots are not kept:** `-b -1` answers like a journal without that boot. Services that
  still log to syslog through `vlogger` (nothing collects it here) have no log for it.
- **Unknown units and anything else:** systemd's own messages and exit codes ("Unit x.service not found.", 5;
  `is-active` → `inactive`, 3), because programs read them.

**What stays as it was:** nothing creates `/run/systemd`, so programs that check whether systemd *runs* (dracut,
mdadm, resolvconf, dhcpcd, e2scrub) still see that it does not. Xfce's `xinitrc` and labwc ask for a systemd user
manager on every login (`systemctl --user list-jobs`, `import-environment`); they still get the failure (checked by the
installer). Before installing it, everything on the Legion that looks for `systemctl` was reviewed (text files and
binaries; 2026-10-17): none changes behavior because the file exists.

## Maintenance: `void-update --systemd`

Every request that is not fully served (unit not found, option not supported, partial answer) leaves one line in
`requests.log` (root's in `/run/systemd-compat/`, the user's in `$XDG_RUNTIME_DIR/systemd-compat/`; per boot, 256 KB
at most; the values of `--setenv`/`Environment=` hidden). `void-update --systemd` shows:

- the installation: links, files against their `MANIFEST` and against the repository (a newer one → "repeat the
  installer"), the packages of `requires`, and that each `units.d` line points to something that exists;
- **the programs that call systemd** (each subfolder of `systemd_compat_scan` in `void-update.conf`; default
  `~/homebrew/plugins`): how many lines, and **what changed since the last review** as a diff — a plugin update
  that calls systemd differently shows up here before anyone notices it failing; and the units each one names, with
  what they are here (runit service, unit of systemd-compat, hidden, does not exist);
- **the requests not served** since the last review, grouped, with who asked.

`void-update --systemd --ack` marks it all reviewed. The **summary** of every update has one line: `✓ systemd` or
`⚠ systemd` "to review" / "N problem(s)" / "not installed" (when programs call systemd and it is missing).
When a request shows up that should be served: a line in `units.d` (an alias, a user command) or, for a new kind of
request, a change in `common/systemd-compat/` with its test in `tests/run.sh`.

## Check

```bash
ls -l /usr/bin/systemctl /usr/bin/systemd-inhibit     # → /usr/local/lib/systemd-compat/systemctl, → elogind-inhibit
systemctl is-system-running                           # offline
sudo systemctl is-active inputplumber.service plugin_loader.service   # active, active
systemctl --user list-jobs; echo $?                   # 1 (no systemd user manager)
sudo journalctl -b -u plugin_loader -n 5              # Decky's last lines (after install-decky.sh)
void-update --systemd                                 # no problems; review, then --ack
```

In Game Mode: **Panel de Control** shows its controller section (InputPlumber detected) and its update button restarts
Decky; Colores' log no longer says `native suspend monitor failed`.
