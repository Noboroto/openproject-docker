"""Project scope (X-OpenProject-Project) refuses everything outside the named project."""

import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest

import scope
from auth import extract_project, reset_request_project, set_request_project
from client import OpenProjectError

ABSENT = object()


class StubClient:
    """Answers the few GETs scope.py makes, from a fixed in-memory site."""

    projects = {"dapt": 3, "3": 3, "demo": 1, "1": 1}
    work_packages = {101: 3, 202: 1}

    def __init__(self):
        self.calls = []

    async def get(self, path, **_params):
        self.calls.append(path)
        kind, _, key = path.strip("/").partition("/")
        if kind == "projects" and key in self.projects:
            return {"_type": "Project", "id": self.projects[key]}
        if kind == "work_packages" and key.isdigit() and int(key) in self.work_packages:
            return wp(int(key), self.work_packages[int(key)])
        raise OpenProjectError(404, "not found")


def wp(wp_id, project_id):
    return {"id": wp_id, "_links": {"project": {"href": f"/api/v3/projects/{project_id}"}}}


def run(coro, project=ABSENT):
    async def scoped():
        marker = set_request_project(None if project is ABSENT else project)
        try:
            return await coro
        finally:
            reset_request_project(marker)

    scope._scope_ids.clear()
    return asyncio.run(scoped())


@pytest.fixture(autouse=True)
def no_env_scope(monkeypatch):
    monkeypatch.delenv("OPENPROJECT_PROJECT", raising=False)


class TestHeader:
    def test_reads_header(self):
        assert extract_project({"x-openproject-project": " dapt "}) == "dapt"

    def test_absent_header_is_none(self):
        assert extract_project({}) is None

    def test_blank_header_is_kept_as_empty(self):
        assert extract_project({"x-openproject-project": "  "}) == ""


class TestUnscoped:
    def test_everything_allowed_without_extra_calls(self):
        op = StubClient()
        assert run(scope.check_project(op, 1)) is None
        assert run(scope.check_work_package(op, 202)) is None
        assert run(scope.check_write_body(op, {"_links": {"project": {"href": "/api/v3/projects/1"}}})) is None
        assert op.calls == []


class TestScoped:
    def test_same_project_by_identifier_allowed(self):
        assert run(scope.check_project(StubClient(), 3), "dapt") is None

    def test_numeric_scope_allowed(self):
        assert run(scope.check_project(StubClient(), 3), "3") is None

    def test_other_project_refused(self):
        out = run(scope.check_project(StubClient(), 1), "dapt")
        assert "Out of scope" in out["error"] and "project 1" in out["error"]

    def test_work_package_in_scope_allowed(self):
        assert run(scope.check_work_package(StubClient(), 101), "dapt") is None

    def test_work_package_elsewhere_refused(self):
        out = run(scope.check_work_package(StubClient(), 202), "dapt")
        assert "work package 202" in out["error"]

    def test_no_project_id_is_not_refused(self):
        # Callers that omit project_id are narrowed to the scope by the tool itself.
        assert run(scope.check_project(StubClient(), None), "dapt") is None


class TestFailsClosed:
    def test_unknown_project(self):
        assert "cannot be used" in run(scope.check_project(StubClient(), 3), "nope")["error"]

    def test_blank_header_refuses_instead_of_unscoped(self):
        assert "cannot be used" in run(scope.check_project(StubClient(), 1), "")["error"]

    def test_path_like_value_never_reaches_the_api(self):
        op = StubClient()
        out = run(scope.check_project(op, 1), "../work_packages/202")
        assert "cannot be used" in out["error"] and op.calls == []

    def test_env_scope_applies_without_header(self, monkeypatch):
        monkeypatch.setenv("OPENPROJECT_PROJECT", "dapt")
        assert "Out of scope" in run(scope.check_project(StubClient(), 1))["error"]

    def test_header_cannot_override_env_scope(self, monkeypatch):
        monkeypatch.setenv("OPENPROJECT_PROJECT", "dapt")
        assert "cannot be used" in run(scope.check_project(StubClient(), 1), "demo")["error"]


class TestWriteBody:
    def body(self, **links):
        return {"subject": "x", "_links": {k: {"href": v} for k, v in links.items()}}

    def test_moving_to_another_project_refused(self):
        out = run(scope.check_write_body(StubClient(), self.body(project="/api/v3/projects/1")), "dapt")
        assert "project 1" in out["error"]

    def test_identifier_project_href_refused(self):
        out = run(scope.check_write_body(StubClient(), self.body(project="/api/v3/projects/demo")), "dapt")
        assert "Out of scope" in out["error"]

    def test_parent_in_another_project_refused(self):
        out = run(scope.check_write_body(StubClient(), self.body(parent="/api/v3/work_packages/202")), "dapt")
        assert "work package 202" in out["error"]

    def test_parent_and_project_in_scope_allowed(self):
        body = self.body(project="/api/v3/projects/3", parent="/api/v3/work_packages/101")
        assert run(scope.check_write_body(StubClient(), body), "dapt") is None

    @pytest.mark.parametrize("href", [
        "/api/v3/projects/1?x=/3",       # OpenProject resolves project 1; last segment says 3
        "/api/v3/projects/1#/3",
        "/api/v3/projects/1/../3",
        "https://evil.example/api/v3/projects/3",
        "/api/v3/work_packages/3",        # wrong collection for a project link
        "/api/v3/projects/3x",
    ])
    def test_crafted_project_href_refused(self, href):
        out = run(scope.check_write_body(StubClient(), self.body(project=href)), "dapt")
        assert "Out of scope" in out["error"]

    def test_crafted_parent_href_refused(self):
        out = run(scope.check_write_body(StubClient(), self.body(parent="/api/v3/work_packages/202?x=/101")), "dapt")
        assert "Out of scope" in out["error"]

    def test_trailing_slash_in_scope_allowed(self):
        assert run(scope.check_write_body(StubClient(), self.body(project="/api/v3/projects/3/")), "dapt") is None

    def test_top_level_project_or_parent_refused(self):
        assert "Out of scope" in run(scope.check_write_body(StubClient(), {"project": 1}), "dapt")["error"]
        assert "Out of scope" in run(scope.check_write_body(StubClient(), {"parent": 202}), "dapt")["error"]

    def test_clearing_parent_allowed(self):
        assert run(scope.check_write_body(StubClient(), {"_links": {"parent": {"href": None}}}), "dapt") is None


class TestListing:
    def test_filters_pinned_to_scope_and_subprojects_dropped(self):
        caller = json.dumps([
            {"status": {"operator": "o", "values": []}},
            {"subprojectId": {"operator": "*", "values": []}},
            {"project": {"operator": "=", "values": ["1"]}},
        ])
        out = json.loads(scope.scoped_filters(caller, 3))
        assert out == [
            {"status": {"operator": "o", "values": []}},
            {"project": {"operator": "=", "values": ["3"]}},
        ]

    def test_bad_filters_still_pinned(self):
        assert json.loads(scope.scoped_filters("not json", 3)) == [
            {"project": {"operator": "=", "values": ["3"]}}
        ]

    def test_rows_from_other_projects_dropped(self):
        rows = [wp(101, 3), wp(202, 1), {"id": 9, "_links": {}}]
        assert [r["id"] for r in scope.in_scope(rows, 3)] == [101]
        assert len(scope.in_scope(rows, None)) == 3
