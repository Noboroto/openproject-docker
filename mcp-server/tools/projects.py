"""Project tools."""

from __future__ import annotations

import json
from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from scope import check_project, resolve_scope
from utils import elements, page_meta


@mcp.tool(annotations={"readOnlyHint": True, "title": "List projects"})
async def list_projects(page: int = 1, page_size: int = 25) -> dict[str, Any]:
    """List projects the API token can access (only the scoped one when scoped).

    page: 1-based page index. page_size: rows per page (max 100).
    Returns {projects: [...], pagination: {...}}.
    """
    op = get_client()
    scoped, err = await resolve_scope(op)
    if err:
        return err
    filters = None
    if scoped is not None:
        filters = json.dumps([{"id": {"operator": "=", "values": [str(scoped)]}}])
    try:
        data = await op.get("/projects", filters=filters, pageSize=page_size, offset=page)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    projects = [
        {
            "id": p["id"],
            "identifier": p.get("identifier"),
            "name": p.get("name"),
            "active": p.get("active", True),
            "public": p.get("public", False),
        }
        for p in elements(data)
    ]
    return {"projects": projects, "pagination": page_meta(data, page_size)}


@mcp.tool(annotations={"readOnlyHint": True, "title": "Get project"})
async def get_project(project_id: int) -> dict[str, Any]:
    """Get a single project by numeric id."""
    op = get_client()
    if denied := await check_project(op, project_id):
        return denied
    try:
        p = await op.get(f"/projects/{project_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {
        "id": p["id"],
        "identifier": p.get("identifier"),
        "name": p.get("name"),
        "description": (p.get("description") or {}).get("raw", ""),
        "active": p.get("active", True),
        "public": p.get("public", False),
        "createdAt": p.get("createdAt"),
        "updatedAt": p.get("updatedAt"),
    }
