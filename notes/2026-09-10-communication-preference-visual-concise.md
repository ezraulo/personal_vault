---
date: 2026-09-10
tags: [preference, communication-style, accessibility]
source: Claude Code session
---

# Preference: visual/concise over dense text

The user has ADHD — long blocks of dense text are harder to read than fast,
"transactional" back-and-forth (chat) or visual/structured content. Applies to any
document meant primarily for them to read (not agent-facing technical docs).

**When producing something for the user to read:**
- Prefer a visual, diagram-illustrated format (e.g. a published Artifact) over a wall
  of markdown, when the content is substantial enough to warrant it.
- Keep sections short, scannable, high visual hierarchy — tables/diagrams over long
  paragraphs.
- Chat-style, quick exchanges work well; don't default to long essay-style replies
  when a shorter one covers it.
- Technical/reference docs meant for an agent to consult (not the user directly) don't
  need this treatment — structured markdown/frontmatter is fine and often better for
  that audience. Match the format to who's actually going to read it.

Came up directly: user requested project documentation as "both" a technical markdown
doc (for agents) and a visual manual (for them), "leaning towards" the visual version
for most of what they'll actually read.
