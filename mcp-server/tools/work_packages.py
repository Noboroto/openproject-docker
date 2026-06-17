"""Work package (task) tools: full CRUD + validate-before-write."""

from __future__ import annotations

from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from utils import elements, page_meta, link_title, to_iso_duration


def _summarize(wp: dict[str, Any]) -> dict[str, Any]:
    links = wp.get("_links", {})
    return {
        "id": wp["id"],
        "subject": wp.get("subject"),
        "status": link_title(wp, "status"),
        "type": link_title(wp, "type"),
        "priority": link_title(wp, "priority"),
        "assignee": link_title(wp, "assignee"),
        "project": link_title(wp, "project"),
        "dueDate": wp.get("dueDate"),
        "startDate": wp.get("startDate"),
        "percentageDone": wp.get("percentageDone", 0),
        "lockVersion": wp.get("lockVersion"),
        "_meta": {"hasParent": bool(links.get("parent", {}).get("href"))},
    }


@mcp.tool(annotations={"readOnlyHint": True, "title": "List work packages"})
async def list_work_packages(
    project_id: int | None = None,
    filters: str = "[]",
    page: int = 1,
    page_size: int = 25,
) -> dict[str, Any]:
    """List work packages, globally or scoped to a project.

    project_id: optional; if given, lists that project's WPs.
    filters: JSON array of API v3 filter objects, e.g.
      '[{"status":{"operator":"o","values":[]}}]' (o = open).
    """
    op = get_client()
    path = f"/projects/{project_id}/work_packages" if project_id else "/work_packages"
    try:
        data = await op.get(path, filters=filters, pageSize=page_size, offset=page)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {
        "workPackages": [_summarize(wp) for wp in elements(data)],
        "pagination": page_meta(data, page_size),
    }


@mcp.tool(annotations={"readOnlyHint": True, "title": "Get work package"})
async def get_work_package(work_package_id: int) -> dict[str, Any]:
    """Get a single work package, including description and lockVersion."""
    op = get_client()
    try:
        wp = await op.get(f"/work_packages/{work_package_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    out = _summarize(wp)
    out["description"] = (wp.get("description") or {}).get("raw", "")
    out["author"] = link_title(wp, "author")
    out["estimatedTime"] = wp.get("estimatedTime")
    out["spentTime"] = wp.get("spentTime")
    out["createdAt"] = wp.get("createdAt")
    out["updatedAt"] = wp.get("updatedAt")
    return out


def _build_wp_body(
    subject: str | None,
    type_id: int | None,
    status_id: int | None,
    priority_id: int | None,
    description: str | None,
    assignee_id: int | None,
    parent_id: int | None,
    start_date: str | None,
    due_date: str | None,
    estimated_hours: float | None,
    percent_done: int | None,
) -> dict[str, Any]:
    body: dict[str, Any] = {"_links": {}}
    if subject is not None:
        body["subject"] = subject
    if description is not None:
        body["description"] = {"format": "markdown", "raw": description}
    if start_date is not None:
        body["startDate"] = start_date
    if due_date is not None:
        body["dueDate"] = due_date
    if estimated_hours is not None:
        body["estimatedTime"] = to_iso_duration(estimated_hours)
    if percent_done is not None:
        body["percentageDone"] = percent_done
    links = body["_links"]
    if type_id is not None:
        links["type"] = {"href": f"/api/v3/types/{type_id}"}
    if status_id is not None:
        links["status"] = {"href": f"/api/v3/statuses/{status_id}"}
    if priority_id is not None:
        links["priority"] = {"href": f"/api/v3/priorities/{priority_id}"}
    if assignee_id is not None:
        links["assignee"] = {"href": f"/api/v3/users/{assignee_id}"}
    if parent_id is not None:
        links["parent"] = {"href": f"/api/v3/work_packages/{parent_id}"}
    if not links:
        del body["_links"]
    return body


@mcp.tool(annotations={"readOnlyHint": True, "title": "Validate work package"})
async def validate_work_package(
    project_id: int,
    subject: str,
    type_id: int,
    description: str | None = None,
    status_id: int | None = None,
    priority_id: int | None = None,
    assignee_id: int | None = None,
) -> dict[str, Any]:
    """Dry-run a work package create via the project form endpoint.

    Returns validationErrors (if any) and the list of required fields from the
    schema — call this before create_work_package to catch missing custom fields.
    """
    op = get_client()
    body = _build_wp_body(
        subject, type_id, status_id, priority_id, description,
        assignee_id, None, None, None, None, None,
    )
    try:
        form = await op.post(f"/projects/{project_id}/work_packages/form", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    validation = form.get("_embedded", {}).get("validationErrors", {})
    schema = form.get("_embedded", {}).get("schema", {})
    required = [
        k for k, v in schema.items()
        if isinstance(v, dict) and v.get("required") and v.get("writable")
    ]
    return {
        "valid": not validation,
        "validationErrors": validation,
        "requiredFields": required,
    }


@mcp.tool(annotations={"title": "Create work package"})
async def create_work_package(
    project_id: int,
    subject: str,
    type_id: int,
    description: str | None = None,
    status_id: int | None = None,
    priority_id: int | None = None,
    assignee_id: int | None = None,
    parent_id: int | None = None,
    start_date: str | None = None,
    due_date: str | None = None,
    estimated_hours: float | None = None,
) -> dict[str, Any]:
    """Create a work package. Dates: YYYY-MM-DD. estimated_hours: decimal (1.5)."""
    op = get_client()
    body = _build_wp_body(
        subject, type_id, status_id, priority_id, description,
        assignee_id, parent_id, start_date, due_date, estimated_hours, None,
    )
    try:
        wp = await op.post(f"/projects/{project_id}/work_packages", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return _summarize(wp)


@mcp.tool(annotations={"title": "Update work package"})
async def update_work_package(
    work_package_id: int,
    subject: str | None = None,
    description: str | None = None,
    status_id: int | None = None,
    type_id: int | None = None,
    priority_id: int | None = None,
    assignee_id: int | None = None,
    parent_id: int | None = None,
    start_date: str | None = None,
    due_date: str | None = None,
    estimated_hours: float | None = None,
    percent_done: int | None = None,
    lock_version: int | None = None,
) -> dict[str, Any]:
    """Update a work package. lockVersion is auto-fetched if not provided.

    Only the fields you pass are changed.
    """
    op = get_client()
    try:
        if lock_version is None:
            lock_version = await op.lock_version(work_package_id)
        body = _build_wp_body(
            subject, type_id, status_id, priority_id, description,
            assignee_id, parent_id, start_date, due_date, estimated_hours, percent_done,
        )
        body["lockVersion"] = lock_version
        wp = await op.patch(f"/work_packages/{work_package_id}", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return _summarize(wp)


@mcp.tool(annotations={"destructiveHint": True, "title": "Delete work package"})
async def delete_work_package(work_package_id: int) -> dict[str, Any]:
    """Permanently delete a work package. This cannot be undone."""
    op = get_client()
    try:
        await op.delete(f"/work_packages/{work_package_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {"deleted": True, "id": work_package_id}
