"""Time entry tools: list/create/update/delete."""

from __future__ import annotations

import json
from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from utils import elements, page_meta, link_title, to_iso_duration


@mcp.tool(annotations={"readOnlyHint": True, "title": "List time entries"})
async def list_time_entries(
    project_id: int | None = None,
    user_id: int | None = None,
    work_package_id: int | None = None,
    from_date: str | None = None,
    to_date: str | None = None,
    page: int = 1,
    page_size: int = 50,
) -> dict[str, Any]:
    """List time entries, optionally filtered. Dates: YYYY-MM-DD."""
    op = get_client()
    filters: list[dict[str, Any]] = []
    if project_id:
        filters.append({"project": {"operator": "=", "values": [str(project_id)]}})
    if user_id:
        filters.append({"user": {"operator": "=", "values": [str(user_id)]}})
    if work_package_id:
        filters.append({"workPackage": {"operator": "=", "values": [str(work_package_id)]}})
    if from_date:
        filters.append({"spentOn": {"operator": "<>d", "values": [from_date, to_date or from_date]}})
    try:
        data = await op.get(
            "/time_entries",
            filters=json.dumps(filters) if filters else None,
            pageSize=page_size,
            offset=page,
        )
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    entries = [
        {
            "id": e["id"],
            "hours": e.get("hours"),
            "spentOn": e.get("spentOn"),
            "comment": (e.get("comment") or {}).get("raw", ""),
            "user": link_title(e, "user"),
            "project": link_title(e, "project"),
            "workPackage": link_title(e, "workPackage"),
            "activity": link_title(e, "activity"),
        }
        for e in elements(data)
    ]
    return {"timeEntries": entries, "pagination": page_meta(data, page_size)}


@mcp.tool(annotations={"title": "Create time entry"})
async def create_time_entry(
    hours: float,
    spent_on: str,
    activity_id: int,
    project_id: int | None = None,
    work_package_id: int | None = None,
    comment: str = "",
) -> dict[str, Any]:
    """Log time. Provide project_id or work_package_id (WP implies its project).

    hours: decimal (1.5 = 1h30m). spent_on: YYYY-MM-DD.
    """
    op = get_client()
    if not project_id and not work_package_id:
        return {"error": "Provide project_id or work_package_id"}
    body: dict[str, Any] = {
        "hours": to_iso_duration(hours),
        "spentOn": spent_on,
        "comment": {"format": "plain", "raw": comment},
        "_links": {"activity": {"href": f"/api/v3/time_entries/activities/{activity_id}"}},
    }
    if project_id:
        body["_links"]["project"] = {"href": f"/api/v3/projects/{project_id}"}
    if work_package_id:
        body["_links"]["workPackage"] = {"href": f"/api/v3/work_packages/{work_package_id}"}
    try:
        entry = await op.post("/time_entries", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {"id": entry["id"], "hours": entry.get("hours"), "spentOn": entry.get("spentOn")}


@mcp.tool(annotations={"title": "Update time entry"})
async def update_time_entry(
    time_entry_id: int,
    hours: float | None = None,
    spent_on: str | None = None,
    comment: str | None = None,
    activity_id: int | None = None,
) -> dict[str, Any]:
    """Update an existing time entry. Only passed fields change."""
    op = get_client()
    body: dict[str, Any] = {"_links": {}}
    if hours is not None:
        body["hours"] = to_iso_duration(hours)
    if spent_on is not None:
        body["spentOn"] = spent_on
    if comment is not None:
        body["comment"] = {"format": "plain", "raw": comment}
    if activity_id is not None:
        body["_links"]["activity"] = {"href": f"/api/v3/time_entries/activities/{activity_id}"}
    if not body["_links"]:
        del body["_links"]
    try:
        entry = await op.patch(f"/time_entries/{time_entry_id}", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {"id": entry["id"], "hours": entry.get("hours"), "spentOn": entry.get("spentOn")}


@mcp.tool(annotations={"destructiveHint": True, "title": "Delete time entry"})
async def delete_time_entry(time_entry_id: int) -> dict[str, Any]:
    """Permanently delete a time entry."""
    op = get_client()
    try:
        await op.delete(f"/time_entries/{time_entry_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {"deleted": True, "id": time_entry_id}
