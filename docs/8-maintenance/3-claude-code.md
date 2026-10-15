# Claude Code

Claude Code with this machine's own context (`~/Work/CLAUDE.md`: it describes the Legion as "this machine"), its
memory notes and the **`void-maintainer`** agent (audits the system read-only with `common/agent/audit-void.sh`,
proposes fixes, prepares what needs root for the user and keeps docs/ up to date). The context, memory and agent
are personal: they live in the **private** companion repository (`claude/`, with the real values).

## Install

Without root (the installer refuses `sudo`); `curl`, `git`, `ripgrep` and `xdg-utils` come with the desktop:

```bash
curl -fsSL https://claude.ai/install.sh | bash          # ~/.local/bin/claude
P="$REPO-private"
[ -d "$P" ] || gh repo clone isaac30503/void-legion-go2-private "$P"   # next to the clone ($REPO: reinstall, stage 2)
M=~/.claude/projects/$(echo ~/Work | sed "s/[^A-Za-z0-9]/-/g")   # Claude Code's folder for ~/Work (-home-<user>-Work)
mkdir -p ~/Work/.claude/agents "$M/memory"
cp "$P/claude/CLAUDE-void-legion.md" ~/Work/CLAUDE.md
cp "$P/claude/memory/"*.md "$M/memory/"
cp "$P/claude/agents/void-maintainer.md" ~/Work/.claude/agents/
cd ~/Work && claude                                      # log in, on the Legion itself
```

The installer's warning that `~/.local/bin` is not in the `PATH` is bash's: fish already has it. Without `xdg-utils`
the browser would not open by itself for the login.

**Check:** `claude --version`; `ls ~/.claude/.credentials.json` (after logging in).

**Keeping them:** when Claude saves something new in its memory, or the context changes, copy it back to the private
repository's `claude/` and commit there.
