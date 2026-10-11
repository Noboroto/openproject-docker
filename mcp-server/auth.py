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

Project scope: a request may also carry `X-OpenProject-Project: <identifier or
id>`. Tools then refuse anything outside that project (see scope.py). It only
narrows what the caller's token could already do; it never grants access.
`OPENPROJECT_PROJECT` sets the same limit server-side (e.g. for stdio).
"""

from __future__ import annotations

import contextvars
import os
from typing import Mapping

# Token supplied by the current request; None -> fall back to the env token.
_request_token: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "openproject_request_token", default=None
)

# Project the current request is limited to; None -> fall back to the env value.
_request_project: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "openproject_request_project", default=None
)


def set_request_token(token: str | None) -> contextvars.Token:
    """Bind the token for the current request; returns a reset marker."""
    return _request_token.set(token or None)


def reset_request_token(marker: contextvars.Token) -> None:
    _request_token.reset(marker)


def get_request_token() -> str | None:
    return _request_token.get()


def set_request_project(project: str | None) -> contextvars.Token:
    """Bind the project scope for the current request; returns a reset marker.

    None means the request sent no header. An empty string means it sent one
    with no value, which is kept so scope.py refuses it instead of running
    unscoped (e.g. a client config whose variable was never set).
    """
    return _request_project.set(project)


def reset_request_project(marker: contextvars.Token) -> None:
    _request_project.reset(marker)


def get_project_scope() -> str | None:
    """Project identifier/id this request is limited to, or None for no limit.

    The header wins over OPENPROJECT_PROJECT only when they agree; scope.py
    refuses a header that asks for a different project than the server's.
    """
    header = _request_project.get()
    if header is not None:
        return header.strip()
    env = os.environ.get("OPENPROJECT_PROJECT", "").strip()
    return env or None


def extract_project(headers: Mapping[str, str]) -> str | None:
    """Header value, stripped; "" when sent empty; None when absent."""
    value = headers.get("x-openproject-project")
    return None if value is None else value.strip()


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
