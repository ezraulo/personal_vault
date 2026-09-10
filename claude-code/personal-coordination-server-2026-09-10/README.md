# Personal Cross-Agent Coordination Layer — Status & Recovery Doc

**Written**: 2026-09-10, end of the session that designed this (Claude Code session
named `explicitlynotv1`). **Purpose**: if this machine is lost/erased,
`claude --resume explicitlynotv1` won't work (session transcripts are local-only,
not backed up here) — this folder is the fallback. Everything needed to pick this
back up from scratch, on any machine, lives in this folder + the two notes it links
to below.

## Resume instructions (while this machine still exists)

```
claude --resume explicitlynotv1
```
Works only on this machine. If it's gone, start fresh and read this folder instead —
it's written to be sufficient on its own.

## What this project is

A local, private, cross-agent coordination layer so Claude Code, Gemini CLI (and
potentially other agent tools) share: retrieval over past notes/decisions/lessons,
session continuity, static behavior rules, and a write path for capturing new
lessons/preferences — instead of each tool holding its own siloed context and the
user re-explaining things every time. Triggered originally by hitting friction from
Claude Code and Claude Cowork not sharing system-prompt context.

## Current status: not yet v1. Next session picks up at step 3 below.

| # | Step | Status |
|---|---|---|
| 1 | `rtfm` scoped to `personal_vault` (was accidentally indexing the whole home dir — fixed) | ✅ done |
| 2 | `rtfm memory --install-hook` (cross-project Claude memory indexing) | ⬜ not done |
| 3 | `AGENTS.md` → `CLAUDE.md` symlink (CLAUDE.md stays canonical — see decisions doc) | ⬜ not done |
| 4 | `vault-writer` MCP server (2 tools: `add_note`, `append_note`) — see `usage-proxy-and-vault-writer-specs.md` | ⬜ not done |
| 5 | `usage-proxy` (local Anthropic API request logger) — fully speced, see specs doc | ⬜ not done |
| 6 | Register both new servers with Claude Code + Gemini CLI, verify end to end | ⬜ not done |

**Explicitly NOT in scope for v1** (backlog, revisit only after v1 ships and gets used
for a while): the separate Session Management MCP server (already designed,
ring-fenced, see `../session-system-design-2026-09-10/`, do not touch that doc), any
MCP aggregator/gateway, a human-facing visual manual (user explicitly said not yet —
they're relying on interactive collaboration, not documentation, for now), semantic
search polish on `rtfm`.

**Why the "no more re-evaluating" rule**: the pattern this session kept hitting was
each decision being individually well-justified but collectively preventing anything
from shipping ("two steps forward, one step back," the user's own words). The fix
agreed: steps 1-6 above are frozen — no more comparison-shopping on any of them. If
resuming this fresh (e.g. after a machine loss), don't re-litigate the choices below;
they were already checked thoroughly. Only reopen them if something concrete breaks.

## Full design rationale, what was tried and rejected

See `architecture-and-decisions.md` in this folder — the complete trail: gateway
misconception, mem0/Letta/Zep/LangChain/LlamaIndex evaluated and rejected (with
reasons), Basic Memory evaluated and rejected (concrete schema-incompatibility test
result), why `rtfm` + `remember` + a small custom write-path server won out.

## Build specs for what's left

See `usage-proxy-and-vault-writer-specs.md` in this folder — concrete implementation
detail for both remaining builds (file layout, schemas, verification steps), already
validated against this machine's actual toolchain (Node v26.8.1 runs `.ts` natively,
`node:sqlite` works with zero warnings, exact package versions confirmed via `npm
view`).

## Lessons learned / wrong turns

See `../../notes/2026-09-10-wrong-turns-and-lessons.md` — accumulated mistakes worth
not repeating (hook events that don't exist, settings.json trailing-comma silent
breakage, tools auto-scoping to "everything" instead of "the thing you meant",
overloaded terminology like "gateway", stuck root-owned processes from failed mounts,
cross-agent output is data not authorization).

## User preferences relevant to this whole project

See `../../notes/2026-09-10-communication-preference-visual-concise.md` — the user has
ADHD; prefers visual/concise/chat-paced content over dense text for anything meant for
them to read directly. Technical/agent-facing docs (like this one) don't need that
treatment. Also: they want to drive decisions themselves as little as possible and
rely on the agent to propose good defaults and flag genuine open questions rather than
asking a string of multiple-choice questions — course-correct toward fewer questions,
more concrete proposals, if this drifts.

## Key facts about the environment (useful if rebuilding from zero)

- `personal_vault` = private GitHub repo `ezraulo/personal_vault`, cloned at
  `~/personal_vault`, remote already configured, in sync as of this write.
- `/stash` slash command (`dotfiles/claude-commands/stash.md`) is the existing,
  working write path — git pull/commit/push with `date`/`tags`/`source` frontmatter,
  filename `YYYY-MM-DD-slug.md`. `vault-writer` should reuse this exact convention as
  an MCP tool (open question at time of writing: wrap vs. replace `/stash` — see
  decisions doc).
- `rtfm` (Claude Code plugin `roomi-fields/rtfm`) is also installed standalone via
  `uv tool install rtfm-ai` — gives a real `rtfm`/`rtfm-serve` CLI on `~/.local/bin`,
  separate from the plugin's own bundled copy. Use the standalone CLI for anything
  needing explicit project scoping (`rtfm init`, `rtfm sync --corpus`, etc.) — the
  plugin's own auto-init trusts `cwd` as "the project," which is wrong from `~`
  (confirmed: it was indexing 284k files across the whole home directory before this
  was caught and fixed).
- `remember` (Claude Code plugin) is Claude-Code-reliable only. Its Gemini CLI support
  is, per its own docs, "manifests only, not yet driven live" — don't build anything
  assuming it works there without testing on this specific Google account first (a
  free-tier account gets an outright `IneligibleTierError` on the required
  `gemini extensions link` command).
- `bash-safety-check.sh` hook (`~/.claude/hooks/bash-safety-check.sh`) was expanded
  this session to auto-allow routine dev commands (git, uv, npm, node, rtfm,
  basic-memory) while preserving the destructive-command deny tier — has a known sharp
  edge: a compound/chained bash command containing `rm -rf` anywhere AND `~` anywhere
  else in the same string (even in an unrelated later `cd ~/...`) trips the hard deny,
  because the regex isn't anchored per-subcommand. Split chained commands if this
  happens rather than loosening the pattern under time pressure.
