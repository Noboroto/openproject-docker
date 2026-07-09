# MCP server — per-user authentication

The `mcp-server/` MCP server runs **per-user** over `streamable-http`: each HTTP
request authenticates with the connecting user's OWN OpenProject API token, so the
server acts as whoever is connected (no single shared identity).

## How it works
- `auth.py` — `extract_token(headers)` reads the token from (priority):
  1. `X-OpenProject-Token: opapi-...`  (preferred; a custom header no MCP client hijacks for OAuth)
  2. `Authorization: Bearer opapi-...` (fallback)
  Stored in a `ContextVar` via `set_request_token` / `get_request_token`.
- `app.py` — `TokenCaptureMiddleware` (pure ASGI) binds the request token into the ContextVar
  for the request's duration, resets it after. Added to the app in `server.py` for streamable-http.
- `client.py` — the pooled httpx client carries NO baked-in auth. `_auth()` resolves per request:
  request token (from ContextVar) OVERRIDES env `OPENPROJECT_TOKEN`; legacy `OPENPROJECT_API_KEY`
  is HTTP-Basic last resort; none → raise `OpenProjectError(401, ...)`. get/post/patch/delete pass
  `headers=`/`auth=` per call.
- `server.py` — streamable-http builds `mcp.streamable_http_app()`, wraps with the middleware,
  runs via `uvicorn`. `stdio` has no HTTP layer → always uses env token.

## Fallback / modes
- Env `OPENPROJECT_TOKEN` is now OPTIONAL (server no longer refuses to start without it). Used only
  when a request carries no token (stdio, or a deliberate shared-token deployment).

## Plugin guide sync
`openproject-mcp-ce` admin page emits copy-ready snippets (claude_code/vscode/codex/json) that all
include the `X-OpenProject-Token` header with placeholder `opapi-YOUR_TOKEN`. Constants
`TOKEN_HEADER` / `TOKEN_PLACEHOLDER` in the controller; per-user note is locale key `auth_note_html`.

Docs: `MCP.md` §2/§3/§5, `mcp-server/README.md` "Per-user authentication".
