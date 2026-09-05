---
date: 2026-09-05
tags: [architecture, claude-code, agent-sdk, mcp, skills, plugins]
source: Claude Code session
---

# Agent SDK vs Skill vs Plugin vs MCP server

| | What it is | Where it runs | Analogy |
|---|---|---|---|
| **Agent SDK** | A library for building an entirely new, standalone agentic application — your own program with its own agent loop, tools, and deployment | Its own process/service, wherever you deploy it (not inside Claude Code) | Building your own app from a framework — this is literally what Claude Code itself is built on |
| **Skill** | Packaged instructions (a `SKILL.md` + optional scripts/resources) that teach an existing agent how to do a specific task, loaded into context on demand | Inside a host that already runs an agent loop — Claude Code, claude.ai, or an SDK app that supports skills | A how-to guide or SOP handed to a worker who already has a job |
| **Plugin** | A distributable bundle for Claude Code specifically — can package skills, subagents, hooks, slash commands, and MCP server configs together | Installed into a Claude Code session | An app-store package — one install, multiple features bundled |
| **MCP server** | A separate service exposing tools/data over a standard protocol, connectable by any compatible client | Its own process (local or remote), connected to by the agent | A plug-in peripheral — any compatible device can use it, not just one app |

## How to pick

- Want Claude Code to know how to do something better → **Skill**
- Want to package and share several skills/hooks/commands as one installable unit for Claude Code → **Plugin**
- Want to give an agent access to an external system/API/database as a tool → **MCP server** (works across Claude Code, Desktop, claude.ai, SDK apps)
- Want to build your own standalone agent product, not extend Claude Code → **Agent SDK**

They compose: an Agent SDK app can consume MCP servers and skills too; a Claude Code plugin can bundle an MCP server config alongside its skills.
