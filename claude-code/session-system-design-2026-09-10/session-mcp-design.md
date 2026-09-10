# Session Management MCP Server Design

**Status**: Design phase (ready for implementation)  
**Date**: 2026-09-10  
**Scope**: Unified session metadata, health monitoring, duplicate detection, context injection

---

## Overview

A local MCP (Model Context Protocol) server that becomes the **single source of truth** for session management. Claude (in any session) can query it for:
- Session metadata (purpose, tags, relationships)
- Health status (stale, blocked, duplicate)
- Context injection (other active sessions, guidance)
- Duplicate detection (prevent accidental work duplication)
- Cleanup recommendations (what to delete/archive)

**Why MCP vs. shell scripts + JSON**:
- Single unified interface (not scattered CLI tools)
- Queryable (Claude asks questions, gets answers)
- Extensible (add new capabilities without new scripts)
- Transparent (Claude sees what it's doing)
- Future-proof (if Claude Code adds MCP session support, already integrated)

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Claude (any session)                                    │
│  Tools: list_sessions, get_context, create_session,     │
│         check_duplicates, tag_session, cleanup, etc.     │
└────────────────────┬─────────────────────────────────────┘
                     │ JSON-RPC 2.0
                     ▼
┌──────────────────────────────────────────────────────────┐
│  Session Management MCP Server (stdio)                   │
│                                                          │
│  ┌─ Core Logic ───────────────────────────────────────┐ │
│  │ • Metadata registry (CRUD)                         │ │
│  │ • Health checker (stale, blocked, orphaned)        │ │
│  │ • Duplicate detector (by purpose, tags, content)   │ │
│  │ • Context injector (generate session guidance)     │ │
│  │ • Tag manager (create, apply, filter)              │ │
│  │ • Cleanup automation (archive, suggest delete)     │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─ Storage Layer ─────────────────────────────────────┐ │
│  │ SQLite DB: ~/.claude/session-mcp.db                 │ │
│  │ • sessions table                                    │ │
│  │ • tags table                                        │ │
│  │ • activity_log table                                │ │
│  │ • duplicates table                                  │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                     │
                     ▼
    ~/.claude/session-mcp.db (SQLite)
    ~/.claude/session-mcp.log (activity log)
```

---

## Tools (MCP Interface)

### **Core Queries**

#### 1. `list_sessions`
**Purpose**: Get all sessions with metadata + health status

**Input**:
```json
{
  "filter": {
    "tags": ["active"],
    "state": "running",
    "cwd": "/Users/august"
  },
  "include_health": true
}
```

**Output**:
```json
{
  "sessions": [
    {
      "sessionId": "11f77a2b-...",
      "name": "prompt-zesty-pretzel",
      "purpose": "Session hygiene + MCP design",
      "tags": ["infrastructure", "active"],
      "kind": "interactive",
      "state": "running",
      "createdAt": "2026-09-10T12:00:00Z",
      "lastActiveAt": "2026-09-10T13:00:00Z",
      "ageHours": 1,
      "health": {
        "status": "healthy",
        "isDuplicate": false,
        "isStale": false,
        "isBlocked": false,
        "recommendation": null
      }
    }
  ]
}
```

#### 2. `get_session_context`
**Purpose**: Get guidance for Claude about its own session context

**Input**:
```json
{
  "sessionId": "11f77a2b-...",
  "include_related": true
}
```

**Output**:
```json
{
  "context": {
    "sessionName": "prompt-zesty-pretzel",
    "purpose": "Session hygiene + MCP design",
    "tags": ["infrastructure", "active"],
    "guidance": "You are in the main work session. Avoid spawning new background jobs unless explicitly asked. Check for related sessions before suggesting multi-session workflows.",
    "relatedSessions": [
      {
        "sessionId": "143c254c-...",
        "name": "mcp-plugins-config",
        "relationship": "blocked-cleanup-candidate",
        "note": "Background job stuck 72+ hours — marked for deletion"
      }
    ]
  }
}
```

#### 3. `check_duplicates`
**Purpose**: Detect sessions doing similar work

**Input**:
```json
{
  "sessionId": "11f77a2b-...",
  "sensitivity": "high"
}
```

**Output**:
```json
{
  "isDuplicate": false,
  "potentialDuplicates": [
    {
      "sessionId": "abe1758a-...",
      "name": "check-router-admin-login",
      "similarity": 0.45,
      "reason": "Both involve network exploration, but different scopes"
    }
  ],
  "recommendation": null
}
```

#### 4. `get_health_report`
**Purpose**: Full health scan of all sessions

**Input**:
```json
{
  "include_stale": true,
  "staleThresholdHours": 24
}
```

**Output**:
```json
{
  "report": {
    "timestamp": "2026-09-10T13:00:00Z",
    "totalSessions": 5,
    "healthy": 2,
    "issues": [
      {
        "sessionId": "143c254c-...",
        "issue": "blocked",
        "hoursStuck": 72,
        "recommendation": "delete",
        "reasoning": "Background job blocked for 72+ hours, no progress"
      }
    ]
  }
}
```

---

### **Write Operations**

#### 5. `create_session_metadata`
**Purpose**: Register a new session (called on session start)

**Input**:
```json
{
  "sessionId": "11f77a2b-...",
  "name": "prompt-zesty-pretzel",
  "purpose": "Session hygiene + Bash hook refactor",
  "tags": ["infrastructure", "active"],
  "kind": "interactive",
  "cwd": "/Users/august"
}
```

#### 6. `tag_session`
**Purpose**: Add/remove tags

**Input**:
```json
{
  "sessionId": "11f77a2b-...",
  "action": "add",
  "tags": ["testing-ready"]
}
```

#### 7. `mark_duplicate`
**Purpose**: Mark sessions as duplicates of each other

**Input**:
```json
{
  "sessionId": "143c254c-...",
  "duplicateOf": "4787c32c-...",
  "reason": "Both MCP plugin setup, same goal"
}
```

#### 8. `update_health_status`
**Purpose**: Manually set health flags (or auto-called by monitoring)

**Input**:
```json
{
  "sessionId": "143c254c-...",
  "isBlocked": true,
  "hoursBlocked": 72,
  "recommendation": "delete"
}
```

#### 9. `cleanup_suggestion`
**Purpose**: Get and act on cleanup recommendations

**Input**:
```json
{
  "action": "list_candidates"
}
```

**Output**:
```json
{
  "candidates": [
    {
      "sessionId": "143c254c-...",
      "action": "delete",
      "reason": "Blocked 72+ hours, duplicative"
    }
  ]
}
```

---

## Database Schema (SQLite)

```sql
-- Sessions table
CREATE TABLE sessions (
  sessionId TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  purpose TEXT,
  kind TEXT,  -- 'interactive' | 'background'
  state TEXT, -- 'running' | 'stopped' | 'idle'
  cwd TEXT,
  createdAt TIMESTAMP,
  lastActiveAt TIMESTAMP,
  isDuplicate BOOLEAN DEFAULT 0,
  duplicateOf TEXT,
  isArchived BOOLEAN DEFAULT 0,
  health_status TEXT, -- 'healthy' | 'stale' | 'blocked' | 'orphaned'
  health_recommendation TEXT
);

-- Tags table
CREATE TABLE tags (
  id INTEGER PRIMARY KEY,
  sessionId TEXT,
  tag TEXT,
  createdAt TIMESTAMP,
  FOREIGN KEY (sessionId) REFERENCES sessions(sessionId)
);

-- Activity log
CREATE TABLE activity_log (
  id INTEGER PRIMARY KEY,
  sessionId TEXT,
  event TEXT, -- 'created' | 'updated' | 'marked_duplicate' | 'archived'
  detail TEXT,
  timestamp TIMESTAMP,
  FOREIGN KEY (sessionId) REFERENCES sessions(sessionId)
);

-- Relationships (for future: parent-child, related, etc.)
CREATE TABLE relationships (
  fromSessionId TEXT,
  toSessionId TEXT,
  relationType TEXT, -- 'parent' | 'related' | 'duplicate_of'
  createdAt TIMESTAMP,
  PRIMARY KEY (fromSessionId, toSessionId)
);
```

---

## Implementation Phases

### **Phase 1: Core Server + Storage** (2-3 hours)
- [x] Design (this document)
- [ ] Implement MCP server skeleton (stdio transport)
- [ ] SQLite schema + initialization
- [ ] Tools 1-4 (query operations)

### **Phase 2: Write Operations** (1-2 hours)
- [ ] Tools 5-9 (create, tag, mark_duplicate, update, cleanup)
- [ ] Validation + error handling
- [ ] Activity logging

### **Phase 3: Integration** (1-2 hours)
- [ ] Auto-call `create_session_metadata` on session start (via hook)
- [ ] Auto-call `update_health_status` periodically (via cron)
- [ ] Claude learns to query it (provide MCP config to ~/.claude/settings.json)

### **Phase 4: UI/CLI** (1 hour, optional)
- [ ] `claude-mcp-query` CLI for manual queries
- [ ] Integration with `session-status.sh` (fetch data from MCP instead of JSON files)

---

## Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Server | Python 3.11+ | Fast iteration, async support, sqlite3 stdlib |
| Protocol | MCP (stdio) | Standard, Claude Code compatible |
| Storage | SQLite | Local, persistent, queryable, zero setup |
| Logging | Python logging | Simple, rotatable |
| Process management | systemd user service (optional) | Auto-restart on crash, managed lifecycle |

---

## How Claude Uses It

**Example 1: Session Start**
```
Claude loads this session
↓
Reads CLAUDE.md charter
↓
Calls MCP: get_session_context(sessionId)
↓
Learns: "You're in prompt-zesty-pretzel (infrastructure, active). Avoid spawning unless asked."
↓
Operates with context awareness
```

**Example 2: Considering New Background Job**
```
User asks: "Run a background test suite"
Claude thinks: "Should I spawn a new background session?"
↓
Calls MCP: check_duplicates(sessionId), list_sessions(tags=["testing"])
↓
Learns: "Session abe1758a already tests. Consider consolidating."
↓
Responds: "We already have a testing session running. Should I run the suite there instead?"
```

**Example 3: End-of-Session Cleanup**
```
Claude finishes work
↓
Calls MCP: get_health_report()
↓
Learns: "Sessions 143c254c and 4787c32c are blocked cleanup candidates"
↓
Suggests to user: "Before you go, 2 blocked sessions are marked for deletion. Want me to clean them?"
```

---

## Success Metrics

- ✅ Claude can query session metadata from MCP
- ✅ Duplicate detection catches overlapping work
- ✅ Health monitoring alerts to stale/blocked sessions
- ✅ Context injection makes Claude aware of cross-session state
- ✅ Activity log tracks all session lifecycle events
- ✅ Zero manual maintenance (auto-updates via hooks)

---

## Next Steps

1. Implement MCP server (Python)
2. Test tools 1-4 (queries)
3. Integrate with Claude via ~/.claude/settings.json
4. Add write operations (tools 5-9)
5. Auto-call from hooks (session start, health monitoring)

---

**Owned by**: This design is in the ringfenced vault folder. Modify only if explicitly asked.
