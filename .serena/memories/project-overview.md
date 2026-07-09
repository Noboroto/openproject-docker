# openproject-docker — project overview

Self-hosted OpenProject via Docker Compose, plus custom plugins and a standalone MCP server.
Polyglot repo: **Ruby** (Rails plugins), **Python** (MCP server), **TypeScript/Angular** (frontend plugin).

## Layout
- `docker-compose.yml` / `docker-compose.dev.yml` — stack. Services incl. `op-web`, `op-mcp`.
- `mcp-server/` — standalone Python MCP server (FastMCP, `mcp[cli]`). Talks to OpenProject via REST API v3 only.
  - `server.py` entry (transports: `streamable-http` default, `stdio`); `app.py` FastMCP instance + lifespan + `/health` + `TokenCaptureMiddleware`; `client.py` httpx API client; `auth.py` per-request token ContextVar; `tools/*` + `resources.py`.
- `plugins/openproject-mcp-ce/` — Rails plugin: **Administration → MCP Server** admin page (guide + health check). Controller `app/controllers/mcp_ce/admin_settings_controller.rb`, view `show.html.erb`, locales `config/locales/{en,vi}.yml`.
- `plugins/openproject-team-planner/` — Angular + FullCalendar resource-timeline team planner (frontend under `frontend/`, pnpm).
- `MCP.md` — full MCP setup/usage guide.

## MCP auth (per-user) — see `mem:mcp-per-user-auth`
The MCP server authenticates each HTTP request with the CALLER's own OpenProject API token
(header `X-OpenProject-Token`, or `Authorization: Bearer`), falling back to env `OPENPROJECT_TOKEN`.

## Deploy notes
- Remote deploy exposes NO host port for op-mcp — only via proxy (Nginx Proxy Manager forwards `/mcp` → `op-mcp:8000`, Websockets on).
- Local admin login: see `.env.local` / your password manager (use localhost, not 127.0.0.1).
- Branch `stable-17-plugin` tracks plugin work off `stable/17`.
