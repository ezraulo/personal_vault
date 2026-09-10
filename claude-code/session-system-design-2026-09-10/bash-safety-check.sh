#!/bin/bash
# Bash safety hook for Claude Code PreToolUse
# Emits permissionDecision ("allow", "ask", or "deny") to decide whether a Bash command needs approval
# Three tiers: clearly-safe read-only → auto-allow (no prompt)
#             everything else → ask (normal permission prompt)
#             catastrophic wide patterns → hard deny

set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract command safely
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$cmd" ]]; then
  # No command found, fall through to ask
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask"}}'
  exit 0
fi

# ============================================================================
# TIER 1: Clearly-safe read-only commands — auto-allow, no prompt
# ============================================================================

# Simple allowlist: commands that are read-only and cannot mutate state
safe_simple=0
case "$cmd" in
  ls*|cat*|grep*|rg*|pwd|echo*|head*|tail*|wc*|which*|file*|df*|du*|uname*|id|whoami|date|env|printenv|lsof*|jq*)
    safe_simple=1
    ;;
  git\ status*|git\ log*|git\ diff*|git\ show*)
    safe_simple=1
    ;;
esac

# Pattern check for find (without -delete), and other safe uses
if [[ $safe_simple -eq 0 ]]; then
  # Allow find but only without -delete
  if [[ "$cmd" =~ ^find[[:space:]] ]] && ! [[ "$cmd" =~ -delete ]]; then
    safe_simple=1
  fi
fi

if [[ $safe_simple -eq 1 ]]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow"}}'
  exit 0
fi

# ============================================================================
# TIER 2: Catastrophic wide-destructive patterns — hard deny, no prompt
# ============================================================================

# Pattern 1: rm -rf on home dir, /Users/august, or any glob star pattern
if [[ "$cmd" =~ rm[[:space:]]+-.*rf.*(~|/Users/august|\*) ]] || [[ "$cmd" =~ rm[[:space:]]+.*(~|-rf|-fr).*/Users/august ]]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Destructive rm -rf on home directory or wide glob — blocked"}}'
  exit 0
fi

# Pattern 2: sudo chflags -R or sudo chmod -R on sensitive paths
if [[ "$cmd" =~ sudo[[:space:]]+(chflags|chmod)[[:space:]]+-R ]] && [[ "$cmd" =~ (~|/Users/august|/Users|/System|/) ]]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Destructive sudo chmod/chflags -R on sensitive paths — blocked"}}'
  exit 0
fi

# Pattern 3: dot_clean (clears DS_Store, metadata)
if [[ "$cmd" =~ dot_clean ]]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Destructive dot_clean operation — blocked"}}'
  exit 0
fi

# Pattern 4: dd targeting raw disk devices
if [[ "$cmd" =~ dd.*(/dev/rdisk|/dev/disk[^a-zA-Z_]) ]] || [[ "$cmd" =~ of=/dev/(rdisk|disk[^a-zA-Z_]) ]]; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Destructive dd to raw disk device — blocked"}}'
  exit 0
fi

# ============================================================================
# TIER 3: Everything else — ask for explicit approval (normal permission flow)
# ============================================================================
# This includes narrowly-scoped but risky commands like "rm /path/to/one-file"
# They must not be auto-accepted; user must explicitly approve them.

jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask"}}'
exit 0
