# OpenProject MCP — Setup & Usage Guide

The repo ships a **standalone Model Context Protocol (MCP) server** for OpenProject
in [`mcp-server/`](./mcp-server). It talks to OpenProject **only through the public
REST API v3** — no Ruby plugin required — so it works against any OpenProject
(Community or Enterprise), local or remote.

This guide covers: getting a token, the run modes, and wiring the server into
**Claude Code**, **Claude Desktop**, **Codex**, and any generic MCP client.

---

## 1. What you get

**20 tools**, 2 resources, 2 prompts:

| Group | Tools |
|---|---|
| Projects | `list_projects`, `get_project` |
| Work packages | `list_work_packages`, `get_work_package`, `validate_work_package`, `create_work_package`, `update_work_package`, `delete_work_package` |
| Users | `list_users`, `get_user` |
| Lookups | `list_types`, `list_statuses`, `list_priorities`, `list_time_entry_activities` |
| Comments | `list_comments`, `create_comment` |
| Time entries | `list_time_entries`, `create_time_entry`, `update_time_entry`, `delete_time_entry` |

- Resources: `openproject://projects`, `openproject://work_packages/{id}`
- Prompts: `weekly_time_report`, `sprint_backlog`
- Safety: `lockVersion` is fetched automatically before every update;
  `validate_work_package` dry-runs a create before you commit it.

---

## 2. Get an API token (required)

In OpenProject UI: **Avatar → My account → Access tokens → + API token**.

Copy the value — it looks like `opapi-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`.

> The same token works two ways with the same value: as a **Bearer** token
> (`OPENPROJECT_TOKEN`, preferred) or as HTTP Basic with username `apikey`
> (`OPENPROJECT_API_KEY`, legacy fallback). Use `OPENPROJECT_TOKEN`.

---

## 3. Environment variables

| Var | Purpose | Default |
|---|---|---|
| `OPENPROJECT_URL` | Base URL of the instance. In-stack: `http://op-web:8080`. Remote: `https://op.example.com` | `http://op-web:8080` |
| `OPENPROJECT_TOKEN` | API token (`opapi-...`) — preferred, sent as Bearer | — |
| `OPENPROJECT_API_KEY` | Legacy fallback (HTTP Basic, username `apikey`) | — |
| `TRANSPORT` | `streamable-http` (web/Docker) or `stdio` (desktop clients) | `streamable-http` |
| `HOST` / `PORT` | Bind address for streamable-http | `0.0.0.0` / `8000` |

You must set **one of** `OPENPROJECT_TOKEN` or `OPENPROJECT_API_KEY` — the server
refuses to start otherwise.

---

## 4. Run modes

### A. In the Docker stack (recommended for the server)

`op-mcp` is already defined in `docker-compose.yml` (proxy-only, no host port):

```bash
# token must be in .env.local (or .env) as OPENPROJECT_TOKEN=opapi-...
docker compose --env-file .env.local up -d op-mcp
```

### B. Local testing with a host port

The dev overlay maps `127.0.0.1:8000` so you can reach it directly:

```bash
docker compose --env-file .env.local \
  -f docker-compose.yml -f docker-compose.dev.yml up -d op-mcp
# endpoint: http://127.0.0.1:8000/mcp
```

### C. Standalone Python (no Docker)

```bash
cd mcp-server
pip install -r requirements.txt
export OPENPROJECT_URL=https://your-op-instance
export OPENPROJECT_TOKEN=opapi-xxxxxxxx
python server.py                    # streamable-http on :8000  → http://127.0.0.1:8000/mcp
python server.py --transport stdio  # stdio (for desktop clients)
```

### D. Remote (production, behind Nginx Proxy Manager)

The deploy exposes **no host port** — only the proxy. `op-mcp` joins the `frontend`
network. In the **NPM UI** add a proxy host:

- Forward Hostname/IP `op-mcp` · Port `8000` · scheme `http`
- Enable **Websockets Support** (streamable-http holds a long-lived connection)
- SSL tab → Let's Encrypt cert, force HTTPS

Then point clients at `https://<your-mcp-subdomain>/mcp`. Do **not** hand-edit nginx config files.

---

## 5. Wire it into clients

There are two transports. Pick by client:

- **`stdio`** — client launches the process locally (Claude Desktop, Codex). Best for a local instance.
- **`streamable-http`** — client connects to a running URL `…/mcp` (Claude Code remote, web clients).

### Claude Code (CLI)

**HTTP transport** (server already running via Docker mode A/B or remote D):

```bash
# local stack
claude mcp add --transport http openproject http://127.0.0.1:8000/mcp
# remote
claude mcp add --transport http openproject https://<your-mcp-subdomain>/mcp
```

**stdio transport** (Claude Code launches Python itself):

```bash
claude mcp add openproject \
  --env OPENPROJECT_URL=https://your-op-instance \
  --env OPENPROJECT_TOKEN=opapi-xxxxxxxx \
  -- python D:/Github/openproject-docker/mcp-server/server.py --transport stdio
```

Verify: `claude mcp list` then `/mcp` inside a session. Scope to the project with
`--scope project` to write `.mcp.json` into the repo (shareable with the team).

### Claude Desktop (stdio)

`%APPDATA%\Claude\claude_desktop_config.json` (Windows) or
`~/.config/Claude/claude_desktop_config.json` (Linux) /
`~/Library/Application Support/Claude/claude_desktop_config.json` (macOS):

```json
{
  "mcpServers": {
    "openproject": {
      "command": "python",
      "args": [
        "D:/Github/openproject-docker/mcp-server/server.py",
        "--transport", "stdio"
      ],
      "env": {
        "OPENPROJECT_URL": "https://your-op-instance",
        "OPENPROJECT_TOKEN": "opapi-xxxxxxxx"
      }
    }
  }
}
```

Restart Claude Desktop after editing. The tools appear under the 🔌 (plug) icon.

### Codex CLI

Codex reads MCP servers from `~/.codex/config.toml`:

```toml
[mcp_servers.openproject]
command = "python"
args = ["D:/Github/openproject-docker/mcp-server/server.py", "--transport", "stdio"]

[mcp_servers.openproject.env]
OPENPROJECT_URL = "https://your-op-instance"
OPENPROJECT_TOKEN = "opapi-xxxxxxxx"
```

Or via CLI: `codex mcp add openproject -- python D:/Github/openproject-docker/mcp-server/server.py --transport stdio`
(then set the env in the generated config). List with `codex mcp list`.

### Cursor / Windsurf / other editors (stdio)

Same shape as Claude Desktop — a `mcpServers` object with `command`, `args`, `env`.
Put it in the editor's MCP settings file (e.g. Cursor: `~/.cursor/mcp.json`).

### Generic HTTP MCP client

Point it at the streamable-HTTP endpoint:

```
http://127.0.0.1:8000/mcp     (local)
https://<your-mcp-subdomain>/mcp   (remote)
```

---

## 6. In-app guide & health check (MCP-CE plugin)

The `openproject-mcp-ce` plugin adds **Administration → MCP Server** inside
OpenProject (admin-only). It:

- shows the **connection path** clients should use — the public endpoint is
  **derived from `OPENPROJECT_HOST__NAME` + `/mcp`** (same domain, via the proxy),
  override via a public base URL setting;
- gives **shortcuts** to copy the MCP path and to open the API-token page;
- offers **copy-ready setup snippets** for Claude Code (CLI), VS Code
  (`.vscode/mcp.json`), Codex (`~/.codex/config.toml`), and a generic JSON config;
- runs a **health check** that pings the server's `/health` endpoint and reports
  reachability, HTTP status, and latency.

> **Proxy routing required for the same-domain path.** For `https://<your-op-domain>/mcp`
> to reach the MCP server, the proxy must forward `/mcp` → `op-mcp:8000`. In Nginx
> Proxy Manager add a custom location `/mcp` on the OpenProject proxy host pointing
> at `op-mcp:8000` (Websockets on). Otherwise expose `op-mcp` on its own subdomain
> and set that as the public base URL.

The MCP server exposes `GET /health` (liveness, no MCP handshake needed):

```bash
curl http://127.0.0.1:8001/health   # local dev mapping
# {"status":"ok","server":"openproject-mcp","mcp_endpoint":"/mcp","client_initialized":true}
```

## 7. Quick smoke test

With the server running (mode B) and a token set:

```bash
cd mcp-server
python client.py            # bundled test client — lists tools, calls list_projects
```

Or in Claude Code after adding the server: ask *"list my OpenProject projects"* —
it should call `list_projects` and return your projects.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| Server exits at startup: "Set OPENPROJECT_TOKEN…" | No token in env — set `OPENPROJECT_TOKEN`. |
| `401 Unauthorized` | Token wrong/revoked, or basic-auth disabled. Re-mint token; prefer `OPENPROJECT_TOKEN` (Bearer). |
| `404` on every call | `OPENPROJECT_URL` wrong (missing scheme, or pointing at proxy without `/`). The server appends `/api/v3` itself — don't include it. |
| Claude Code can't reach HTTP server | Server not up / wrong port. Use mode B for a `127.0.0.1:8000` mapping; check `docker compose ps op-mcp`. |
| Remote connection drops | Enable **Websockets Support** on the NPM proxy host. |
| In-stack URL | Use `http://op-web:8080` (service name), not `localhost`, from inside the Docker network. |

See [`mcp-server/README.md`](./mcp-server/README.md) for server internals.
