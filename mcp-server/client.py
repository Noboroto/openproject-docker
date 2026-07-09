"""Async HTTP client for the OpenProject API v3.

Auth (validated against https://www.openproject.org/docs/api/introduction/):
OpenProject issues an API token (format `opapi-<40 hex>`). It can be sent two
ways with the SAME token value:
  - Bearer:  Authorization: Bearer opapi-...        <- preferred (OPENPROJECT_TOKEN)
  - Basic:   username literally "apikey", token as password  <- legacy fallback

Per-user mode: the connection pool carries NO baked-in credentials. Auth is
resolved per request in `_auth()` — a token bound to the current request (the
caller's own token, captured from request headers into a ContextVar; see
auth.py) wins over the server's env token. This lets one server serve many
users, each acting as themselves. When no request token is present the env
token is used, so the stdio transport and token-configured clients still work.

A single pooled httpx.AsyncClient is created at server startup (lifespan) and
reused across all requests for connection pooling.
"""

from __future__ import annotations

import os
from typing import Any

import httpx

from auth import get_request_token


class OpenProjectError(Exception):
    """Raised when the OpenProject API returns an error response."""

    def __init__(self, status: int, message: str, body: Any = None):
        self.status = status
        self.body = body
        super().__init__(f"OpenProject API {status}: {message}")


class OpenProjectClient:
    def __init__(self) -> None:
        base_url = os.environ.get("OPENPROJECT_URL", "http://web:8080").rstrip("/")
        self._base = f"{base_url}/api/v3"

        # Server-side fallback credentials. Used only when a request supplies no
        # token of its own (stdio transport, or a client configured with a token
        # baked into the server). Per-user requests override these in _auth().
        self._env_token = os.environ.get("OPENPROJECT_TOKEN", "").strip()
        self._legacy = os.environ.get("OPENPROJECT_API_KEY", "").strip()

        # When OpenProject runs with OPENPROJECT_HTTPS=true it 301-redirects any
        # plain-http request to https. op-mcp reaches op-web internally over http
        # (http://op-web:8080), so without a hint every API call gets a 301 that
        # httpx won't follow. Sending X-Forwarded-Proto tells OpenProject the
        # effective external scheme, so it serves the request instead of
        # redirecting. Default "https" matches the usual deployment; set
        # OPENPROJECT_FORWARDED_PROTO to "" to disable (e.g. http-only local OP).
        default_headers: dict[str, str] = {}
        fwd_proto = os.environ.get("OPENPROJECT_FORWARDED_PROTO", "https").strip()
        if fwd_proto:
            default_headers["X-Forwarded-Proto"] = fwd_proto

        # Auth is NOT on the pool — resolved per request so callers act as
        # themselves. Only scheme/transport hints live here.
        self._http = httpx.AsyncClient(
            base_url=self._base,
            headers=default_headers,
            timeout=30.0,
            limits=httpx.Limits(max_connections=10, max_keepalive_connections=5),
        )

    def _auth(self) -> tuple[dict[str, str], tuple[str, str] | None]:
        """Resolve (headers, basic_auth) for the current request.

        Precedence: the per-request token (the caller's own, from their headers)
        beats the server env token, enabling per-user access. The legacy env API
        key uses HTTP Basic and is only a last resort.
        """
        token = get_request_token() or self._env_token
        if token:
            return {"Authorization": f"Bearer {token}"}, None
        if self._legacy:
            return {}, ("apikey", self._legacy)  # HTTP Basic; username is literal "apikey"
        raise OpenProjectError(
            401,
            "No OpenProject credentials. Send your API token via "
            "'X-OpenProject-Token: opapi-...' or 'Authorization: Bearer opapi-...', "
            "or set OPENPROJECT_TOKEN on the server.",
        )

    async def aclose(self) -> None:
        await self._http.aclose()

    @staticmethod
    def _raise(resp: httpx.Response) -> None:
        if resp.is_success:
            return
        body: Any
        try:
            body = resp.json()
            # OpenProject errors are HAL: { message, _embedded.errors[...] }
            msg = body.get("message", resp.text) if isinstance(body, dict) else resp.text
        except Exception:
            body = resp.text
            msg = resp.text
        raise OpenProjectError(resp.status_code, msg, body)

    async def get(self, path: str, **params: Any) -> dict[str, Any]:
        headers, auth = self._auth()
        clean = {k: v for k, v in params.items() if v is not None}
        resp = await self._http.get(path, params=clean, headers=headers, auth=auth)
        self._raise(resp)
        return resp.json()

    async def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        headers, auth = self._auth()
        resp = await self._http.post(path, json=body, headers=headers, auth=auth)
        self._raise(resp)
        return resp.json() if resp.content else {}

    async def patch(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        headers, auth = self._auth()
        resp = await self._http.patch(path, json=body, headers=headers, auth=auth)
        self._raise(resp)
        return resp.json() if resp.content else {}

    async def delete(self, path: str) -> None:
        headers, auth = self._auth()
        resp = await self._http.delete(path, headers=headers, auth=auth)
        self._raise(resp)
