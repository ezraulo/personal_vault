# Session hygiene: fast Bash safety hook + session-status/management script

## Context

Two related but separate problems surfaced in this conversation:

1. **Every Bash command triggers a slow, LLM-judged permission check.** `~/.claude/settings.json` has a `PreToolUse` hook on `matcher: "Bash"` with `"type": "prompt"` — this fires on literally every Bash call (`ls`, `grep`, `cat`, not just risky ones), spending a model round-trip to decide whether to allow it. The user wants `defaultMode: "plan"` kept as-is (confirmed explicitly — not changing it). They clarified the actual requirement precisely: **only clearly-safe, non-destructive commands should skip the approval prompt.** Anything not clearly safe — including narrowly-scoped commands that touch risky territory (e.g. a scoped `rm` on one specific file) — must still stop and ask for explicit approval, not be silently auto-accepted. This hook exists because of the 2026-09-04 home-directory-wipe incident (see `home-folder-loss-2026-09-04` memory), so the fix must not weaken that protection — it should only remove *latency/friction on the obviously-safe path*, not expand what's auto-allowed.

   **Global scope, confirmed:** `~/.claude/settings.json` is the user-level settings file — it applies to every Claude Code session on this machine, in every project directory, since there is no per-project `.claude/settings.json` anywhere on this machine that would override or shadow it (only `~/.claude/settings.local.json` exists alongside it, which holds unrelated permission allowlist entries and does not touch this hook). Editing the global file is sufficient; no other file needs the same change.

2. **No single view of "what sessions/jobs are alive and what are they doing."** The user has accumulated local interactive sessions, local background jobs, and cloud-bridged sessions over recent session-hygiene work, and currently has to run `claude agents --json`, cross-reference `~/.claude/jobs/*/state.json`, and read transcripts by hand to figure out what's live and what it's for. They want a manual script that surveys everything (local + cloud, where visible), summarizes each session's content, and lays out what can be done with it beyond resume/delete.

   **Why merging isn't offered as an option:** the research agent checked the CLI (`claude --help` and every hidden subcommand's `--help`), the settings schema, and every plugin/skill directory on this machine for anything resembling session merge — none exists. Two independent transcripts (each its own `.jsonl` DAG of `uuid`/`parentUuid`-linked turns, its own `sessionId`) have no supported way to be combined into one session; `--fork-session` only *branches* one session into two, it doesn't join two into one. The closest practical substitutes, which the script will surface instead: **fork** (`--fork-session`, branch a copy), **rename** (`-n`), **export** (copy the `.jsonl`), and **cross-session handoff** (`SendMessage`/`csd handoff` — one live session summarizes and passes context to another, which is a manual synthesis, not a true merge).

## Part 1 — Replace the slow "prompt" Bash hook with a fast three-way pattern-match "command" hook

Current (`~/.claude/settings.json`):
```json
"PreToolUse": [{
  "matcher": "Bash",
  "hooks": [{ "type": "prompt", "prompt": "...block only if destructive...", "continueOnBlock": false }]
}]
```

Replace with a `"type": "command"` hook — a plain shell pattern-match (no model call, returns in milliseconds), using the documented `hookSpecificOutput.permissionDecision` field to explicitly pick one of three outcomes per command, rather than the old binary allow/block:

| Outcome | JSON emitted | When |
|---|---|---|
| **allow** — no prompt, no delay | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}` | Command matches a small, clearly-safe allowlist: `ls`, `cat`, `grep`/`rg`, `find` (non-`-delete`), `pwd`, `echo`, `head`/`tail`, `git status`/`log`/`diff`/`show`, `jq` (read), `wc`, `which`, `file`, `df`/`du` — read-only, no filesystem mutation, no `sudo`, no pipe-to-shell |
| **deny** — hard block | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}` | Wide, irreversible, catastrophic-scale patterns: `rm -rf` on `~`, `/Users/august`, or a glob spanning many files; `sudo chflags -R`/`sudo chmod -R` on home/system paths; `dot_clean`; `dd` targeting a raw disk device (`/dev/rdisk*`, `/dev/disk*`) |
| **ask** — normal permission prompt, same as if no hook existed | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}` (or simply exit 0 with no output, which falls through to the standard permission flow) | Everything else — every command not on the safe allowlist and not a catastrophic pattern, **including narrowly-scoped risky-looking commands** (e.g. `rm` on one named file, `sudo` on a single file, `chmod` on a specific path). These must never be silently auto-accepted. |

New hook script: `~/.claude/hooks/bash-safety-check.sh`
- Reads the tool-call JSON from stdin, extracts `.tool_input.command` via `jq`.
- Checks the safe-allowlist regex first → emits `allow` and exits.
- Checks the catastrophic-pattern regex next → emits `deny` with a reason and exits.
- Otherwise → emits `ask` (explicit, so this never silently degrades to auto-allow if `defaultMode` or another setting changes later) and exits 0.

`settings.json` changes to:
```json
"PreToolUse": [{
  "matcher": "Bash",
  "hooks": [{ "type": "command", "command": "~/.claude/hooks/bash-safety-check.sh" }]
}]
```

`defaultMode` stays `"plan"` — untouched, per the user's explicit preference.

## Part 2 — `session-status.sh`: survey + manage local and cloud-bridged sessions

New script: `~/.claude/scripts/session-status.sh` (chmod +x, run manually — not a hook, not scheduled).

**Data sources** (from research):
- `claude agents --json --all` — single source of truth for all interactive + background sessions, running and stopped. Fields: `kind` (background/interactive), `id`/`pid`, `sessionId`, `cwd`, `name`, `state`/`status`, `startedAt`.
- `~/.claude/jobs/<id>/state.json` — richer per-background-job status: `intent`, `resumeSessionId`, `children` (may include `claude.ai/code/artifact/...` links), and `bridgeSessionId`/`bridgeOwnerAccountUuid` — the **cloud link**. This is the only locally-visible signal of a cloud counterpart; there is no CLI subcommand to list cloud sessions directly (that requires the in-conversation `ListAgents` tool, not shell-scriptable). The script will surface `bridgeSessionId` as a `claude.ai/code/...` reference where present rather than claim a live cloud enumeration.
- `~/.claude/jobs/<id>/timeline.jsonl` — human-readable progress log, good for "what is this job doing" summaries.
- `~/.claude/projects/<sanitized-cwd>/<sessionId>.jsonl` — transcript. Pull the `{"type":"ai-title",...}` record for a title, and the last 1-2 `user`/`assistant` text turns for a one-line content summary.

**Output**: interactive menu.
1. Print a table: index, name/title, kind, state, age, cwd, cloud-linked (yes/no).
2. For each, a one-line auto-summary (from `ai-title` + last turn, or job `timeline.jsonl` for background jobs).
3. Prompt: pick a session by index, then choose an action:
   - **Resume** → `claude --resume <sessionId>` (interactive) or `claude attach <id>` (background)
   - **Stop** (keep transcript) → `claude stop <id>`
   - **Delete** (session + worktree) → `claude rm <id>`
   - **Export** → copy the `.jsonl` transcript to `~/Documents/ClaudeCode/session_reference/` (same pattern as prior manual exports already in that folder)
   - **Rename** → re-launch attach with `-n <name>` guidance (no in-place rename subcommand exists)
   - **Fork** → `claude --resume <sessionId> --fork-session` (new session ID, same history)
   - **View logs** (background only) → `claude logs <id>`
4. Print "No merge primitive exists" note when relevant, with the actual alternative: use `SendMessage`/`csd handoff` from within a live session to have one session summarize/pass context to another, or manually concatenate summaries — merging two transcripts into one session is not supported by the CLI.

**What sessions can be done with, beyond resume/delete** (documented as a comment block in the script + told to the user): stop-and-resume-later, rename, fork (branch off a copy), export transcript, view background job logs/timeline, and cross-session handoff via `SendMessage`/`csd` — but not merge.

## Files touched
- `~/.claude/settings.json` — swap the Bash `PreToolUse` hook from `prompt` to `command`.
- `~/.claude/hooks/bash-safety-check.sh` — new, pattern-match safety check.
- `~/.claude/scripts/session-status.sh` — new, interactive session survey/management script.

## Verification
- Feed the hook script sample stdin JSON directly (no real execution) for all three tiers and confirm the right `permissionDecision` comes back:
  - Safe commands (`ls`, `grep foo file`, `git status`) → `"allow"`
  - A narrowly-scoped risky command (e.g. `rm /Users/august/scratch/one-file.txt`) → `"ask"` (must NOT be `"allow"`)
  - A catastrophic wide pattern (e.g. `rm -rf ~/Desktop/*`, as a literal string fed to the hook — not actually executed) → `"deny"`
- Then run a couple of real safe commands (`ls`, `grep`) in a live session and confirm no perceptible delay/prompt, and one narrowly-scoped-but-not-safe command (e.g. `touch /tmp/x && rm /tmp/x`) and confirm it still prompts for approval as before.
- Run `~/.claude/scripts/session-status.sh` against the current live sessions (the two blocked background jobs `143c254c`/`4787c32c` and others already found) and confirm it lists them with correct summaries, and that choosing "delete" against `143c254c` actually runs `claude rm 143c254c` successfully.
