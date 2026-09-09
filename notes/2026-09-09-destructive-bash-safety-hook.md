---
date: 2026-09-09
tags: [claude-code, hooks, settings, safety]
source: Claude Code session
---

# Destructive-Bash-command safety hook

A `PreToolUse` hook on `Bash` in global `~/.claude/settings.json`, added after the
2026-09-04 home-folder-loss incident (a `sudo chmod`/`chflags`/`dot_clean` cleanup session
emptied `/Users/august` — see the `home-folder-loss-2026-09-04` memory / `~/personal_vault/home-recovery`).

It runs a quick LLM check before any Bash command executes and blocks it only if it looks like
a broad, irreversible destructive filesystem operation (recursive `rm`, `sudo chflags -R` /
`chmod -R` over home or system paths, `dot_clean`, `dd` to a device, etc.). Narrow, normal
commands pass through untouched. This is independent of whatever permission mode
(`plan`/`acceptEdits`/etc.) is active — a defense-in-depth layer specifically against that
class of command.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "A shell command is about to run in the user's home directory (not inside a project repo). Block it ONLY if it is a broad, irreversible, destructive filesystem operation — e.g. `rm -rf` on a wide path (~, /Users/august, or a wildcard spanning many files), `sudo chflags -R` / `sudo chmod -R` applied broadly to the home folder or system paths, `dot_clean`, `dd` targeting a disk device, or anything else capable of wiping a large amount of user data in one shot. Allow everything else, including narrow deletes of specific known files. Command: $ARGUMENTS",
            "continueOnBlock": false
          }
        ]
      }
    ]
  }
}
```

## Notes

- Global scope (`~/.claude/settings.json`), not project-scoped — applies to every session.
- `prompt`-type hooks cost a small model call per Bash command; a cheaper but cruder
  alternative is a plain regex `command` hook matching known-dangerous patterns.
- Settings-file changes aren't picked up mid-session unless the directory was already
  watched at session start — open `/hooks` once (or restart) to force a reload.
- Review/edit/disable via the `/hooks` command.
