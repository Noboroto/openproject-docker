"""Work package comment (activity) tools."""

from __future__ import annotations

from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from utils import elements


@mcp.tool(annotations={"readOnlyHint": True, "title": "List comments"})
async def list_comments(work_package_id: int) -> dict[str, Any]:
    """List activities/comments on a work package."""
    op = get_client()
    try:
        data = await op.get(f"/work_packages/{work_package_id}/activities")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    comments = []
    for a in elements(data):
        raw = (a.get("comment") or {}).get("raw", "")
        if not raw:
            continue
        comments.append({
            "id": a["id"],
            "comment": raw,
            "user": (a.get("_links", {}).get("user") or {}).get("title"),
            "createdAt": a.get("createdAt"),
            "version": a.get("version"),
        })
    return {"comments": comments}


@mcp.tool(annotations={"title": "Create comment"})
async def create_comment(work_package_id: int, comment: str) -> dict[str, Any]:
    """Add a comment to a work package (markdown supported)."""
    op = get_client()
    body = {"comment": {"format": "markdown", "raw": comment}}
    try:
        result = await op.post(f"/work_packages/{work_package_id}/activities", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {
        "id": result.get("id"),
        "comment": (result.get("comment") or {}).get("raw"),
        "createdAt": result.get("createdAt"),
    }
