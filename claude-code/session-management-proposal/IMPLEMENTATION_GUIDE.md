# Session Respawn & Naming — Implementation Guide

**Date**: 2026-09-10  
**Status**: Feature request with implementation notes

---

## Which Features Require Code Changes vs. Hooks

### Require Claude Code Core Changes ❌ (hooks won't work)
1. **Auto-respawn threshold (20 turns)**: Requires session daemon to check turn count before respawning
2. **Lock session names after creation**: Requires session registry to enforce immutability
3. **JobId display in status line/UI**: Requires frontend changes across all session displays
4. **JobId color theming in UI**: Requires frontend color/style rendering
5. **Respawn process inheritance of name**: Requires session spawning logic changes

### Can Be Partially Implemented with Hooks ✅

#### Hook Approach 1: Name Stability via PostSessionRespawn Hook
```json
{
  "PostSessionRespawn": [
    {
      "matcher": "global",
      "hooks": [
        {
          "type": "prompt",
          "description": "Force respawned session to use original name",
          "prompt": "This session just respawned. The original name was '{originalName}'. Reset the session name to '{originalName}' to maintain naming consistency.",
          "action": "rename-session",
          "newName": "{originalName}"
        }
      ]
    }
  ]
}
```

**Limitation**: Can only enforce naming AFTER respawn occurs; doesn't prevent auto-rename during respawn.

#### Hook Approach 2: Respawn Logging via PreToolUse
```json
{
  "PostSessionRespawn": [
    {
      "matcher": "global",
      "hooks": [
        {
          "type": "log",
          "description": "Log respawn events for transparency",
          "logFormat": "[Session respawn] jobId: {jobId}, name: '{name}', sessionId: {sessionId:short}, pid: {pid}",
          "writeToTranscript": true
        }
      ]
    }
  ]
}
```

**Limitation**: Logs the event but doesn't prevent respawn of trivial sessions.

#### Hook Approach 3: Session Lifecycle Monitoring
```json
{
  "PreSessionStart": [
    {
      "matcher": "background",
      "hooks": [
        {
          "type": "prompt",
          "description": "Block respawn of background sessions with <20 turns",
          "prompt": "This background session is respawning with only {turnCount} turns of history. {turnCount < 20 ? 'Block respawn (session will terminate)' : 'Allow respawn'}",
          "blockOnCondition": "turnCount < 20",
          "action": "exit-without-prompt"
        }
      ]
    }
  ]
}
```

**Limitation**: Exiting immediately blocks work, but doesn't cleanly prevent registration.

---

## Hybrid Approach: Hooks + Settings + Code Changes

### What We Can Do Now (Hooks + Config)
1. ✅ Name stability enforcement (via PostSessionRespawn hook that renames back)
2. ✅ Respawn event logging (via hooks)
3. ✅ Manual session cleanup (users can delete registry entries as we did)

### What Needs Claude Code Updates
1. ❌ Auto-respawn threshold (20 turns) — requires daemon logic
2. ❌ Prevent auto-rename — requires session creation/naming logic
3. ❌ JobId in status line — requires UI changes
4. ❌ JobId color theming — requires UI rendering changes

### Recommended Path Forward

**Phase 1 (Immediate, hooks-based)**:
- Implement `PostSessionRespawn` hook to rename sessions back to original
- Add `PreSessionStart` hook to log respawn attempts
- Document manual cleanup process

**Phase 2 (Settings-based, no code changes)**:
- Add settings that store "original session name" and "jobId color mapping"
- Scripts read these settings to provide visual feedback (could integrate with status-line scripts)

**Phase 3 (Claude Code updates)**:
- Implement respawn threshold (20 turns)
- Prevent auto-rename after first naming
- Add jobId to status line display
- Implement color theming in UI

---

## Settings Files (Phase 2)

The three JSON files provided in this request define the **desired state** — the settings Claude Code **should** support. They can be:
1. Placed in `~/.claude/` now as documentation/wishlist
2. Used to configure hook-based workarounds
3. Picked up by Claude Code once core features are implemented

### If Implementing Hooks Today:

Create `~/.claude/settings.local.json`:
```json
{
  "sessionNameLocking": {
    "originalNames": {
      "0dd123b4-56ed-42d4-8476-d8f047273e7a": "shell-aliases-precompact-cleanup",
      "143c254c-6ec4-4175-8273-0e70a960c83f": "mcp-plugins-config",
      "8bb51762-2ecf-4d34-85ef-c7d67146d397": "icloud-webdav-recovery"
    },
    "lockAfterCreation": true,
    "comment": "Manually maintained mapping of sessionId → original name for hook-based enforcement"
  },
  "jobIdTheme": {
    "colorMap": {
      "0dd123b4": {"color": "#0173B2", "style": "normal"},
      "143c254c": {"color": "#DE8F05", "style": "bold"},
      "8bb51762": {"color": "#CC78BC", "style": "italic"}
    },
    "comment": "Manual color assignment for known jobIds"
  }
}
```

---

## Recommendation

**Start with hooks** for name stability and logging, while these feature-request settings documents are submitted to Anthropic for core implementation.
