"""User tools."""

from __future__ import annotations

from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from utils import elements, page_meta


@mcp.tool(annotations={"readOnlyHint": True, "title": "List users"})
async def list_users(page: int = 1, page_size: int = 50) -> dict[str, Any]:
    """List users (requires an admin API token for full visibility)."""
    op = get_client()
    try:
        data = await op.get("/users", pageSize=page_size, offset=page)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    users = [
        {
            "id": u["id"],
            "name": u.get("name"),
            "login": u.get("login"),
            "email": u.get("email"),
            "status": u.get("status"),
        }
        for u in elements(data)
    ]
    return {"users": users, "pagination": page_meta(data, page_size)}


@mcp.tool(annotations={"readOnlyHint": True, "title": "Get user"})
async def get_user(user_id: int | None = None) -> dict[str, Any]:
    """Get a user by id. Omit user_id to get the token's own account ('me')."""
    op = get_client()
    ident = user_id if user_id is not None else "me"
    try:
        u = await op.get(f"/users/{ident}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {
        "id": u["id"],
        "name": u.get("name"),
        "login": u.get("login"),
        "email": u.get("email"),
        "admin": u.get("admin"),
        "status": u.get("status"),
    }
