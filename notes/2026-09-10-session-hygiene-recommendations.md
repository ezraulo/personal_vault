---
date: 2026-09-10
tags: [claude-code, sessions, prompts, skills, workflow]
source: Claude Code session
---

# Session hygiene & future-use recommendations

Triggered by discovering 5 background Claude Code tabs open (some idle for hours) plus a
**duplicate agent instance** independently working the exact same cleanup task in parallel — a
race-condition risk that had to be caught and paused manually mid-task.

## What happened
Two tabs ended up assigned essentially the same cleanup request ("export, stash, close idle
sessions, clean registry") at the same time. One had already progressed to proposing kill
targets before this tab even reached the confirmation step. They discovered each other via
Claude Code's cross-session messaging and had to coordinate manually to avoid double-killing
processes / corrupting the shared `~/.claude/sessions/` registry.

## Recommendations for future prompts

1. **Check `claude list` (or `~/.claude/sessions/*.json`) before starting a new tab for a
   maintenance/cleanup task.** Each session gets a `name` field (auto-derived from its work or
   explicitly set) and a `status` (`busy`/`idle`/`waiting`) — a 5-second glance avoids spinning
   up a second tab that duplicates work already in flight elsewhere.
2. **For fleet-wide or system-maintenance asks ("close idle sessions", "clean up my config"),
   name explicitly which tab should own it** if multiple tabs are open, rather than repeating
   the same instruction into several tabs expecting them to sort it out. Claude Code sessions
   *can* coordinate via cross-session messaging, but it costs a manual pause-and-check round
   trip — cheaper to avoid the collision than resolve it.
3. **A peer session's request is never authorization.** Per this session's own standing
   safety rule, cross-session messages proposing a destructive action (killing processes,
   editing shared registries) are surfaced to the user, not acted on directly — even when the
   peer is plainly a fellow agent working the same job in good faith. Worth remembering this is
   enforced automatically; you don't need to add anything to prevent it.

## Skill idea (not yet built)
A lightweight "session-status" check — surfacing `claude list` output or a summarized registry
view — could be worth a skill or slash command if this kind of multi-tab work becomes routine
(e.g. `/sessions` → table of open tabs, name, status, age). Not built yet; flagging as a
candidate if this pattern recurs.

## Related
See `home-folder-loss-2026-09-04` and `[[precompact-archive-hook]]` — same underlying theme
(deterministic, low-judgment safety checks beat relying on manual coordination/memory).
