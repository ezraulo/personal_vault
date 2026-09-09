---
date: 2026-09-09
tags: [claude-code, launchd, zsh, maintenance]
source: Claude Code session
---

# precompact-archive cleanup: aliases + LaunchAgent

Companion to `precompact-archive-hook`. Since `~/.claude/precompact-archive/` isn't covered by
`cleanupPeriodDays`, it needs its own pruning. Two tiers: manual (aliases, run on demand) and
automatic (LaunchAgent, runs unattended). Aliases alone can't self-schedule — a shell alias only
runs when typed interactively — so true automation requires a `launchd` job (cron is deprecated
on macOS).

## Manual aliases — `~/.zshrc`

```
alias precompact-prune='find ~/.claude/precompact-archive -name "*.jsonl" -mtime +60 -delete'
alias precompact-autoclean='ls -t ~/.claude/precompact-archive/*.jsonl 2>/dev/null | tail -n +101 | xargs -I{} rm -- "{}"'
```

- `precompact-prune`: age-based, deletes anything older than 60 days.
- `precompact-autoclean`: count-based cap, keeps the most recent 100 archives regardless of age
  (age-based alone still lets the dir grow unbounded if many compactions happen inside 60 days).

## Automatic — LaunchAgent `com.august.precompact-cleanup`

Runs both cleanup rules once a day (9am) and once at load time.

`~/.claude/precompact-cleanup.sh`:
```bash
#!/bin/bash
find ~/.claude/precompact-archive -name "*.jsonl" -mtime +60 -delete
ls -t ~/.claude/precompact-archive/*.jsonl 2>/dev/null | tail -n +101 | xargs -I{} rm -- "{}"
```

`~/Library/LaunchAgents/com.august.precompact-cleanup.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.august.precompact-cleanup</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>/Users/august/.claude/precompact-cleanup.sh</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>9</integer>
		<key>Minute</key>
		<integer>0</integer>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/Users/august/.claude/precompact-cleanup.log</string>
	<key>StandardErrorPath</key>
	<string>/Users/august/.claude/precompact-cleanup.log</string>
</dict>
</plist>
```

Load / check status:
```
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.august.precompact-cleanup.plist   # NO sudo — per-user gui/<uid> domain
launchctl print gui/$(id -u)/com.august.precompact-cleanup | head -5
cat ~/.claude/precompact-cleanup.log
```

## Gotcha hit during setup: `com.apple.provenance` xattr blocks `launchctl bootstrap`

Files created by Claude Code's (sandboxed) Write tool carry a `com.apple.provenance` extended
attribute. `launchctl bootstrap` rejects plists/scripts carrying it with `Bootstrap failed: 5:
Input/output error` — and this reproduces with or without `sudo` (sudo is also wrong here
regardless, since a per-user `gui/<uid>` domain should never be loaded as root). The xattr can't
be stripped with `xattr -d` (fails, attribute persists). Fix: recreate both the `.sh` and
`.plist` files from an interactive Terminal session (`cat > file << 'EOF' ... EOF`) instead of
via Claude's tools — files written by the user's own shell process don't carry the tag.

Also: a "Bootstrap failed" message can be a stale/misleading false negative if an earlier failed
attempt already partially registered the label — check `launchctl print
gui/<uid>/<label>` for `runs = 1` / `last exit code = 0` to confirm it's actually working before
troubleshooting further.

## Verification

Confirmed via `launchctl print`: `runs = 1`, `last exit code = 0`,
`properties = runatload | inferred program`. First real `/compact` on 2026-09-09 created the
archive directory; LaunchAgent's daily 9am run will now find and prune it correctly going
forward.
