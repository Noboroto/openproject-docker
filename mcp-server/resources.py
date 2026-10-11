"""MCP Resources + Prompts (read-only context helpers)."""

from __future__ import annotations

import json

from app import mcp, get_client
from scope import check_resource, scoped_project_id
from utils import elements


@mcp.resource("openproject://projects")
async def projects_resource() -> str:
    """All accessible projects as JSON (only the scoped one when scoped)."""
    op = get_client()
    scoped = await scoped_project_id(op)
    filters = (
        json.dumps([{"id": {"operator": "=", "values": [str(scoped)]}}]) if scoped is not None else None
    )
    data = await op.get("/projects", filters=filters, pageSize=100)
    rows = [{"id": p["id"], "identifier": p.get("identifier"), "name": p.get("name")}
            for p in elements(data)]
    return json.dumps(rows, indent=2)


@mcp.resource("openproject://work_packages/{work_package_id}")
async def work_package_resource(work_package_id: str) -> str:
    """A single work package as JSON (read-only context)."""
    op = get_client()
    wp = await op.get(f"/work_packages/{work_package_id}")
    if denied := await check_resource(op, wp, f"work package {work_package_id}"):
        raise PermissionError(denied["error"])
    return json.dumps(wp, indent=2)


@mcp.prompt()
def weekly_time_report(project_id: int, from_date: str, to_date: str) -> str:
    """Prompt: summarize a project's time entries for a date range."""
    return (
        f"List time entries for project {project_id} from {from_date} to {to_date} "
        f"using list_time_entries, then summarize total hours per user and per "
        f"work package as a concise table."
    )


@mcp.prompt()
def sprint_backlog(project_id: int) -> str:
    """Prompt: build a sprint backlog from open work packages."""
    return (
        f"List open work packages in project {project_id} (filters "
        f'\'[{{"status":{{"operator":"o","values":[]}}}}]\'), group by type, and '
        f"propose a prioritized sprint backlog with estimates."
    )
