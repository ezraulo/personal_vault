#!/bin/bash
# Interactive session browser and manager for Claude Code
# Lists all sessions (local + background, running + stopped)
# Summarizes each one and offers actions: resume, stop, delete, export, rename, fork, view logs
# Does NOT offer merge (no such primitive exists in Claude Code CLI)

set -euo pipefail

# Helper: extract timestamp from milliseconds and format relative
format_age() {
  local ms="$1"
  local now_ms=$(date +%s)000
  local age_ms=$((now_ms - ms))
  local age_s=$((age_ms / 1000))

  if (( age_s < 60 )); then
    echo "${age_s}s ago"
  elif (( age_s < 3600 )); then
    echo "$((age_s / 60))m ago"
  elif (( age_s < 86400 )); then
    echo "$((age_s / 3600))h ago"
  else
    echo "$((age_s / 86400))d ago"
  fi
}

# Helper: get title from transcript
get_session_title() {
  local session_id="$1"
  local cwd="$2"

  # Sanitize cwd for path lookup (/ becomes -)
  local sanitized_cwd
  sanitized_cwd=$(printf '%s' "$cwd" | sed 's/^\//-/; s/\//-/g')

  local transcript_dir=~/.claude/projects/"$sanitized_cwd"
  local transcript_file="$transcript_dir/$session_id.jsonl"

  if [[ -f "$transcript_file" ]]; then
    # Extract ai-title record if present, otherwise use first 80 chars of last user message
    jq -r 'select(.type=="ai-title") | .aiTitle // empty' "$transcript_file" 2>/dev/null | head -1 || \
    jq -r 'select(.type=="user") | .message.content[0:80] // empty' "$transcript_file" 2>/dev/null | tail -1 || \
    echo "(untitled)"
  else
    echo "(untitled)"
  fi
}

# Helper: get status of background job
get_job_status() {
  local job_id="$1"
  local state_file=~/.claude/jobs/"$job_id"/state.json

  if [[ -f "$state_file" ]]; then
    jq -r '.state // "unknown"' "$state_file" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# Helper: get one-liner summary from transcript or timeline
get_session_summary() {
  local session_id="$1"
  local cwd="$2"
  local job_id="$3"  # optional, for background jobs

  # Sanitize cwd
  local sanitized_cwd
  sanitized_cwd=$(printf '%s' "$cwd" | sed 's/^\//-/; s/\//-/g')

  local transcript_dir=~/.claude/projects/"$sanitized_cwd"
  local transcript_file="$transcript_dir/$session_id.jsonl"

  if [[ -n "$job_id" ]]; then
    # For background jobs, try timeline first
    local timeline_file=~/.claude/jobs/"$job_id"/timeline.jsonl
    if [[ -f "$timeline_file" ]]; then
      tail -1 "$timeline_file" 2>/dev/null | jq -r '.text // .detail // .state' 2>/dev/null || true
      return 0
    fi
  fi

  if [[ -f "$transcript_file" ]]; then
    # Extract last user or assistant message (up to 60 chars)
    jq -r 'select(.type=="assistant" or .type=="user") | .message.content // empty | select(. != null) | gsub("\n"; " ") | .[0:60]' "$transcript_file" 2>/dev/null | tail -1 || true
  fi
}

# Main: fetch and display sessions
main() {
  echo ""
  echo "=== Claude Code Session Status ==="
  echo ""

  # Fetch all sessions (interactive + background, running + stopped)
  local sessions_json
  sessions_json=$(claude agents --json --all 2>/dev/null || echo "[]")

  local session_count
  session_count=$(printf '%s' "$sessions_json" | jq 'length' 2>/dev/null || echo 0)

  if (( session_count == 0 )); then
    echo "No sessions found."
    echo ""
    return
  fi

  echo "Found $session_count session(s):"
  echo ""

  # Print table header
  printf "%-2s %-35s %-12s %-10s %-15s %s\n" "#" "Name/Title (session ID)" "Kind" "State" "Age" "CWD"
  echo "================================================================================================================================"

  # Print each session
  local idx=0
  local -a session_ids=()
  local -a session_kinds=()

  printf '%s' "$sessions_json" | jq -r '.[] | @json' | while read -r session_json; do
    session=$(jq -r '.' <<< "$session_json")

    local id kind state status started_at session_id cwd name
    id=$(jq -r '.id // .pid // "?"' <<< "$session")
    kind=$(jq -r '.kind' <<< "$session")
    state=$(jq -r '.state // .status // "?"' <<< "$session")
    started_at=$(jq -r '.startedAt // 0' <<< "$session")
    session_id=$(jq -r '.sessionId' <<< "$session")
    cwd=$(jq -r '.cwd // "?"' <<< "$session")
    name=$(jq -r '.name // "?"' <<< "$session")

    # Get friendly age
    local age
    age=$(format_age "$started_at")

    # Get title/summary
    local title
    title=$(get_session_title "$session_id" "$cwd" || echo "$name")

    # Truncate cwd to last 15 chars for display
    local cwd_display
    cwd_display="${cwd: -15}"

    # Print row
    printf "%-2d %-35s %-12s %-10s %-15s %s\n" "$idx" "${title:0:35} ($session_id)" "$kind" "$state" "$age" "$cwd_display"

    # Store for later reference
    echo "$id:$session_id:$kind" >> /tmp/claude_sessions_list.$$

    ((idx++))
  done

  echo ""
  echo "Actions:"
  echo "  Enter a number (0-$((session_count - 1))) to manage that session, or Ctrl+C to quit"
  echo ""

  # Interactive loop
  while true; do
    read -p "Choose session [0-$((session_count - 1))]: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice >= session_count )); then
      echo "Invalid choice."
      continue
    fi

    # Get the session info
    local line
    line=$(sed -n "$((choice + 1))p" /tmp/claude_sessions_list.$$)
    local sid session_id kind
    IFS=: read -r sid session_id kind <<< "$line"

    show_session_menu "$sid" "$session_id" "$kind"
    break
  done

  # Cleanup
  rm -f /tmp/claude_sessions_list.$$
}

show_session_menu() {
  local sid="$1"
  local session_id="$2"
  local kind="$3"

  echo ""
  echo "=== Session: $session_id (ID: $sid, Kind: $kind) ==="
  echo ""
  echo "Actions:"
  echo "  1) Resume"
  echo "  2) Stop (keep transcript)"
  echo "  3) Delete (session + worktree)"
  echo "  4) Export transcript"
  echo "  5) Rename"
  echo "  6) Fork (branch off a copy)"
  if [[ "$kind" == "background" ]]; then
    echo "  7) View logs"
  fi
  echo "  0) Back"
  echo ""

  read -p "Choose action: " action

  case "$action" in
    1)
      if [[ "$kind" == "background" ]]; then
        echo "Resuming background session: claude attach $sid"
        claude attach "$sid"
      else
        echo "Resuming interactive session: claude --resume $session_id"
        claude --resume "$session_id"
      fi
      ;;
    2)
      echo "Stopping session: claude stop $sid"
      claude stop "$sid"
      echo "Session stopped (transcript preserved)."
      ;;
    3)
      read -p "Delete session $sid? Type 'yes' to confirm: " confirm
      if [[ "$confirm" == "yes" ]]; then
        echo "Deleting session: claude rm $sid"
        claude rm "$sid"
        echo "Session deleted."
      else
        echo "Cancelled."
      fi
      ;;
    4)
      mkdir -p ~/Documents/ClaudeCode/session_reference
      # Sanitize cwd for path lookup
      local sanitized_cwd
      sanitized_cwd=$(printf '%s' "$(pwd)" | sed 's/^\//-/; s/\//-/g')
      local transcript_file=~/.claude/projects/"$sanitized_cwd"/"$session_id".jsonl
      if [[ -f "$transcript_file" ]]; then
        local export_name
        export_name=$(date -u +%Y%m%dT%H%M%SZ)-"$session_id".jsonl
        cp "$transcript_file" ~/Documents/ClaudeCode/session_reference/"$export_name"
        echo "Transcript exported to: ~/Documents/ClaudeCode/session_reference/$export_name"
      else
        echo "Transcript file not found."
      fi
      ;;
    5)
      read -p "New session name: " newname
      if [[ -n "$newname" ]]; then
        echo "To rename, re-attach with: claude attach $sid -n '$newname'"
        echo "(Claude Code does not support direct rename; re-attaching with -n flag sets the name.)"
      fi
      ;;
    6)
      echo "To fork (branch off a copy), re-resume with: claude --resume $session_id --fork-session"
      echo "This creates a new session ID with the same conversation history."
      ;;
    7)
      if [[ "$kind" == "background" ]]; then
        echo "Logs for background session $sid:"
        echo ""
        claude logs "$sid"
      fi
      ;;
    0)
      echo "Returning to session list..."
      return
      ;;
    *)
      echo "Invalid choice."
      ;;
  esac

  echo ""
}

echo "╔════════════════════════════════════════════════════════════════════════════════════╗"
echo "║  Claude Code Session Manager                                                       ║"
echo "║                                                                                    ║"
echo "║  What can you do with sessions (beyond resume/delete)?                             ║"
echo "║  • Stop and resume later (preserves transcript)                                    ║"
echo "║  • Rename via re-attach (-n flag)                                                 ║"
echo "║  • Fork/branch off a copy (--fork-session)                                         ║"
echo "║  • Export transcript to a file                                                    ║"
echo "║  • View background job logs and progress                                          ║"
echo "║  • Cross-session handoff via SendMessage (manually synthesize context)             ║"
echo "║                                                                                    ║"
echo "║  NOTE: Merging two sessions is NOT supported (no merge primitive in CLI).          ║"
echo "║  Use handoff or manual concatenation of summaries instead.                         ║"
echo "╚════════════════════════════════════════════════════════════════════════════════════╝"
echo ""

main
