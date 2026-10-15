## 7. Claude Code (2026-10-03)

`curl`, `git`, `ripgrep` and `xdg-utils` already come from step 5–12. Without root (the installer refuses
with sudo):

```bash
curl -fsSL https://claude.ai/install.sh | bash          # ~/.local/bin/claude (2.1.289 on 2026-10-03)
mkdir -p ~/Work ~/.claude/projects/-home-isaac-Work/memory
cp "$B/claude/CLAUDE-void-legion.md" ~/Work/CLAUDE.md
cp "$B/claude/memory/"*.md ~/.claude/projects/-home-isaac-Work/memory/
cd ~/Work && claude                                      # log in (on the Legion itself)
```

> **In this repository:** `CLAUDE-void-legion.md` → [`claude/CLAUDE-void-legion.md`](../../claude/CLAUDE-void-legion.md),
> `claude-memoria-legion/` → [`claude/memory/`](../../claude/memory/), `claude-agentes/mantenedor-void.md` →
> [`claude/agents/void-maintainer.md`](../../claude/agents/void-maintainer.md) (the agent is called
> `void-maintainer` here). They are translated into English and are installed as they are: the context and
> the agent describe the same things, and the memory still asks Claude to answer in Spanish. The Spanish
> originals stay on the external disk. The context and the agent name this repository's paths; on the
> machine, `<repo>` is the clone of point B.

The installer's warning that `~/.local/bin` is not in the `PATH` is bash's: in fish it already is
(`fish_add_path`, step 6). **The context is its own** (`CLAUDE-void-legion.md`: describes the Legion
as "this machine"; the IdeaPad's would confuse the session) and the memory carries only the two
general notes (answer in Spanish, explicit recipe), in `claude/memory/`. If Claude
saves something new here, copy that folder to the disk again (with this repository: to `claude/memory/`,
in English, and commit). Check: `claude --version` and
`ls ~/.claude/.credentials.json` (after logging in).

**`mantenedor-void` agent** (`void-maintainer` in this repository): same as on the IdeaPad (its step 7): `mkdir -p ~/Work/.claude/agents && cp
"$B/claude/agents/void-maintainer.md" ~/Work/.claude/agents/`. Its first audit
(2026-10-07) found here the `rtkit` loop (see *Watch*).

