#!/bin/bash
# Claude Code status line: model, context window usage, rate limits, session cost.
# Receives the session JSON payload on stdin.

input=$(cat)

# --- helpers ---------------------------------------------------------------

# Color a percentage: green under 60, yellow under 85, red at/above 85.
pct_color() {
  local p=$1
  if   [ "$p" -ge 85 ]; then printf '\033[1;31m'   # red
  elif [ "$p" -ge 60 ]; then printf '\033[1;33m'   # yellow
  else                        printf '\033[1;32m'  # green
  fi
}

# 141727 -> 142k ; 1000000 -> 1.0M
human_tokens() {
  local n=$1
  if   [ "$n" -ge 1000000 ]; then awk -v n="$n" 'BEGIN{printf "%.1fM", n/1000000}'
  elif [ "$n" -ge 1000    ]; then awk -v n="$n" 'BEGIN{printf "%dk",   n/1000}'
  else printf '%d' "$n"
  fi
}

# seconds -> "2h13m" / "3d4h" / "47m"
human_eta() {
  local s=$1
  [ "$s" -le 0 ] && { printf 'now'; return; }
  if   [ "$s" -ge 86400 ]; then printf '%dd%dh' $((s/86400)) $(((s%86400)/3600))
  elif [ "$s" -ge 3600  ]; then printf '%dh%dm' $((s/3600))  $(((s%3600)/60))
  else printf '%dm' $((s/60))
  fi
}

R='\033[0m'   # reset
D='\033[2m'   # dim

# --- extract ---------------------------------------------------------------

# Tab-separated: the model display name contains spaces, so IFS must be a tab only.
IFS=$'\t' read -r model effort ctx_pct ctx_used ctx_size fh_pct fh_reset sd_pct sd_reset cost <<<"$(
  echo "$input" | jq -r '[
    (.model.display_name // "?"),
    (.effort.level // "-"),
    (.context_window.used_percentage // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.context_window_size // 0),
    (.rate_limits.five_hour.used_percentage // -1),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1),
    (.rate_limits.seven_day.resets_at // 0),
    (.cost.total_cost_usd // 0)
  ] | @tsv'
)"

now=$(date +%s)
sep="${D} │ ${R}"

# --- render ----------------------------------------------------------------

out="\033[1;36m${model}${R}${D} ${effort}${R}"

# context window
out="${out}${sep}ctx $(pct_color "$ctx_pct")${ctx_pct}%${R}${D} ($(human_tokens "$ctx_used")/$(human_tokens "$ctx_size"))${R}"

# 5-hour limit
if [ "$fh_pct" -ge 0 ]; then
  out="${out}${sep}5h $(pct_color "$fh_pct")${fh_pct}%${R}"
  [ "$fh_reset" -gt 0 ] && out="${out}${D} ↻$(human_eta $((fh_reset - now)))${R}"
fi

# 7-day limit
if [ "$sd_pct" -ge 0 ]; then
  out="${out}${sep}7d $(pct_color "$sd_pct")${sd_pct}%${R}"
  [ "$sd_reset" -gt 0 ] && out="${out}${D} ↻$(human_eta $((sd_reset - now)))${R}"
fi

# session cost
out="${out}${sep}${D}\$$(printf '%.2f' "$cost")${R}"

printf '%b' "$out"
