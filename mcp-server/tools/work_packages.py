"""Work package (task) tools: full CRUD + validate-before-write.

Writable fields are resolved against the live OpenProject schema for the target
project+type (see schema.py), so a field that does not exist there — e.g.
`storyPoints` on a project without the backlogs module — is skipped with a
warning instead of failing the entire write.
"""

from __future__ import annotations

from typing import Any

from app import mcp, get_client
from client import OpenProjectError
from schema import build_body, schema_for, schema_for_wp, writable_fields
from utils import elements, page_meta, link_id, link_title, to_iso_duration


def _summarize(wp: dict[str, Any]) -> dict[str, Any]:
    links = wp.get("_links", {})
    return {
        "id": wp["id"],
        "subject": wp.get("subject"),
        "status": link_title(wp, "status"),
        "type": link_title(wp, "type"),
        "priority": link_title(wp, "priority"),
        "assignee": link_title(wp, "assignee"),
        "accountable": link_title(wp, "responsible"),
        "category": link_title(wp, "category"),
        "version": link_title(wp, "version"),
        "storyPoints": wp.get("storyPoints"),
        "project": link_title(wp, "project"),
        "dueDate": wp.get("dueDate"),
        "startDate": wp.get("startDate"),
        "percentageDone": wp.get("percentageDone", 0),
        "lockVersion": wp.get("lockVersion"),
        "_meta": {"hasParent": bool(links.get("parent", {}).get("href"))},
    }


def _fields(
    subject: str | None = None,
    type_id: int | None = None,
    status_id: int | None = None,
    priority_id: int | None = None,
    description: str | None = None,
    assignee_id: int | None = None,
    accountable_id: int | None = None,
    category_id: int | None = None,
    version_id: int | None = None,
    parent_id: int | None = None,
    start_date: str | None = None,
    due_date: str | None = None,
    estimated_hours: float | None = None,
    remaining_hours: float | None = None,
    story_points: int | None = None,
    percent_done: int | None = None,
    custom_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Map tool arguments onto schema keys with normalized values.

    Link fields carry a bare id here; build_body turns them into hrefs once the
    schema says where each belongs. `responsible` is the API name for the field
    OpenProject's UI labels "Accountable".
    """
    fields: dict[str, Any] = {
        "subject": subject,
        "startDate": start_date,
        "dueDate": due_date,
        "percentageDone": percent_done,
        "storyPoints": story_points,
        "type": type_id,
        "status": status_id,
        "priority": priority_id,
        "assignee": assignee_id,
        "responsible": accountable_id,
        "category": category_id,
        "version": version_id,
        "parent": parent_id,
    }
    if description is not None:
        fields["description"] = {"format": "markdown", "raw": description}
    if estimated_hours is not None:
        fields["estimatedTime"] = to_iso_duration(estimated_hours)
    if remaining_hours is not None:
        fields["remainingTime"] = to_iso_duration(remaining_hours)
    if custom_fields:
        fields.update(custom_fields)
    return fields


def _result(wp: dict[str, Any], warnings: list[dict[str, str]]) -> dict[str, Any]:
    out = _summarize(wp)
    if warnings:
        out["warnings"] = warnings
    return out


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
    out["remainingTime"] = wp.get("remainingTime")
    out["spentTime"] = wp.get("spentTime")
    out["createdAt"] = wp.get("createdAt")
    out["updatedAt"] = wp.get("updatedAt")
    out["customFields"] = {
        k: v for k, v in wp.items() if k.startswith("customField")
    }
    return out


@mcp.tool(annotations={"readOnlyHint": True, "title": "List writable fields"})
async def list_work_package_fields(project_id: int, type_id: int) -> dict[str, Any]:
    """List every field settable on a work package of this project + type.

    Use this when a field was skipped with a warning, or before setting an
    unusual/custom field — it reflects the live schema, so it accounts for
    disabled modules (storyPoints needs backlogs) and project custom fields.
    Pass the returned `key` values via create/update_work_package's
    `custom_fields` argument for anything without a dedicated parameter.
    """
    op = get_client()
    schema = await schema_for(op, project_id, type_id)
    if schema is None:
        return {"error": f"No schema for project {project_id} / type {type_id}."}
    return {"fields": writable_fields(schema)}


@mcp.tool(annotations={"readOnlyHint": True, "title": "Validate work package"})
async def validate_work_package(
    project_id: int,
    subject: str,
    type_id: int,
    description: str | None = None,
    status_id: int | None = None,
    priority_id: int | None = None,
    assignee_id: int | None = None,
    accountable_id: int | None = None,
    category_id: int | None = None,
    version_id: int | None = None,
    story_points: int | None = None,
    custom_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Dry-run a work package create via the project form endpoint.

    Returns validationErrors (if any), the required fields from the schema, and
    warnings for any field that does not exist on this project/type.
    """
    op = get_client()
    schema = await schema_for(op, project_id, type_id)
    body, warnings = build_body(
        schema,
        _fields(
            subject=subject, type_id=type_id, status_id=status_id,
            priority_id=priority_id, description=description,
            assignee_id=assignee_id, accountable_id=accountable_id,
            category_id=category_id, version_id=version_id,
            story_points=story_points, custom_fields=custom_fields,
        ),
    )
    try:
        form = await op.post(f"/projects/{project_id}/work_packages/form", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    validation = form.get("_embedded", {}).get("validationErrors", {})
    form_schema = form.get("_embedded", {}).get("schema", {})
    required = [
        k for k, v in form_schema.items()
        if isinstance(v, dict) and v.get("required") and v.get("writable")
    ]
    out: dict[str, Any] = {
        "valid": not validation,
        "validationErrors": validation,
        "requiredFields": required,
    }
    if warnings:
        out["warnings"] = warnings
    return out


@mcp.tool(annotations={"title": "Create work package"})
async def create_work_package(
    project_id: int,
    subject: str,
    type_id: int,
    description: str | None = None,
    status_id: int | None = None,
    priority_id: int | None = None,
    assignee_id: int | None = None,
    accountable_id: int | None = None,
    category_id: int | None = None,
    version_id: int | None = None,
    parent_id: int | None = None,
    start_date: str | None = None,
    due_date: str | None = None,
    estimated_hours: float | None = None,
    remaining_hours: float | None = None,
    story_points: int | None = None,
    custom_fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a work package. Dates: YYYY-MM-DD. estimated_hours: decimal (1.5).

    accountable_id sets the field the UI calls "Accountable". story_points needs
    the backlogs module; category_id/version_id are project-scoped (see
    list_categories / list_versions). custom_fields takes raw schema keys, e.g.
    {"customField3": 5} — see list_work_package_fields.

    Fields absent from this project/type's schema are skipped and reported under
    `warnings` rather than failing the create.
    """
    op = get_client()
    schema = await schema_for(op, project_id, type_id)
    body, warnings = build_body(
        schema,
        _fields(
            subject=subject, type_id=type_id, status_id=status_id,
            priority_id=priority_id, description=description,
            assignee_id=assignee_id, accountable_id=accountable_id,
            category_id=category_id, version_id=version_id, parent_id=parent_id,
            start_date=start_date, due_date=due_date,
            estimated_hours=estimated_hours, remaining_hours=remaining_hours,
            story_points=story_points, custom_fields=custom_fields,
        ),
    )
    try:
        wp = await op.post(f"/projects/{project_id}/work_packages", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body, "warnings": warnings}
    return _result(wp, warnings)


@mcp.tool(annotations={"title": "Update work package"})
async def update_work_package(
    work_package_id: int,
    subject: str | None = None,
    description: str | None = None,
    status_id: int | None = None,
    type_id: int | None = None,
    priority_id: int | None = None,
    assignee_id: int | None = None,
    accountable_id: int | None = None,
    category_id: int | None = None,
    version_id: int | None = None,
    parent_id: int | None = None,
    start_date: str | None = None,
    due_date: str | None = None,
    estimated_hours: float | None = None,
    remaining_hours: float | None = None,
    story_points: int | None = None,
    percent_done: int | None = None,
    custom_fields: dict[str, Any] | None = None,
    lock_version: int | None = None,
) -> dict[str, Any]:
    """Update a work package. lockVersion is auto-fetched if not provided.

    Only the fields you pass are changed. accountable_id sets "Accountable".
    Fields absent from this work package's schema (e.g. story_points on a
    project without backlogs) are skipped and reported under `warnings` rather
    than failing the whole update.
    """
    op = get_client()
    try:
        current = await op.get(f"/work_packages/{work_package_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}

    # Changing the type changes the schema, so validate against the target type.
    if type_id is not None:
        project_id = link_id(current, "project")
        schema = (
            await schema_for(op, project_id, type_id)
            if project_id is not None
            else await schema_for_wp(op, current)
        )
    else:
        schema = await schema_for_wp(op, current)

    body, warnings = build_body(
        schema,
        _fields(
            subject=subject, type_id=type_id, status_id=status_id,
            priority_id=priority_id, description=description,
            assignee_id=assignee_id, accountable_id=accountable_id,
            category_id=category_id, version_id=version_id, parent_id=parent_id,
            start_date=start_date, due_date=due_date,
            estimated_hours=estimated_hours, remaining_hours=remaining_hours,
            story_points=story_points, percent_done=percent_done,
            custom_fields=custom_fields,
        ),
    )
    body["lockVersion"] = lock_version if lock_version is not None else current["lockVersion"]
    try:
        wp = await op.patch(f"/work_packages/{work_package_id}", body)
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body, "warnings": warnings}
    return _result(wp, warnings)


@mcp.tool(annotations={"destructiveHint": True, "title": "Delete work package"})
async def delete_work_package(work_package_id: int) -> dict[str, Any]:
    """Permanently delete a work package. This cannot be undone."""
    op = get_client()
    try:
        await op.delete(f"/work_packages/{work_package_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return {"deleted": True, "id": work_package_id}
