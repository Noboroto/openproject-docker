"""Per-request OpenProject credential resolution (per-user mode).

A single MCP server process can serve many users. Instead of a fixed
server-side token, each incoming HTTP request may carry the caller's own
OpenProject API token; we stash it in a ContextVar for the duration of the
request so the shared client can act as that user WITHOUT threading auth
through every tool signature.

Header precedence (see `extract_token`):
  1. `X-OpenProject-Token: opapi-...`   — explicit, avoids clashing with any
     OAuth handling an MCP client may apply to `Authorization`.
  2. `Authorization: Bearer opapi-...`  — standard bearer.

When no request token is present (e.g. the stdio transport, or a client
configured without one), the client falls back to the server's env token.
"""

from __future__ import annotations

import contextvars
from typing import Mapping

# Token supplied by the current request; None -> fall back to the env token.
_request_token: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "openproject_request_token", default=None
)


def set_request_token(token: str | None) -> contextvars.Token:
    """Bind the token for the current request; returns a reset marker."""
    return _request_token.set(token or None)


def reset_request_token(marker: contextvars.Token) -> None:
    _request_token.reset(marker)


def get_request_token() -> str | None:
    return _request_token.get()


def extract_token(headers: Mapping[str, str]) -> str | None:
    """Pull an OpenProject API token from case-insensitive request headers."""
    explicit = headers.get("x-openproject-token")
    if explicit and explicit.strip():
        return explicit.strip()

    authz = headers.get("authorization") or ""
    if authz.strip().lower().startswith("bearer "):
        token = authz.strip()[len("bearer "):].strip()
        if token:
            return token
    return None
