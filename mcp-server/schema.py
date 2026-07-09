"""Schema-driven work package payload building.

OpenProject decides per project+type which work package fields exist and which
are writable. `storyPoints`, for instance, only appears when the project has the
backlogs module enabled — it is absent from every type of a plain project, so
sending it there is a 422. Custom fields (`customField3`, ...) are likewise
defined per project/type.

Rather than hardcode a field whitelist, we read the live schema at
`/work_packages/schemas/{project_id}-{type_id}` and build the payload from it:

  - a field missing from the schema, or present but not writable, is DROPPED and
    reported back to the caller as a warning — one bad field no longer fails the
    whole write;
  - the schema tells us where each field goes. Entries carrying
    `"location": "_links"` (responsible, category, version, assignee, custom
    fields of type User/Version/list) belong under `_links` as `{"href": ...}`;
    everything else is a plain top-level attribute. That rule is generic, so
    custom fields work without any per-field code.

Schemas are cached briefly — they change only when an admin edits a type.
"""

from __future__ import annotations

from typing import Any

from client import OpenProjectClient, OpenProjectError
from utils import schema_cache

# schema `type` -> API v3 collection used to build an href from a numeric id.
LINK_ENDPOINTS: dict[str, str] = {
    "User": "users",
    "Group": "groups",
    "PlaceholderUser": "placeholder_users",
    "Category": "categories",
    "Version": "versions",
    "Status": "statuses",
    "Priority": "priorities",
    "Type": "types",
    "Project": "projects",
    "WorkPackage": "work_packages",
    "ListOptionalValue": "custom_options",
    "CustomOption": "custom_options",
}


def _rel(href: str) -> str:
    """Strip the /api/v3 prefix — the http client already has it as base_url."""
    return href[len("/api/v3"):] if href.startswith("/api/v3") else href


def _is_field(spec: Any) -> bool:
    """Schema payloads mix field specs with plain metadata keys (_type, _links)."""
    return isinstance(spec, dict) and "type" in spec


def _href(field_type: str, value: Any) -> str | None:
    """Resolve a link value to an href.

    An int is turned into a collection href using the field's schema type; a str
    is assumed to already be an href (lets callers address groups or placeholder
    users, which share the `User` schema type but not its endpoint).
    """
    if isinstance(value, str):
        return value
    endpoint = LINK_ENDPOINTS.get(field_type)
    if endpoint is None:
        return None
    return f"/api/v3/{endpoint}/{value}"


async def fetch_schema(op: OpenProjectClient, path: str) -> dict[str, Any] | None:
    """GET a work package schema, cached. Returns None if it cannot be read."""
    path = _rel(path)
    if path in schema_cache:
        return schema_cache[path]
    try:
        data = await op.get(path)
    except OpenProjectError:
        return None
    schema_cache[path] = data
    return data


async def schema_for(
    op: OpenProjectClient, project_id: int, type_id: int
) -> dict[str, Any] | None:
    """Schema for a (project, type) pair — the create/validate case."""
    return await fetch_schema(op, f"/work_packages/schemas/{project_id}-{type_id}")


async def schema_for_wp(
    op: OpenProjectClient, wp: dict[str, Any]
) -> dict[str, Any] | None:
    """Schema for an existing work package, via its own _links.schema href."""
    href = (wp.get("_links", {}).get("schema") or {}).get("href")
    return await fetch_schema(op, href) if href else None


def build_body(
    schema: dict[str, Any] | None,
    fields: dict[str, Any],
) -> tuple[dict[str, Any], list[dict[str, str]]]:
    """Build a work package payload, dropping fields the schema rejects.

    `fields` maps schema keys to already-normalized values (durations as ISO
    strings, descriptions as {format, raw}, links as an int id or an href).
    Values that are None are skipped: "not supplied", never "set to null".

    Returns (body, warnings). Each warning names the dropped field and why, so
    the agent can retry or tell the user, instead of the whole write failing.
    """
    body: dict[str, Any] = {}
    links: dict[str, Any] = {}
    warnings: list[dict[str, str]] = []

    for key, value in fields.items():
        if value is None:
            continue

        if schema is None:
            # Schema unreadable — fall back to sending the field as-is rather
            # than silently dropping data the user explicitly asked us to set.
            body[key] = value
            continue

        spec = schema.get(key)
        if not _is_field(spec):
            warnings.append({
                "field": key,
                "reason": (
                    "not available for this project/type — the field does not "
                    "exist here (module disabled, or not enabled on this type). "
                    "It was skipped; other fields were applied."
                ),
            })
            continue

        if not spec.get("writable", False):
            warnings.append({
                "field": key,
                "reason": (
                    f"read-only for this user on {spec.get('name', key)!r}. "
                    "It was skipped; other fields were applied."
                ),
            })
            continue

        if spec.get("location") == "_links":
            href = _href(spec.get("type", ""), value)
            if href is None:
                warnings.append({
                    "field": key,
                    "reason": (
                        f"cannot build a link for schema type {spec.get('type')!r} "
                        "from a numeric id; pass a full href instead. It was skipped."
                    ),
                })
                continue
            links[key] = {"href": href}
        else:
            body[key] = value

    if schema is None and fields:
        warnings.append({
            "field": "*",
            "reason": "schema could not be read; fields were sent unvalidated.",
        })

    if links:
        body["_links"] = links
    return body, warnings


def writable_fields(schema: dict[str, Any]) -> list[dict[str, Any]]:
    """Every writable field in a schema — what the agent may actually set."""
    out = []
    for key, spec in schema.items():
        if not _is_field(spec) or not spec.get("writable"):
            continue
        out.append({
            "key": key,
            "name": spec.get("name"),
            "type": spec.get("type"),
            "required": bool(spec.get("required")),
            "isLink": spec.get("location") == "_links",
        })
    return sorted(out, key=lambda f: f["key"])
