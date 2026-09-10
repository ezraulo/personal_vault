# Claude Code Session Respawn & Naming Behavior — Feature Request

**Submitted**: 2026-09-10 03:33 BST  
**User**: august (nctw9xwwm2@privaterelay.appleid.com)  
**Priority**: High (UX/accessibility issue)

---

## Problem Statement

Current session respawn behavior creates a confusing UX:

1. **Invisible respawns**: Background sessions respawn after being killed with no clear indication they're continuations of prior sessions
2. **Context loss**: Respawned sessions don't recover full conversation context — they're fresh processes with the same sessionId metadata
3. **Proliferation & clutter**: Users see many sessions in `ListAgents` that appear disparate but are actually incomplete fragments of the same logical work, leading to:
   - Duplicate-looking entries
   - Unclear which sessions are safe to close
   - Difficulty finding "the real" version of ongoing work
4. **Naming instability**: Session names auto-change mid-work, losing user's original naming intent
5. **No visual lineage tracking**: Users cannot quickly see which sessions share a `jobId` (logical work lineage) because there's no color-coding or status-line indication of jobId

**Accessibility impact**: For users with vision or color-recognition limitations, the lack of consistent, accessible jobId labeling makes session management extremely difficult.

---

## Requested Changes

### 1. Limit Respawn Behavior (20-turn threshold)

**Behavior**: Only respawn background sessions that have ≥20 turns of conversation history.

**Rationale**: 
- Sessions with <20 turns are typically exploratory, dud tests, or automation artifacts
- They clutter the UI and create confusion when respawned
- Real work sessions (20+ turns) are worth recovering; trivial sessions are not

**Implementation**:
```json
{
  "sessions": {
    "autoRespawnMinTurns": 20,
    "autoRespawnKinds": ["interactive"],
    "comment": "Only respawn interactive sessions with ≥20 conversation turns. Background sessions with <20 turns will terminate permanently on process death."
  }
}
```

### 2. Stable Session Naming (First-Name-Wins)

**Behavior**: 
- Session receives its name at creation (either auto-derived or user-assigned)
- That name persists for the lifetime of the logical session (across all respawns, resumes, etc.)
- Only the user can rename it afterward; subsequent respawns use the same name
- Respawned processes automatically inherit the source session's name

**Rationale**:
- Users expect names to be stable anchors for session identity
- Auto-renaming mid-work (as currently happens) breaks that mental model
- Each respawn should be transparent to naming — same name, same jobId

**Implementation**:
```json
{
  "sessions": {
    "nameStability": {
      "mode": "first-name-wins",
      "allowUserRename": true,
      "autoRenameDisabled": true,
      "respawnInheritsSourceName": true,
      "comment": "Session name is set once (at creation) and persists across all resumes/respawns. Only user can change it."
    }
  }
}
```

### 3. JobId in Status Line & Interface

**Behavior**:
- Every session display (terminal status line, `ListAgents`, session selector) shows the `jobId` in addition to `sessionId`
- jobId is prominently displayed (since it's the stable lineage identifier)

**Display format example**:
```
Shell: august-b7 [jobId: 0dd123b4] (sessionId: 8bb51762...) — idle
```

**Implementation**:
```json
{
  "statusLine": {
    "showJobId": true,
    "jobIdFormat": "[jobId: {jobId}]",
    "sessionIdAbbreviation": true,
    "abbreviationLength": 8,
    "comment": "Display jobId in status line for all session listings"
  },
  "ui": {
    "listAgentsShowJobId": true,
    "sessionSelectorShowJobId": true
  }
}
```

### 4. JobId Color/Style Theming (Accessibility-Friendly)

**Behavior**:
- Each unique `jobId` is assigned a consistent color and/or text-decoration style from a palette
- The same jobId always gets the same color, across all interfaces and sessions
- Sessions with different jobIds get visually distinct colors
- The palette uses **high-contrast, colorblind-safe colors** (not relying on red/green distinction alone)

**Rationale**:
- Users with color blindness or low vision need multiple visual cues, not just color
- Consistent color-to-jobId mapping makes it immediately obvious which sessions are part of the same work lineage
- Different jobIds must be visually distinguishable at a glance

**Implementation**:
```json
{
  "jobIdTheme": {
    "enabled": true,
    "mode": "color-and-style",
    "palette": [
      {
        "index": 0,
        "color": "#0173B2",
        "style": "normal",
        "highContrast": true,
        "colorblindSafe": true,
        "name": "Strong Blue"
      },
      {
        "index": 1,
        "color": "#DE8F05",
        "style": "bold",
        "highContrast": true,
        "colorblindSafe": true,
        "name": "Bold Orange"
      },
      {
        "index": 2,
        "color": "#CC78BC",
        "style": "italic",
        "highContrast": true,
        "colorblindSafe": true,
        "name": "Italic Purple"
      },
      {
        "index": 3,
        "color": "#029E73",
        "style": "underline",
        "highContrast": true,
        "colorblindSafe": true,
        "name": "Underlined Green"
      },
      {
        "index": 4,
        "color": "#D55E00",
        "style": "bold-underline",
        "highContrast": true,
        "colorblindSafe": true,
        "name": "Bold Underlined Red-Orange"
      },
      {
        "index": 5,
        "color": "#56B4E9",
        "style": "inverse",
        "highContrast": true,
        "colorblindSafe": true,
        "name": "Inverted Light Blue"
      }
    ],
    "cycleMode": "round-robin",
    "comment": "Color-blind safe palette from Paul Tol (https://personal.sron.nl/~pault/colourschemes.pdf). Each jobId gets unique color + text style."
  }
}
```

### 5. Respawn Transparency

**Behavior**:
- When a session respawns, the process shows a clear log message: `[Session respawn] jobId: {jobId}, name: {name}, prior sessionId: {old}, new sessionId: {new}`
- Status changes from "idle" to "respawning" briefly, then back to "idle"
- Users can see in the transcript that a respawn occurred

**Implementation**:
```json
{
  "sessions": {
    "respawnTransparency": {
      "logRespawnEvents": true,
      "respawnEventFormat": "[Session respawn] jobId: {jobId}, name: {name}, prior sessionId: {sessionId}, new pid: {pid}",
      "showRespawnInTranscript": true,
      "temporaryStatusOnRespawn": "respawning"
    }
  }
}
```

---

## Files to Create

1. **`~/.claude/settings-session-management.json`** — Core session behavior settings
2. **`~/.claude/settings-jobid-theme.json`** — JobId color/style theming
3. **`~/.claude/settings-status-line.json`** — Status line display configuration
4. **`FEATURE_REQUEST.md`** (for GitHub) — This document, as a GitHub issue/discussion starter

---

## Acceptance Criteria

- [ ] Sessions with <20 turns do not auto-respawn on process death
- [ ] Session names are stable from creation; no auto-rename after creation
- [ ] User can manually rename sessions; respawns inherit the name
- [ ] `ListAgents` and all session UIs show jobId prominently
- [ ] Every unique jobId has a consistent color + style across all interfaces
- [ ] Color palette is high-contrast and colorblind-safe (not red/green dependent)
- [ ] Respawn events are logged and visible in session transcript
- [ ] Status line includes jobId display with configurable format

---

## Accessibility Notes

This request addresses specific accessibility needs:
- **Low vision**: Multiple visual cues (color + text style + explicit labeling) needed, not color alone
- **Color blindness**: Paul Tol's colorblind-safe palette ensures distinction via hue, saturation, and lightness
- **Cognitive load**: Stable naming + clear jobId display reduces mental overhead of tracking "which session is which"

---

## Related Issues

- Session respawning without user action creates confusion
- Auto-renaming of sessions breaks user mental models
- No way to distinguish between different `jobId` lineages in UI
- Proliferation of incomplete session fragments in `ListAgents`

---

**Submitted by**: august  
**Date**: 2026-09-10  
**Status**: Awaiting implementation
