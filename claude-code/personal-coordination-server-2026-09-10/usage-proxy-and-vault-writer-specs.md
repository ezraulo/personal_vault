# Build specs: `vault-writer` and `usage-proxy`

Both live under `~/personal_vault/tools/` (new top-level area, alongside `notes/`,
`claude-code/`, `home-recovery/`). Confirmed on this machine: Node v26.8.1 runs `.ts`
files directly (`node file.ts`) with **no build step, no `tsx`/`ts-node`** — but
relative imports need the literal `.ts` extension (`import { x } from "./notes.ts"`,
not `"./notes"` — Node's loader doesn't do extension resolution like `tsc`/bundlers
do). `node:sqlite` (`DatabaseSync`) works with zero warnings on this Node version.
Confirmed real package versions via `npm view`: `@modelcontextprotocol/sdk@1.30.0`
(peer-supports `zod@^3.25 || ^4.0`), `gray-matter@4.0.3`, `zod@4.5.4`.

## `tools/vault-writer/`

**Resolve first**: does this wrap `/stash`'s existing logic as an MCP tool (so Gemini
CLI gets write parity), or replace it? See the open question in
`architecture-and-decisions.md`. The spec below assumes reuse of `/stash`'s exact
convention either way.

### Tools (2, both write — not `readOnlyHint`)

**`add_note(slug, content, tags[], source)`**
- Writes `notes/<today's-date>-<slug>.md` with the standard frontmatter:
  ```yaml
  ---
  date: <YYYY-MM-DD>
  tags: [<tags>]
  source: <source, default "Claude Code session" or "Gemini CLI session">
  ---
  ```
  followed by `content`.
- **Refuses to overwrite** if the slug/filename already exists — same behavior as
  `/stash`. Return an error naming the collision, don't silently pick a different
  name.
- `destructiveHint: false`, but not `readOnlyHint` either — it's a write.

**`append_note(slug)`**
- Appends `content` to an existing note by slug. Errors clearly if the slug doesn't
  exist (don't silently create it — that's `add_note`'s job).

### Git safety (mirrors `/stash` exactly)

Before writing: `git pull --ff-only` (avoid divergence — other agents/devices may have
pushed). After writing: `git add -A && git commit -m "Add note: <slug>"` (or
`"Update note: <slug>"` for append) `&& git push`. Confirm back with the local path and
the GitHub URL, same as `/stash` does.

### Stack

TypeScript + `@modelcontextprotocol/sdk`, run directly via `node src/index.ts` — no
build step. `package.json`: `"type": "module"`, deps `@modelcontextprotocol/sdk@^1.30`,
`zod@^4.5`, `gray-matter@^4.0` (for frontmatter parsing/writing consistency with the
read side); devDeps `typescript`, `@types/node`.

### Registration

```
claude mcp add vault-writer --scope user -- node ~/personal_vault/tools/vault-writer/src/index.ts
```
Plus the equivalent `gemini mcp add`. `--scope user` (not project-local) — this is a
personal tool usable from any working directory, not tied to one project.

### Verification

1. `npm install && npm run typecheck` (if a typecheck script exists).
2. Register locally, ask Claude Code to save a note — confirm a real file lands in
   `notes/` with correct frontmatter and a real git commit+push.
3. Test the collision-refusal path (try `add_note` on an existing slug).
4. Test `append_note` on a real note.

---

## `tools/usage-proxy/`

**Not** Anthropic's Claude apps gateway (rejected — see decisions doc). A minimal
local transparent reverse proxy for personal request/usage visibility only.

### Stack

Node, **only** built-in `node:http`/`node:https` (no proxy library — deliberate,
keeps the path that forwards your auth header small enough to read top-to-bottom in
one sitting). Storage: `node:sqlite`. **Zero runtime dependencies** for this whole
project.

### Request/response flow

- `http.createServer` on `127.0.0.1` **only** (never `0.0.0.0` — must not be reachable
  from the network). Port: `USAGE_PROXY_PORT` env var, default `8787`.
- Upstream: `PROXY_UPSTREAM_URL` env var, default `https://api.anthropic.com`.
  (Deliberately not named `ANTHROPIC_BASE_URL` — that name is reserved for pointing
  `claude` *at* the proxy; reusing it here would be a copy-paste hazard.)
- On each request: forward method + path/query verbatim, headers minus hop-by-hop ones
  (`connection`, `keep-alive`, `proxy-authenticate`, `proxy-authorization`, `te`,
  `trailers`, `transfer-encoding`, `upgrade`), `host` rewritten to the upstream
  hostname. **`authorization`/`x-api-key`/`anthropic-version` pass through completely
  untouched** — the proxy never inspects, generates, or caches credentials.
- **Never parses the request body** — `req.pipe(upstreamReq)` directly. Sidesteps any
  risk of the proxy touching prompt content on the way in (and it's unnecessary —
  `model`/token counts are obtainable from the *response*).
- On the upstream response: `upstreamRes.pipe(res)` **immediately and unconditionally**,
  regardless of content type — this is what makes SSE streaming never buffer/delay. In
  parallel, tee the same chunks into an in-memory accumulator purely for logging (side
  channel, never gates or delays what's written to `res`).
- On `upstreamRes` `"end"`: compute latency, determine `streamed` from
  `content-type: text/event-stream`, parse accumulated text for `model`/`usage`
  (SSE case: see below; JSON case: parse directly). Any parse failure is caught and
  logged as an `error` string in that row — never thrown, never affects what was
  already streamed to the client.
- On upstream connection error: respond `502` if headers not yet sent, log a row with
  `status: null`.

### SSE usage extraction

Anthropic's streaming Messages API emits `message_start` (full `message` object:
`model`, initial `usage.input_tokens`, `cache_creation_input_tokens`,
`cache_read_input_tokens`) and one or more `message_delta` events (cumulative
`usage.output_tokens` — last one wins). Split accumulated text on `\n\n`, parse
`data: ` lines, switch on `.type`, ignore everything else (`content_block_*`, `ping`,
`message_stop`). Wrap in try/catch, best-effort, never throws.

### SQLite schema (`data/usage.db`, `CREATE TABLE IF NOT EXISTS` on every start)

```sql
CREATE TABLE IF NOT EXISTS usage_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  model TEXT,
  status INTEGER,
  streamed INTEGER NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  cache_creation_input_tokens INTEGER,
  cache_read_input_tokens INTEGER,
  latency_ms INTEGER NOT NULL,
  error TEXT
);
CREATE INDEX IF NOT EXISTS idx_usage_log_ts ON usage_log(ts);
CREATE INDEX IF NOT EXISTS idx_usage_log_model ON usage_log(model);
```
**No prompt/completion content column anywhere** — this is the concrete enforcement of
"metadata only," matching Anthropic's own gateway's stated telemetry philosophy.

### Report CLI (`src/report.ts`, `npm run report [-- --since YYYY-MM-DD] [--by day|model|day-model]`)

Grouped query by day/model with request counts, token sums, avg latency, plus a
grand-totals row. `console.table` output only — no dashboard, no charting.

### Opt-in wrapper (`bin/claude-logged`)

```bash
#!/usr/bin/env bash
set -euo pipefail
PROXY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${USAGE_PROXY_PORT:-8787}"
if ! lsof -i :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  (cd "$PROXY_DIR" && node src/server.ts > data/proxy.log 2>&1 &)
  sleep 0.3
fi
export ANTHROPIC_BASE_URL="http://127.0.0.1:${PORT}"
exec claude "$@"
```
User adds one alias: `alias claude-logged="$HOME/personal_vault/tools/usage-proxy/bin/claude-logged"`.
Plain `claude` stays completely untouched — `ANTHROPIC_BASE_URL` is only ever set
inside this wrapper's own process/exec, never exported in a shell rc file. This
preserves the existing claude.ai-subscription credential (confirmed: setting only
`ANTHROPIC_BASE_URL` with no separate gateway credential keeps the subscription login
active — verified against Claude Code's own gateway docs). The `lsof` check makes it
safe to run from multiple terminal tabs without spawning duplicate proxy processes.

### Files

```
tools/usage-proxy/
├── package.json          # "type": "module", zero runtime deps
├── tsconfig.json
├── bin/claude-logged      # chmod +x
├── data/.gitkeep          # usage.db/proxy.log/proxy.pid land here, gitignored
└── src/
    ├── server.ts          # entry point, http server, request lifecycle
    ├── forward.ts         # header filtering + request/response piping
    ├── sse-usage-parser.ts
    ├── db.ts              # node:sqlite setup + schema + insert/query
    └── report.ts          # separate CLI entry
```

### Verification (in order — pass-through correctness before logging correctness)

1. `npm install && npm run typecheck`.
2. Start manually, confirm it listens and idles without crashing.
3. Non-streaming `curl` smoke test directly against the proxy (not through `claude`) —
   confirm response matches hitting `api.anthropic.com` directly.
4. Streaming smoke test (`"stream": true`) — confirm output arrives incrementally, not
   all at once (proves no buffering).
5. Query `usage_log` after steps 3-4 — confirm rows exist with correct model/tokens
   and **no prompt/completion text anywhere**.
6. End-to-end through Claude Code via `claude-logged` — confirm completely normal
   behavior (no re-auth prompt, no error — this is the check that pass-through didn't
   break the subscription credential flow), then confirm a new row landed.
7. `npm run report` and `npm run report -- --since <date>` — confirm totals match.
8. Confirm isolation: plain `claude` in a fresh terminal has no `ANTHROPIC_BASE_URL` set.

### Sequencing (from the original implementation pass)

1. Scaffold `tools/` + `.gitignore`, no functional code — first commit.
2. Build `vault-writer`, verify.
3. Build `usage-proxy` core forwarding (no logging yet) — verify pass-through/streaming
   work *before* adding logging, since a broken pass-through is a functional
   regression on `claude` itself, whereas broken logging is not.
4. Add `db.ts` + logging + `sse-usage-parser.ts`, verify.
5. Add `report.ts`, verify.
6. Add `bin/claude-logged` + alias, verify isolation.
