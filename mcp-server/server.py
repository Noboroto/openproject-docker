"""OpenProject MCP Server — entry point.

Transports:
  streamable-http (default) — for Docker/web clients. Endpoint: /mcp
  stdio                     — for Claude Desktop (local), via --transport stdio

Env:
  TRANSPORT  streamable-http | stdio   (default streamable-http)
  HOST       bind host                 (default 0.0.0.0)
  PORT       bind port                 (default 8000)
  OPENPROJECT_URL    base URL of the OpenProject instance
  OPENPROJECT_TOKEN  API token (opapi-...), preferred
  OPENPROJECT_API_KEY  legacy fallback (HTTP Basic, username "apikey")
"""

from __future__ import annotations

import argparse
import os

from app import mcp

# Importing these modules registers their @mcp.tool/@mcp.resource/@mcp.prompt.
import tools.projects        # noqa: F401
import tools.work_packages   # noqa: F401
import tools.users           # noqa: F401
import tools.metadata        # noqa: F401
import tools.comments        # noqa: F401
import tools.time_entries    # noqa: F401
import resources             # noqa: F401


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenProject MCP server")
    parser.add_argument(
        "--transport",
        choices=["streamable-http", "stdio"],
        default=os.environ.get("TRANSPORT", "streamable-http"),
    )
    args = parser.parse_args()

    if args.transport == "stdio":
        # No HTTP layer -> no per-request token; falls back to the env token.
        mcp.run(transport="stdio")
    else:
        import uvicorn
        from app import TokenCaptureMiddleware

        # Build the ASGI app ourselves so we can wrap it with the middleware that
        # captures each caller's OpenProject token for per-user auth.
        app = mcp.streamable_http_app()
        app.add_middleware(TokenCaptureMiddleware)
        uvicorn.run(
            app,
            host=os.environ.get("HOST", "0.0.0.0"),
            port=int(os.environ.get("PORT", "8000")),
        )


if __name__ == "__main__":
    main()
