"""Async HTTP client for the OpenProject API v3.

Auth (validated against https://www.openproject.org/docs/api/introduction/):
OpenProject issues an API token (format `opapi-<40 hex>`). It can be sent two
ways with the SAME token value:
  - Bearer:  Authorization: Bearer opapi-...        <- preferred (OPENPROJECT_TOKEN)
  - Basic:   username literally "apikey", token as password  <- legacy fallback

A single pooled httpx.AsyncClient is created at server startup (lifespan) and
reused across all requests for connection pooling.
"""

from __future__ import annotations

import os
from typing import Any

import httpx


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

        token = os.environ.get("OPENPROJECT_TOKEN", "").strip()
        legacy = os.environ.get("OPENPROJECT_API_KEY", "").strip()

        auth: tuple[str, str] | None = None
        headers: dict[str, str] = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        elif legacy:
            auth = ("apikey", legacy)  # HTTP Basic; username is literal "apikey"
        else:
            raise RuntimeError(
                "Set OPENPROJECT_TOKEN (API token, preferred) or OPENPROJECT_API_KEY"
            )

        self._http = httpx.AsyncClient(
            base_url=self._base,
            auth=auth,
            headers=headers,
            timeout=30.0,
            limits=httpx.Limits(max_connections=10, max_keepalive_connections=5),
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
        clean = {k: v for k, v in params.items() if v is not None}
        resp = await self._http.get(path, params=clean)
        self._raise(resp)
        return resp.json()

    async def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        resp = await self._http.post(path, json=body)
        self._raise(resp)
        return resp.json() if resp.content else {}

    async def patch(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        resp = await self._http.patch(path, json=body)
        self._raise(resp)
        return resp.json() if resp.content else {}

    async def delete(self, path: str) -> None:
        resp = await self._http.delete(path)
        self._raise(resp)

    async def lock_version(self, work_package_id: int) -> int:
        """Fetch current lockVersion for a WP (required before PATCH)."""
        wp = await self.get(f"/work_packages/{work_package_id}")
        return wp["lockVersion"]
