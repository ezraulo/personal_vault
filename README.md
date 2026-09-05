# personal_vault

A private, agent-agnostic reference vault: plain Markdown notes, versioned in git.
Any agent with shell/git access (Claude Code, Gemini CLI, local scripts) can read
or add to this — no vendor-specific API required.

## Structure

```
notes/       one Markdown file per stashed item, frontmatter for metadata
```

## Conventions

Each note starts with frontmatter:

```markdown
---
date: YYYY-MM-DD
tags: [tag1, tag2]
source: where this came from
---
```
