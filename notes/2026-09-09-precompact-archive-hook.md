---
date: 2026-09-09
tags: [claude-code, hooks, settings, backup]
source: Claude Code session
---

# PreCompact transcript-archive hook

A `PreCompact` hook in global `~/.claude/settings.json`, added after the 2026-09-04
home-folder-loss incident (see `home-folder-loss-2026-09-04` memory /
`~/personal_vault/home-recovery`). Goal: never rely on remembering to manually export
something "before something risky" — that judgment-based trigger is exactly the failure mode
that caused the original incident. Instead, archive automatically on a deterministic event
(every compaction, auto or manual) with zero judgment involved.

Rejected alternatives considered first:
- A full Bash-command audit-log hook — wouldn't have caught the original incident (that was
  manual Terminal use, not a Claude Code session), partly redundant with existing session
  transcripts, and risks logging plaintext secrets.
- A "manual export before something risky" skill — requires the same judgment call that failed
  last time; no reliable way to define "risky" in advance.

## What it does

Before any compaction, copies the current session's live transcript
(`~/.claude/projects/<project>/<session_id>.jsonl`) into a dedicated archive directory, named
with a UTC timestamp so multiple compactions of the same session don't collide.

```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.session_id' | { read -r sid; f=$(find ~/.claude/projects -maxdepth 2 -name \"${sid}.jsonl\" 2>/dev/null | head -1); if [ -n \"$f\" ]; then mkdir -p ~/.claude/precompact-archive; cp \"$f\" ~/.claude/precompact-archive/\"$(date -u +%Y%m%dT%H%M%SZ)-${sid}.jsonl\"; fi; } 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

## Where archives live / how to check for bloat

`~/.claude/precompact-archive/*.jsonl` — one file per compaction event. **Not** covered by
Claude Code's `cleanupPeriodDays` (that only prunes `~/.claude/projects/`), so it grows
unbounded unless pruned. Check size/count periodically:

```
du -sh ~/.claude/precompact-archive
ls ~/.claude/precompact-archive | wc -l
```

## Cleanup

Two layers, see `precompact-cleanup-automation` note for full detail:
- Manual `.zshrc` aliases (`precompact-prune`, `precompact-autoclean`) for on-demand pruning.
- A `launchd` LaunchAgent (`com.august.precompact-cleanup`) that runs the same logic
  automatically once a day.

## Verification

First real end-to-end test: ran `/compact` on 2026-09-09, confirmed
`~/.claude/precompact-archive/20260909T121251Z-<session_id>.jsonl` was created (1.4MB, `-rw-------`
permissions), matching the session that was compacting. Hook confirmed working.

## Notes

- Global scope, applies to every session, no manual invocation needed.
- Settings-file changes aren't picked up mid-session unless the directory was already watched
  at session start — open `/hooks` once (or restart) to force a reload.
- Review/edit/disable via the `/hooks` command.
