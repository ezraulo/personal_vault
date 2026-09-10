---
date: 2026-09-10
tags: [claude-code, settings, maintenance, recommendations]
source: Claude Code /doctor health check
---

# Claude Code Doctor Recommendations — 2026-09-10

## Scan Summary
- **Installation:** Homebrew (`claude-code` cask, stable channel) — clean, no duplicates or leftovers
- **Settings:** All JSON files parse correctly; no corruption
- **Version:** 2.1.236 (up to date with stable channel)
- **Plugins:** 57 total (44 inline, 13 marketplace); 9 enabled; 48 with zero usage (never invoked)
- **Skills:** 10 registered; 2 actively used in transcripts (`update-config`, `stash`); 8 unused
- **MCP Servers:** 1 user-scope (`mcp-bundler`); no project-scope servers
- **Scan window:** 5 sessions over ~5 days (2026-09-05 to 2026-09-10)

## Top Recommendations

### 1. Switch to Auto Mode as Default (HIGH PRIORITY)
**Current:** `permissions.defaultMode: "plan"`  
**Recommended:** `permissions.defaultMode: "auto"`

**Why:** Auto mode uses a safety classifier to approve routine read-only and safe actions, eliminating repetitive permission prompts for every tool call. Plan mode requires manual per-action approval and is better for high-stakes work; auto is fine for general development.

**Benefit:** Fewer interruptions, faster workflow  
**Reversibility:** One-line setting; revert anytime  
**Action:** Add to `~/.claude/settings.json`:
```json
{
  "permissions": {
    "defaultMode": "auto"
  }
}
```

### 2. Disable Unused Inline Plugins (OPTIONAL CLEANUP)
44 inline plugins with zero usage (all seeded at install/enable, never invoked). They cost ~500-700 est. resident tokens per session despite having no signal this machine uses them.

**Recommended action:** Disable all 44 inline plugins; they add no value.

**Affected plugins:** `claude-tag-data-viz@inline`, `bigquery@inline`, `brightdata-plugin@inline`, `healthcare@inline`, `pdf-viewer@inline`, `legal@inline`, `ip-legal@inline`, `ai-governance-legal@inline`, `legal-clinic@inline`, `productivity@inline`, `cowork-plugin-management@inline`, `claude-tag-troubleshoot@inline`, `privacy-legal@inline`, `auth0@inline`, `fastly-agent-toolkit@inline`, `operations@inline`, `sp-global@inline`, `product-management@inline`, `nimble@inline`, `bio-research@inline`, `investment-banking@inline`, `commercial-legal@inline`, `product-legal@inline`, `engineering@inline`, `modern-web-guidance@inline`, `google-drive@inline`, `litigation-legal@inline`, `finance@inline`, `regulatory-legal@inline`, `browser-use@inline`, `employment-legal@inline`, `legal-builder-hub@inline`, `enterprise-search@inline`, `claude-for-msft-365-install@inline`, `box@inline`, `desktop-commander@inline`, `law-student@inline`, `dropbox@inline`, `langfuse@inline`, `data@inline`, `lseg@inline`, `corporate-legal@inline`, `learn-with-coursera@inline`, `anthropic-skills@inline`.

**Reversibility:** Can re-enable all via `/plugin enable <name>@inline` or `settings.json` edits.

### 3. Disable Unused Marketplace Plugins (MINOR)
**Unused marketplace plugins:** `agent-sdk-dev@claude-plugins-official`, `mcp-server-dev@claude-plugins-official`, `ralph-loop@claude-plugins-official`, `claude-code-setup@claude-plugins-official`, `claude-md-management@claude-plugins-official`, `notebooklm@roomi-fields`, `notebooklm-skill@roomi-fields`, `frontend-design@claude-plugins-official` — all zero usage in window.

**Already disabled in settings:** Most are already set to `false`. Those still enabled (`true`):
- `claude-md-management@claude-plugins-official` — 0 uses
- `claude-code-setup@claude-plugins-official` — 0 uses
- `notebooklm@roomi-fields` — 1 use (2026-09-04, over a month ago)

Disable these three for consistency.

### 4. Disable Unused Skills (MINOR)
8 of 10 registered skills unused in window: `artifact-design`, `doctor`, `init`, `notebooklm:notebooklm`, `plugin-dev:command-development`, `statusline`, `superpowers-lab:mcp-cli`. Used skills: `stash`, `update-config`.

Keep the unused ones — they're low-cost and useful for ad-hoc tasks. No action needed.

## What NOT to Change
- **mcp-bundler:** User-scope MCP server with zero transcript invocations but likely used for project-specific tasks; keep.
- **CLAUDE.md:** Lean and appropriate (not project-specific); addresses the 2026-09-04 incident context and home-folder setup. No trim needed.
- **Hooks:** Both PreToolUse and PreCompact hooks are recent additions from the hardening session (2026-09-09); working as designed; no issue found.
- **Transcripts:** 40 startups across 5 sessions; normal cleanup via `cleanupPeriodDays` (default 30) is already happening.

## Installation Health
✓ Homebrew cask install (`claude-code`), no npm leftovers  
✓ PATH includes `/opt/homebrew/bin`  
✓ Version current (stable channel)  
✓ No malformed settings or manifests  
✓ LaunchAgent (`com.august.precompact-cleanup`) loaded and working

## Summary
The installation is clean. Primary recommendation is **Switch to Auto Mode** (high impact, zero risk). Optional cleanup: disable 44 unused inline plugins (saves ~500-700 est. tokens/session; reversible). Everything else is working as intended.

---
**Files for reference:** See `~/Documents/ClaudeCode/session_reference/Claude-Code-Hardening-2026-09-04-to-09-10/` for full session export, config snapshots, and scripts.
