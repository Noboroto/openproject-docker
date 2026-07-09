"""Schema-driven payload building — pure, deterministic, no mocks.

The schema fixtures below are trimmed copies of real responses from
/api/v3/work_packages/schemas/{project}-{type} on OpenProject 17.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from schema import build_body, writable_fields, _href, _rel

# Scrum project / Task: backlogs enabled, so storyPoints exists.
SCRUM = {
    "_type": "Schema",
    "subject": {"type": "String", "name": "Subject", "required": True, "writable": True},
    "storyPoints": {"type": "Integer", "name": "Story Points", "writable": True},
    "percentageDone": {"type": "Integer", "name": "% Complete", "writable": True},
    "responsible": {"type": "User", "name": "Accountable", "writable": True, "location": "_links"},
    "category": {"type": "Category", "name": "Category", "writable": True, "location": "_links"},
    "version": {"type": "Version", "name": "Version", "writable": True, "location": "_links"},
    "createdAt": {"type": "DateTime", "name": "Created on", "writable": False},
    "customField3": {"type": "Integer", "name": "Risk", "writable": True},
    "customField7": {"type": "ListOptionalValue", "name": "Tier", "writable": True, "location": "_links"},
    "_links": {"self": {"href": "/api/v3/work_packages/schemas/2-1"}},
}

# Demo project / Task: no backlogs module, so storyPoints is absent entirely.
DEMO = {k: v for k, v in SCRUM.items() if k != "storyPoints"}


class TestRel:
    def test_strips_api_prefix(self):
        assert _rel("/api/v3/work_packages/schemas/2-6") == "/work_packages/schemas/2-6"

    def test_leaves_bare_path(self):
        assert _rel("/work_packages/schemas/2-6") == "/work_packages/schemas/2-6"


class TestHref:
    def test_int_becomes_href(self):
        assert _href("User", 5) == "/api/v3/users/5"
        assert _href("Category", 2) == "/api/v3/categories/2"
        assert _href("ListOptionalValue", 9) == "/api/v3/custom_options/9"

    def test_str_passes_through(self):
        # Lets callers address a group, which shares the `User` schema type.
        assert _href("User", "/api/v3/groups/4") == "/api/v3/groups/4"

    def test_unknown_type_unresolvable(self):
        assert _href("Wat", 1) is None


class TestBuildBody:
    def test_link_fields_go_under_links(self):
        body, warnings = build_body(SCRUM, {"responsible": 5, "category": 2, "version": 3})
        assert warnings == []
        assert body["_links"] == {
            "responsible": {"href": "/api/v3/users/5"},
            "category": {"href": "/api/v3/categories/2"},
            "version": {"href": "/api/v3/versions/3"},
        }
        assert "responsible" not in body

    def test_plain_attrs_stay_top_level(self):
        body, warnings = build_body(SCRUM, {"storyPoints": 8, "subject": "Hi"})
        assert warnings == []
        assert body == {"storyPoints": 8, "subject": "Hi"}
        assert "_links" not in body

    def test_missing_field_is_dropped_with_warning_not_error(self):
        # The bug this guards: storyPoints on a project without backlogs used to
        # 422 the whole write. Now it is skipped and the rest still applies.
        body, warnings = build_body(DEMO, {"subject": "Hi", "storyPoints": 8})
        assert body == {"subject": "Hi"}
        assert [w["field"] for w in warnings] == ["storyPoints"]
        assert "not available" in warnings[0]["reason"]

    def test_other_fields_survive_a_dropped_field(self):
        body, warnings = build_body(DEMO, {"storyPoints": 8, "responsible": 5, "subject": "Hi"})
        assert body["subject"] == "Hi"
        assert body["_links"]["responsible"] == {"href": "/api/v3/users/5"}
        assert len(warnings) == 1

    def test_readonly_field_is_dropped_with_warning(self):
        body, warnings = build_body(SCRUM, {"createdAt": "2026-01-01"})
        assert body == {}
        assert warnings[0]["field"] == "createdAt"
        assert "read-only" in warnings[0]["reason"]

    def test_none_means_not_supplied(self):
        body, warnings = build_body(SCRUM, {"subject": None, "storyPoints": None})
        assert body == {}
        assert warnings == []

    def test_custom_fields_route_by_schema_location(self):
        body, warnings = build_body(SCRUM, {"customField3": 5, "customField7": 9})
        assert warnings == []
        assert body["customField3"] == 5
        assert body["_links"]["customField7"] == {"href": "/api/v3/custom_options/9"}

    def test_unknown_custom_field_warns(self):
        body, warnings = build_body(SCRUM, {"customField99": 1})
        assert body == {}
        assert warnings[0]["field"] == "customField99"

    def test_no_schema_sends_unvalidated_and_warns(self):
        # Never silently discard data the user asked us to set.
        body, warnings = build_body(None, {"subject": "Hi", "storyPoints": 8})
        assert body == {"subject": "Hi", "storyPoints": 8}
        assert warnings[-1]["field"] == "*"

    def test_no_schema_no_fields_is_silent(self):
        body, warnings = build_body(None, {})
        assert body == {} and warnings == []

    def test_zero_is_sent_not_treated_as_absent(self):
        body, _ = build_body(SCRUM, {"storyPoints": 0, "percentageDone": 0})
        assert body == {"storyPoints": 0, "percentageDone": 0}


class TestWritableFields:
    def test_excludes_readonly_and_metadata(self):
        keys = [f["key"] for f in writable_fields(SCRUM)]
        assert "createdAt" not in keys
        assert "_links" not in keys
        assert "storyPoints" in keys

    def test_flags_links(self):
        by_key = {f["key"]: f for f in writable_fields(SCRUM)}
        assert by_key["responsible"]["isLink"] is True
        assert by_key["responsible"]["name"] == "Accountable"
        assert by_key["storyPoints"]["isLink"] is False


if __name__ == "__main__":
    import subprocess
    raise SystemExit(subprocess.call(["python", "-m", "pytest", __file__, "-v"]))
