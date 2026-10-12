# openproject-mcp-ce

**Companion plugin** for the standalone [OpenProject MCP server](../../mcp-server)
(`op-mcp`, already defined in `docker-compose.yml`). It does **not** run the MCP
server — it only surfaces, inside OpenProject:

1. **The connection path** AI clients (Claude Code, Claude Desktop, Codex, …)
   should point at — both the in-stack endpoint and the public one.
2. **A live health check** that pings the MCP server's `/health` endpoint and
   reports reachability, HTTP status, and latency.

## Where

- **My account → MCP Server** (`/my/mcp`) — every logged-in user. Read-only guide:
  client path, API-token link, copy-ready snippets, and the optional
  `X-OpenProject-Project` header that limits an agent to one project.
- **Administration → MCP Server** (`/admin/mcp`) — admin only (`require_admin`).
  The same guide plus in-stack endpoint, health check and settings.

Both pages share `McpCe::ConnectionInfo` and the `mcp_ce/_client_setup` partial.

## Settings (no DB table)

Stored in the `Setting` store — there is **no migration**, so deploying this
plugin can never block a production database migrate.

| Setting | Default | Meaning |
|---|---|---|
| `mcp_base_url` | `http://op-mcp:8000` | In-stack base URL of the op-mcp service. Endpoint = `<base>/mcp`, health = `<base>/health`. |
| `mcp_public_url` | _(blank)_ | External base URL once exposed via the proxy; public endpoint = `<public>/mcp`. |

## Health check

`POST /admin/mcp/health_check` does a short-timeout (3s) server-side GET to
`<mcp_base_url>/health`. The MCP server exposes that route (added in `mcp-server/app.py`)
returning `{"status":"ok", ...}`. The base URL is admin-configured, so this is
not an open SSRF vector.

See the repo-level [`MCP.md`](../../MCP.md) for full client setup instructions.
