# OpenProject MCP Server

A **standalone** Model Context Protocol server for OpenProject. It talks to your
OpenProject instance only through the **REST API v3** — it needs no Ruby plugin
and works against any OpenProject (Community or Enterprise).

## Tools (20)

| Group | Tools |
|---|---|
| Projects | `list_projects`, `get_project` |
| Work packages | `list_work_packages`, `get_work_package`, `validate_work_package`, `create_work_package`, `update_work_package`, `delete_work_package` |
| Users | `list_users`, `get_user` |
| Lookups | `list_types`, `list_statuses`, `list_priorities`, `list_time_entry_activities` |
| Comments | `list_comments`, `create_comment` |
| Time entries | `list_time_entries`, `create_time_entry`, `update_time_entry`, `delete_time_entry` |

Plus MCP **Resources** (`openproject://projects`, `openproject://work_packages/{id}`)
and **Prompts** (`weekly_time_report`, `sprint_backlog`).

A plain-HTTP **`GET /health`** liveness route (no MCP handshake) returns
`{"status":"ok", "mcp_endpoint":"/mcp", "client_initialized":true}` — used by the
`openproject-mcp-ce` plugin's admin health check and any orchestrator probe.

## Configuration

| Env var | Purpose |
|---|---|
| `OPENPROJECT_URL` | Base URL, e.g. `http://web:8080` (in-stack) or `https://op.example.com` |
| `OPENPROJECT_TOKEN` | API token (`opapi-...`) — **preferred**, sent as Bearer |
| `OPENPROJECT_API_KEY` | Legacy fallback — HTTP Basic, username `apikey` |
| `TRANSPORT` | `streamable-http` (default) or `stdio` |
| `HOST` / `PORT` | bind address (default `0.0.0.0:8000`) |

Generate a token in OpenProject: **My Account → Access tokens → + API Token**.

## Run with Docker (in the stack)

```bash
# 1. Start OpenProject, generate an API token in the UI, put it in .env.local
# 2. Start the MCP server:
docker compose --env-file .env.local up -d op-mcp
# streamable-http endpoint: http://127.0.0.1:8000/mcp
```

## Run standalone (local dev)

```bash
pip install -r requirements.txt
export OPENPROJECT_URL=https://your-op-instance
export OPENPROJECT_TOKEN=opapi-xxxxxxxx
python server.py                      # streamable-http on :8000
python server.py --transport stdio    # for Claude Desktop
```

## Claude Desktop (stdio)

`%APPDATA%\Claude\claude_desktop_config.json` (Windows) /
`~/.config/Claude/claude_desktop_config.json` (Linux/Mac):

```json
{
  "mcpServers": {
    "openproject": {
      "command": "python",
      "args": ["D:/Github/openproject-docker/mcp-server/server.py", "--transport", "stdio"],
      "env": {
        "OPENPROJECT_URL": "https://your-op-instance",
        "OPENPROJECT_TOKEN": "opapi-xxxxxxxx"
      }
    }
  }
}
```

## Remote access (server deployment)

**Deploy maps NO host port** (only the proxy is exposed). `op-mcp` joins the
`frontend` network so the proxy can route to it. Expose a subdomain via the
**Nginx Proxy Manager UI**:

- Forward Hostname/IP: `op-mcp` · Port: `8000` · scheme `http`
- Enable **Websockets Support** (streamable-http keeps a long-lived connection)
- SSL tab → request a Let's Encrypt cert, force HTTPS
- Do **not** hand-edit the nginx config files.

Then point an HTTP MCP client at `https://<your-mcp-subdomain>/mcp`.

### Local testing without the proxy

Use the dev overlay, which adds a host-only `127.0.0.1:8000` mapping:

```bash
docker compose --env-file .env.local \
  -f docker-compose.yml -f docker-compose.dev.yml up -d op-mcp
# endpoint: http://127.0.0.1:8000/mcp
```

Or SSH-tunnel to the server's container network if needed.
