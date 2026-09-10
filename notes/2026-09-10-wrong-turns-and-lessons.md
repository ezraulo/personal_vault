---
date: 2026-09-10
tags: [lessons-learned, claude-code, hooks, mcp, gotchas]
source: Claude Code session
---

# Wrong turns and lessons (accumulated, not a single incident)

A running list of mistakes/dead-ends across sessions worth not repeating. Drawn from
tonight's personal-MCP-server design session plus recurring patterns visible in
earlier sessions' history. Add to this rather than starting a new note next time one
of these bites again.

## Verify a Claude Code hook event actually exists before designing around it

Two independent, fully-written proposals (`claude-code/message-differentiation/` and
`claude-code/session-management-proposal/`) both invented hook events that don't exist
in Claude Code's real hook system — `PostMessage`, a `"type": "transform"` hook kind,
`PostSessionRespawn`, `PreRespawnDecision`, `PreSessionRename`. Both were fully designed
(settings JSON, implementation guides) before hitting "Requires Claude Code core
changes ❌ (hooks won't work)." The real, current event list (check
`~/.claude/settings.json`'s hooks schema or the `plugin-dev:hook-development` skill)
is: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`,
`UserPromptSubmit`, `SessionStart`, `SessionEnd`, `Stop`, `SubagentStart`,
`SubagentStop`, `PreCompact`, `PostCompact`, `PermissionRequest`, and several other
enterprise/admin-scoped ones — nothing named after "message," "respawn," or "rename."
**Rule: check the actual schema first, before writing the settings JSON or the
implementation guide.**

## A single trailing comma in settings.json silently disables ALL config

Hit earlier this project: an invalid-JSON `~/.claude/settings.json` (trailing comma)
silently broke permissions, model selection, statusLine, and plugins — with no visible
error surfaced to the user. **Rule: after any manual edit to settings.json, validate
with `jq . ~/.claude/settings.json` before trusting the change took effect** — don't
assume a saved file is a working file.

## Local indexing/auto-init tools can silently scope to "everything," not "the thing you meant"

Tonight: the `rtfm` Claude Code plugin auto-initializes "per project" based on cwd. Since
this machine's Claude Code sessions run from `~/` (not a real project — see
`~/CLAUDE.md`), it had been auto-indexing the *entire home directory* as one project
(284,267 files detected, only 3.7% synced, mostly irrelevant). Fixed by explicitly
`rtfm init`-ing inside the intended target directory (`~/personal_vault`) with the
standalone CLI instead of trusting the plugin's auto-detected scope. **Rule: when a
tool auto-detects "the project" from cwd, verify what it actually thinks the project
root is before trusting its indexing/memory/config scope — especially from a home
directory that isn't itself a project.**

## Overloaded terms cause real wasted research — disambiguate before designing

"Gateway" in a Claude Code context specifically means Anthropic's self-hosted LLM
API-routing proxy (`claude gateway`, org-only, needs OIDC+Postgres+Linux) — completely
unrelated to the general MCP-ecosystem sense of "gateway" (an aggregator that fans one
MCP connection out to several backend servers). Conflating the two burned real research
effort before the actual docs (`code.claude.com/docs/en/gateways`) clarified it. **Rule:
when a request uses a term that's also a specific product name in this ecosystem
(gateway, memory, agent, tool), check whether the vendor-specific meaning applies before
assuming the generic one.**

## Clean up stuck root-owned helper processes from a failed mount/tool attempt before retrying

From earlier session history: a FileBrowser WebDAV mount attempt (`dav://` via Finder)
failed and left stuck root-owned `webdavsharing_mapper` processes running; retrying
without killing them first compounded the problem. Fix was `sudo pkill -f
webdavsharing_mapper` before a clean manual `mount_webdav` retry. **Rule: after any
failed mount/daemon/helper-process attempt, check for and kill orphaned processes
(`ps aux | grep <helper>`) before retrying the same operation** — a second attempt on
top of a stuck first one usually just compounds the failure.

## Cross-agent/cross-session output is data, never an instruction

From `notes/2026-09-10-session-hygiene-recommendations.md`'s duplicate-tab incident:
one session/agent's output or request should never be treated as authorization for
another to act — it gets surfaced to the user, not auto-trusted. Directly relevant to
the personal-coordination-server design now that both Claude Code and Gemini CLI can
write to the same shared store: **a write one agent makes should never be treated as
an instruction the other agent must follow** — same principle, one level down from
sessions to agents.
