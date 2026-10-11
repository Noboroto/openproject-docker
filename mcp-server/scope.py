"""Optional per-request project scope (`X-OpenProject-Project`).

When a request names a project, every tool must stay inside it. This is a
guard rail for agents that work on one project; the real permission boundary is
still the caller's own OpenProject role, which the API enforces regardless.

Each check returns None when the call may proceed, or an error dict the tool
returns unchanged — the same shape tools already use for API errors. Anything
that cannot be resolved (blank header, malformed value, unknown project, header
disagreeing with the server's OPENPROJECT_PROJECT) refuses rather than running
unscoped.

Users, statuses, priorities and global types are instance-wide in OpenProject,
so they are not project data and stay readable while scoped.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from typing import Any

from cachetools import TTLCache

from auth import get_project_scope, get_request_token
from client import OpenProjectClient, OpenProjectError
from utils import link_id

# A project identifier (lowercase slug) or a numeric id. Anything else — notably
# path fragments like "../work_packages/5" — never reaches the URL.
_SCOPE_RE = re.compile(r"^(\d+|[a-z][a-z0-9_-]*)$")

# (caller, scope) -> numeric project id. Keyed per caller so one user's lookup
# never answers for another user who cannot see that project.
_scope_ids: TTLCache = TTLCache(maxsize=128, ttl=300)


class ScopeError(Exception):
    pass


def _caller_key() -> str:
    token = get_request_token() or os.environ.get("OPENPROJECT_TOKEN", "")
    return hashlib.sha256(token.encode()).hexdigest()[:16]


def _refusal(what: str) -> dict[str, Any]:
    return {
        "error": (
            f"Out of scope: this session is limited to project '{get_project_scope()}' "
            f"(X-OpenProject-Project); {what} is outside it."
        )
    }


async def scoped_project_id(op: OpenProjectClient) -> int | None:
    """Numeric id of the scoped project, or None when the request is unscoped.

    Raises ScopeError / OpenProjectError when the scope cannot be resolved, so a
    misconfigured scope fails closed.
    """
    scope = get_project_scope()
    if scope is None:
        return None
    env_scope = os.environ.get("OPENPROJECT_PROJECT", "").strip()
    if env_scope and scope != env_scope:
        raise ScopeError(f"header asks for '{scope}' but the server is limited to '{env_scope}'")
    if not _SCOPE_RE.match(scope):
        raise ScopeError("expected a project identifier or numeric id")
    key = (_caller_key(), scope)
    if key not in _scope_ids:
        project = await op.get(f"/projects/{scope}")
        if project.get("_type") != "Project" or "id" not in project:
            raise ScopeError("it does not name a project")
        _scope_ids[key] = int(project["id"])
    return _scope_ids[key]


async def resolve_scope(op: OpenProjectClient) -> tuple[int | None, dict[str, Any] | None]:
    """(scoped project id, error) — error is set when the scope cannot be resolved."""
    try:
        return await scoped_project_id(op), None
    except (OpenProjectError, ScopeError) as e:
        return None, {
            "error": (
                f"Project scope '{get_project_scope()}' (X-OpenProject-Project) "
                f"cannot be used: {e}"
            ),
            "details": getattr(e, "body", None),
        }


async def check_project(op: OpenProjectClient, project_id: int | None) -> dict[str, Any] | None:
    scoped, err = await resolve_scope(op)
    if err:
        return err
    if scoped is None or project_id is None or int(project_id) == scoped:
        return None
    return _refusal(f"project {project_id}")


async def check_resource(op: OpenProjectClient, resource: dict[str, Any], what: str) -> dict[str, Any] | None:
    """Check an already-fetched HAL resource (work package, time entry) by its project link."""
    scoped, err = await resolve_scope(op)
    if err:
        return err
    if scoped is None or link_id(resource, "project") == scoped:
        return None
    return _refusal(what)


async def check_work_package(op: OpenProjectClient, work_package_id: int | None) -> dict[str, Any] | None:
    """Fetch a work package only when scoped, and check which project it is in."""
    if work_package_id is None or get_project_scope() is None:
        return None
    try:
        wp = await op.get(f"/work_packages/{work_package_id}")
    except OpenProjectError as e:
        return {"error": str(e), "details": e.body}
    return await check_resource(op, wp, f"work package {work_package_id}")


async def check_write_body(op: OpenProjectClient, body: dict[str, Any]) -> dict[str, Any] | None:
    """Check the project and parent links of the final write body.

    Tool arguments are not enough: `custom_fields` can carry `project` or
    `parent` straight into `_links`, so the body that is about to be sent is
    what gets checked.
    """
    if get_project_scope() is None:
        return None
    links = body.get("_links") or {}
    project = links.get("project")
    if project is not None:
        project_id = link_id({"_links": {"project": project}}, "project")
        if project_id is None:
            # An identifier href or anything else that is not a numeric id is refused.
            return _refusal(f"project {(project or {}).get('href')}")
        if denied := await check_project(op, project_id):
            return denied
    parent = links.get("parent")
    if parent is not None and parent.get("href"):
        parent_id = link_id({"_links": {"parent": parent}}, "parent")
        if parent_id is None:
            return _refusal(f"parent {parent.get('href')}")
        return await check_work_package(op, parent_id)
    return None


def scoped_filters(filters: str, scoped: int) -> str:
    """Pin a work package filter list to the scoped project, without subprojects."""
    try:
        parsed = json.loads(filters or "[]")
    except json.JSONDecodeError:
        parsed = []
    if not isinstance(parsed, list):
        parsed = []
    # The caller may not widen the scope: their own project/subproject filters go.
    kept = [
        f for f in parsed
        if isinstance(f, dict) and not ({"project", "subprojectId", "onlySubproject"} & f.keys())
    ]
    kept.append({"project": {"operator": "=", "values": [str(scoped)]}})
    return json.dumps(kept)


def in_scope(rows: list[dict[str, Any]], scoped: int | None) -> list[dict[str, Any]]:
    """Drop rows from another project (e.g. a subproject) as a last line of defence."""
    if scoped is None:
        return rows
    return [r for r in rows if link_id(r, "project") == scoped]
