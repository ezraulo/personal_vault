# Architecture and decision trail

Full reasoning behind every adopted/rejected option, in the order they came up. Written
so a future session (or a different agent entirely) can understand *why*, not just
*what*, without re-deriving any of it.

## The original ask, and how it evolved

Started as "what does the `mcp-server-dev` plugin do" (an empty/unfilled stub skill).
Evolved through conversation into: the user wants a personal, cross-agent context
layer — not a notes-search tool, a genuine "librarian/gatekeeper" holding preferences,
rules, learned facts, and a tool registry, usable by whichever agent (Claude Code,
Gemini CLI) they're working with at the time, so they stop re-explaining themselves
and agents stop duplicating each other's mistakes.

## Rejected: Anthropic's Claude apps gateway

The user initially said "personal mcp server and gateway." "Gateway" turned out to be
overloaded terminology — in Claude Code specifically it means Anthropic's self-hosted
LLM API-routing proxy (`claude gateway`, requires an OIDC identity provider, Postgres,
a Linux server), built for organizations sharing one upstream credential across many
developers. Confirmed via `code.claude.com/docs/en/gateways` and
`.../claude-apps-gateway`: the doc's own note says "if you don't have this [org]
requirement... Claude Enterprise may be a better fit." Zero benefit at solo scale,
real infra cost. Rejected.

Replaced with a much lighter want: a local transparent logging proxy in front of
`ANTHROPIC_BASE_URL` purely for personal request/usage visibility — see the specs doc.

## Rejected: mem0/OpenMemory, Letta, Zep/Graphiti (the "AI memory product" category)

Researched as the established category for "cross-agent personal memory." All three
share the same architectural weak point: an LLM judges what's worth remembering and
resolves conflicts between memories, and that judge is the category's documented,
unsolved failure mode — mem0's own issue tracker (#5867) has a report of it silently
deleting a memory the user still needed, because similarity-based conflict resolution
can't distinguish "the user changed their mind" from "the user has two preferences
that are both true, in different contexts." All three also require real infrastructure
(Docker, vector DB, sometimes Neo4j) for a solo, local-first, low-maintenance setup.
Rejected on both the fragility and the infra-weight axes.

## Rejected: LangChain / LlamaIndex as a foundation

Pushed on again later ("is this really the ceiling") specifically for these two.
Finding: both are pipeline-*assembly* frameworks (you write the indexing, storage
choice, retrieval logic, and MCP-serving layer yourself), not ready memory servers.
Their MCP integrations are client-side tool-*consumption* (letting an agent built on
them use external MCP servers), not a way to *serve* personal data as MCP tools to
other hosts. The one first-party attempt at the latter — LlamaCloud's MCP server —
requires a paid cloud service and was archived August 2026. Both also carry real
version-churn risk (LlamaIndex is pre-1.0 with no stability guarantee and a documented
history of breaking releases; LangChain only hit its first stability commitment in Oct
2025). Building on either would mean writing the same custom code already planned,
wrapped in a heavier, faster-breaking dependency. Rejected — pure framework weight, no
capability gain over what's below.

## Adopted: `rtfm` for retrieval

Already installed as a Claude Code plugin. Local SQLite+FTS5 (+optional local-ONNX
semantic search via FastEmbed), MCP-native, purpose-built Obsidian/PKM vault mode,
AST/header-aware parsing across 22 file formats, and — critically — already has a
`rtfm memory` mode that indexes `~/.claude/projects/*/memory/` across every project on
the machine, which is close to "central repository of what we've learned" out of the
box. Zero cost, no cloud, no API keys for the FTS5 baseline.

**Execution gotcha, already fixed**: the plugin's own bundled auto-init trusts `cwd` as
"the project" — since Claude Code sessions here run from `~` (not a real project, see
top-level `~/CLAUDE.md`), it had silently been indexing the *entire home directory*
(284,267 files, 3.7% synced, mostly noise) as "the vault index." Fixed by installing
the standalone `rtfm-ai` CLI (`uv tool install rtfm-ai`) and running `rtfm init`
explicitly inside `~/personal_vault`, giving it its own project-scoped
`~/personal_vault/.rtfm/library.db`, independent of the home-wide one. Confirmed
working: a genuinely fresh, cold-start Claude Code session launched from
`~/personal_vault` correctly auto-loaded the RTFM-usage instructions and had the
`rtfm_*` MCP tools available, with no manual registration needed (rtfm's own `init`
auto-created a project-scope `.mcp.json`).

**Known minor cleanup, not urgent**: two overlapping corpora ("default" from the
initial auto-init, "vault" from an explicit forced sync) both point at the same
directory — cosmetic duplication, not a correctness problem, worth collapsing to one
corpus eventually. Also: `rtfm` shows up twice in a fresh session's tool list
(`mcp__rtfm__*` from the plugin, `mcp__plugin_rtfm_rtfm__*` from the project's own
`.mcp.json`) — redundant, harmless.

## Adopted: `remember` for continuity — Claude Code only

Already installed and running. Hooks `SessionStart`/`PostToolUse`/`SessionEnd`,
auto-saves session activity, compresses through Haiku into layered summaries
(`now.md` → `today-*.md` → `recent.md` → `archive.md`), re-injects at the next
`SessionStart` automatically. This is exactly the "inform the agent without repeating
yourself" mechanism that would otherwise need building from scratch.

**Confirmed limitation**: its Gemini CLI support is, per its own maintainer's docs
(`docs/install-gemini-cli.md`), "manifests only, not yet driven live" — never observed
firing a hook under a real Gemini CLI session in the maintainer's own testing, and on
an individual **free-tier** Google account the required `gemini extensions link`
command is refused outright (`IneligibleTierError: UNSUPPORTED_CLIENT`). Treat as
Claude-Code-reliable only until proven otherwise on this specific account.

**Confirmed via live test**: from `~` (home dir), a fresh session got real injected
`.remember/` content (today's actual session log). From `~/personal_vault`, only the
file-layout pointer was injected, no real content — meaning `remember`'s continuity is
currently anchored to `~` as "the project," not to `personal_vault` specifically, even
though most of the actual work happens in/around the vault. Not necessarily a problem
(most sessions do run from `~`), but worth knowing.

## Rejected/superseded: bespoke `vault-mcp-server` read tools

Before `rtfm`'s role was clear, a full 4-tool read-only server was fully speced by a
Plan sub-agent (`search_notes`/`fetch_note`/`list_notes`/`list_tags`, hand-rolled
weighted substring search, TypeScript + official MCP SDK, native `.ts` execution on
Node v26.8.1, no build step). **Do not build this** — `rtfm_search`/`rtfm_context`/
`rtfm_expand`/`rtfm_tags` already do this, with AST/header-aware parsing and optional
semantic search rtfm's implementation would have needed reinventing. The Plan
sub-agent's detailed *implementation-mechanics* findings (native-TS gotchas, exact
package versions, Node/`node:sqlite` behavior) are still valid and reused for the
`usage-proxy` spec, which is unrelated in purpose.

## Evaluated and rejected: Basic Memory (for the write path)

Surfaced by a broader ecosystem sweep as a serious, actively-maintained
(~3,900★) local-first, MCP-native, plain-Markdown alternative that — unlike `rtfm` —
already has both read *and write* tools, making it a plausible replacement for the
planned custom `vault-writer` server. Installed (`uv tool install basic-memory`) and
tested directly against the real vault, not just read about:

- `basic-memory project add eval-vault ~/personal_vault/notes --local` — registered.
- `read-note` on an existing note (`2026-09-09-precompact-archive-hook`) returned
  **completely null** (title/content/frontmatter all `null`) — it could not parse any
  of the 8 existing notes at all.
- `search-notes` returned zero results for a term ("precompact") that's prominently
  in an existing note's title.
- A test `write-note` revealed its actual expected schema:
  ```yaml
  ---
  title: Test Note Format
  type: note
  permalink: eval-vault/bm-test/test-note-format
  ---
  ```
  No `date`/`tags`/`source` — completely incompatible with the vault's established
  convention (used by `/stash` and all 8 existing notes) and a different filename
  convention too (literal title, not `YYYY-MM-DD-slug.md`).

**Verdict**: adopting Basic Memory means either migrating every existing note to an
incompatible schema, or running two parallel, incompatible note formats in the same
folder — both worse than the alternative. Rejected. Per the original decision rule
("if it doesn't fit cleanly, fall back to the small custom server"), the plan reverts
to building the small custom `vault-writer` MCP server, reusing `/stash`'s existing,
proven convention exactly. `basic-memory` was uninstalled from the eval project after
testing; no trace left in the vault itself.

## Open question, not yet resolved: `/stash` vs. `vault-writer`

A full read-through of the vault ("mining" pass, see below) confirmed `/stash`
(`dotfiles/claude-commands/stash.md`) is not just prior art — it's a working,
already-deployed write path (git-safe pull/commit/push, correct frontmatter), and the
vault's own `README.md` already states the cross-agent intent explicitly: "Any agent
with shell/git access — Claude Code, Gemini CLI, local scripts — can read or add to
this." Unresolved: should `vault-writer` *wrap* `/stash`'s existing logic as an MCP
tool (so Gemini CLI, which has no slash commands, gets write parity), or does it
replace `/stash` outright? Decide this explicitly before or during the `vault-writer`
build — don't let it default silently either way.

## Design principle adopted for the write path

From `notes/2026-09-10-session-hygiene-recommendations.md`'s duplicate-tab incident,
generalized one level down: **a write one agent makes is never treated as an
instruction the other agent must follow.** Relevant because both Claude Code and
Gemini CLI will be able to write to the same shared vault — one agent's write/suggestion
shouldn't be auto-trusted by the other as something it must act on.

## The vault-mining pass (what else was in the "attic")

A full, dedicated read-through of `personal_vault` (notes/, `claude-code/*`,
`home-recovery/`, dotfiles) was done specifically to check for reusable ideas before
building anything new. Findings, condensed:

- **Reusable, already cited above**: `/stash`, the vault's own agent-agnostic
  `README.md` framing, the `PreCompact` hook's "trigger on a deterministic event, don't
  rely on remembering" design principle, the "peer output is never authorization"
  principle.
- **Good idea, wrong scope**: `claude-code/session-system-design-2026-09-10/`
  (session lifecycle/dedup-detection MCP server — a separate, already-designed,
  ring-fenced project; do not touch, do not merge into this one).
- **Dead ends, nothing to port in**: `claude-code/message-differentiation/` and
  `claude-code/session-management-proposal/` — both fully-designed proposals that
  invented Claude Code hook events that don't actually exist (`PostMessage`,
  `PostSessionRespawn`, `PreRespawnDecision`, `PreSessionRename`, a `"type":
  "transform"` hook kind). See the wrong-turns note for the generalized lesson.
- **Pure clutter, confirmed and left alone**: `claude-code/ux-improvements/` (empty),
  `home-recovery/` (a separate, complete, self-contained incident-recovery archive from
  the 2026-09-04 event, no relevance here).

## Housekeeping done to the vault repo itself this session

- Committed and pushed `claude-code/session-system-design-2026-09-10/` — it had never
  been committed, existed disk-only, at real risk of loss.
- Committed this session's own `rtfm` project config (`.mcp.json`, `CLAUDE.md`,
  `.claude/hooks/`) so a fresh clone gets the same scoped index setup.
- Removed three unmodified GitHub Actions template files (`manual.yml`, `nextjs.yml`,
  `summary.yml`) — none related to vault content; `nextjs.yml` was actively firing and
  failing on every single push (no `package.json` in this repo).
- Added `.gitignore` entries for `.rtfm/` (local index db, regenerable) and
  `.DS_Store`.
