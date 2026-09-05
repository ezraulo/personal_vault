---
description: Stash a snippet of reference text into the personal_vault GitHub repo
argument-hint: [topic/slug] [optional: paste content to stash]
---

# Stash into vault

Vault: `/Users/august/personal_vault` (private GitHub repo `ezraulo/personal_vault`, notes under `notes/`).

First, sync the local clone with the remote so we never diverge (another agent/device may have pushed):

!`cd /Users/august/personal_vault && git pull --ff-only 2>&1`

## Task

Arguments: $ARGUMENTS

1. **Determine what to stash.**
   - If the arguments contain literal pasted text, that's the content.
   - Otherwise, "this" / "the above" refers to the most relevant recent content in this
     conversation (e.g. the last assistant response, or a block the user pointed at).
     If it's genuinely ambiguous which content is meant, ask before writing anything —
     don't guess at something this durable.

2. **Pick a filename.** Slug from the topic/arguments (or inferred from the content):
   lowercase, hyphenated, no spaces. Target path:
   `/Users/august/personal_vault/notes/<YYYY-MM-DD>-<slug>.md`
   (use today's actual date, not a placeholder).

   If a file already exists at that path, don't overwrite it — ask whether to append,
   replace, or pick a different slug.

3. **Write the note** with frontmatter:
   ```
   ---
   date: <YYYY-MM-DD>
   tags: [<relevant tags>]
   source: Claude Code session
   ---
   ```
   followed by the content. Clean it up as readable Markdown (e.g. convert ASCII/box-drawing
   tables to real Markdown tables) but stay faithful to the original meaning — don't
   summarize or drop information.

4. **Commit and push:**
   ```
   cd /Users/august/personal_vault && git add -A && git commit -m "Add note: <slug>" && git push
   ```

5. **Confirm** to the user with the local file path and the GitHub URL:
   `https://github.com/ezraulo/personal_vault/blob/main/notes/<filename>`
