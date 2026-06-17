"""Lookup tools: types, statuses, priorities. Cached 5 min (rarely change)."""

from __future__ import annotations

from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from utils import elements, lookup_cache


async def _cached(key: str, path: str) -> list[dict[str, Any]] | dict[str, Any]:
    if key in lookup_cache:
        return lookup_cache[key]
    op = get_client()
    try:
        data = await op.get(path)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    rows = elements(data)
    lookup_cache[key] = rows
    return rows


@mcp.tool(annotations={"readOnlyHint": True, "title": "List types"})
async def list_types(project_id: int | None = None) -> dict[str, Any]:
    """List work package types (Task, Bug, ...). Optionally scoped to a project."""
    path = f"/projects/{project_id}/types" if project_id else "/types"
    key = f"types:{project_id or 'all'}"
    rows = await _cached(key, path)
    if isinstance(rows, dict):
        return rows
    return {"types": [{"id": t["id"], "name": t.get("name"), "color": t.get("color")} for t in rows]}


@mcp.tool(annotations={"readOnlyHint": True, "title": "List statuses"})
async def list_statuses() -> dict[str, Any]:
    """List all work package statuses."""
    rows = await _cached("statuses", "/statuses")
    if isinstance(rows, dict):
        return rows
    return {
        "statuses": [
            {"id": s["id"], "name": s.get("name"),
             "isClosed": s.get("isClosed", False), "isDefault": s.get("isDefault", False)}
            for s in rows
        ]
    }


@mcp.tool(annotations={"readOnlyHint": True, "title": "List priorities"})
async def list_priorities() -> dict[str, Any]:
    """List all work package priorities."""
    rows = await _cached("priorities", "/priorities")
    if isinstance(rows, dict):
        return rows
    return {
        "priorities": [
            {"id": p["id"], "name": p.get("name"), "isDefault": p.get("isDefault", False)}
            for p in rows
        ]
    }


@mcp.tool(annotations={"readOnlyHint": True, "title": "List time entry activities"})
async def list_time_entry_activities() -> dict[str, Any]:
    """List time-entry activities (Development, Management, ...) for logging time."""
    rows = await _cached("tea", "/time_entries/activities")
    if isinstance(rows, dict):
        return rows
    return {"activities": [{"id": a["id"], "name": a.get("name")} for a in rows]}
