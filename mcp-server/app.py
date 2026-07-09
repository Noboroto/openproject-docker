"""Shared FastMCP instance + lifespan-managed OpenProject client.

Tool modules import `mcp` from here and decorate with @mcp.tool().
The pooled client is created once at startup and exposed via get_client().
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from starlette.datastructures import Headers
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

from auth import extract_token, reset_request_token, set_request_token
from client import OpenProjectClient

# Module-global client, set during lifespan startup. Version-robust: tools call
# get_client() rather than threading Context through every signature.
_client: OpenProjectClient | None = None


def get_client() -> OpenProjectClient:
    if _client is None:
        raise RuntimeError("OpenProject client not initialized (lifespan not started)")
    return _client


@asynccontextmanager
async def lifespan(_server: FastMCP):
    global _client
    _client = OpenProjectClient()
    try:
        yield
    finally:
        if _client is not None:
            await _client.aclose()
            _client = None


mcp = FastMCP(
    "openproject-mcp",
    instructions=(
        "Tools to manage OpenProject: projects, work packages (tasks), users, "
        "types/statuses/priorities, comments, and time entries. For updates, "
        "lockVersion is fetched automatically. Use validate_work_package to "
        "dry-run a create before committing.\n\n"
        "Work package fields depend on the project and type: story points need "
        "the backlogs module, and categories/versions are project-scoped. "
        "Writes are checked against the live schema, so an unsupported field is "
        "skipped rather than failing the call — ALWAYS check the `warnings` key "
        "in a create/update result and tell the user which fields were not "
        "applied. Call list_work_package_fields(project_id, type_id) to see what "
        "is settable, and pass anything without a dedicated parameter via "
        "`custom_fields` using its raw schema key (e.g. {\"customField3\": 5})."
    ),
    stateless_http=True,
    lifespan=lifespan,
    # op-mcp always runs behind a trusted reverse proxy (op-proxy/NPM) that
    # controls the Host header, so allow any host — disable the SDK's default
    # DNS-rebinding protection, which otherwise 421s requests whose Host is not
    # localhost (e.g. the public domain proj.example.com/mcp).
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=False,
    ),
)


class TokenCaptureMiddleware:
    """ASGI middleware for per-user mode.

    Stashes the caller's OpenProject token (from `X-OpenProject-Token` or
    `Authorization: Bearer`) into a ContextVar for the duration of each HTTP
    request, so the shared client can act as that user. Added to the app in
    server.py; a no-op on the stdio transport (no HTTP layer).
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        marker = set_request_token(extract_token(Headers(scope=scope)))
        try:
            await self.app(scope, receive, send)
        finally:
            reset_request_token(marker)


@mcp.custom_route("/health", methods=["GET"])
async def health(_request: Request) -> JSONResponse:
    """Liveness probe for the streamable-http transport.

    Used by the OpenProject MCP-CE plugin admin page (and any orchestrator) to
    confirm the server is up WITHOUT speaking the MCP handshake. Returns 200 as
    soon as the process is serving; `mcp` reports whether the upstream client was
    initialized by the lifespan. The MCP protocol endpoint itself stays at /mcp.
    """
    return JSONResponse(
        {
            "status": "ok",
            "server": "openproject-mcp",
            "mcp_endpoint": "/mcp",
            "client_initialized": _client is not None,
        }
    )
