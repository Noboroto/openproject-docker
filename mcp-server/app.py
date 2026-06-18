"""Shared FastMCP instance + lifespan-managed OpenProject client.

Tool modules import `mcp` from here and decorate with @mcp.tool().
The pooled client is created once at startup and exposed via get_client().
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from mcp.server.fastmcp import FastMCP
from starlette.requests import Request
from starlette.responses import JSONResponse

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
        "dry-run a create before committing."
    ),
    stateless_http=True,
    lifespan=lifespan,
)


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
