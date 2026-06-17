"""Shared helpers: ISO 8601 durations, HAL parsing, TTL cache."""

from __future__ import annotations

from typing import Any
from cachetools import TTLCache

# Static lookups (types/statuses/priorities) rarely change — cache 5 min.
lookup_cache: TTLCache = TTLCache(maxsize=64, ttl=300)


def to_iso_duration(hours: float) -> str:
    """Convert decimal hours to a valid ISO 8601 duration.

    1.5 -> "PT1H30M"  ·  2 -> "PT2H"  ·  0.25 -> "PT15M"  ·  0 -> "PT0M"
    `f"PT{hours}H"` is WRONG for fractional hours (PT1.5H is invalid).
    """
    total_minutes = round(float(hours) * 60)
    h, m = divmod(total_minutes, 60)
    out = "PT"
    if h:
        out += f"{h}H"
    if m:
        out += f"{m}M"
    return out if out != "PT" else "PT0M"


def link_id(resource: dict[str, Any], rel: str) -> int | None:
    """Extract the numeric id from a HAL _links[rel].href like /api/v3/types/3."""
    href = (resource.get("_links", {}).get(rel) or {}).get("href")
    if not href:
        return None
    try:
        return int(str(href).rstrip("/").split("/")[-1])
    except (ValueError, IndexError):
        return None


def link_title(resource: dict[str, Any], rel: str) -> str | None:
    """Extract the title from a HAL _links[rel]."""
    return (resource.get("_links", {}).get(rel) or {}).get("title")


def elements(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """Return _embedded.elements from a HAL collection payload."""
    return payload.get("_embedded", {}).get("elements", [])


def page_meta(payload: dict[str, Any], page_size: int) -> dict[str, Any]:
    """Build a pagination summary so callers never silently miss rows."""
    total = payload.get("total", 0)
    count = payload.get("count", len(elements(payload)))
    offset = payload.get("offset", 1)
    return {
        "total": total,
        "count": count,
        "pageSize": payload.get("pageSize", page_size),
        "offset": offset,
        "hasMore": (offset * payload.get("pageSize", page_size)) < total,
    }
