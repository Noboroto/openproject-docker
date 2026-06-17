"""Real unit tests for pure helpers — no mocks, deterministic."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils import to_iso_duration, link_id, link_title, elements, page_meta


class TestToIsoDuration:
    def test_whole_hours(self):
        assert to_iso_duration(2) == "PT2H"

    def test_fractional_half(self):
        # The bug this guards: f"PT{1.5}H" == "PT1.5H" is INVALID ISO 8601
        assert to_iso_duration(1.5) == "PT1H30M"

    def test_quarter_hour(self):
        assert to_iso_duration(0.25) == "PT15M"

    def test_zero(self):
        assert to_iso_duration(0) == "PT0M"

    def test_minutes_only(self):
        assert to_iso_duration(0.5) == "PT30M"

    def test_rounding(self):
        # 1.51h -> 90.6 min -> rounds to 91 min -> 1h31m
        assert to_iso_duration(1.51) == "PT1H31M"

    def test_string_input(self):
        assert to_iso_duration(3) == "PT3H"


class TestLinkHelpers:
    SAMPLE = {
        "_links": {
            "type": {"href": "/api/v3/types/3", "title": "Task"},
            "status": {"href": "/api/v3/statuses/7/", "title": "New"},
            "assignee": {},
        }
    }

    def test_link_id_basic(self):
        assert link_id(self.SAMPLE, "type") == 3

    def test_link_id_trailing_slash(self):
        assert link_id(self.SAMPLE, "status") == 7

    def test_link_id_missing(self):
        assert link_id(self.SAMPLE, "assignee") is None
        assert link_id(self.SAMPLE, "nonexistent") is None

    def test_link_title(self):
        assert link_title(self.SAMPLE, "type") == "Task"
        assert link_title(self.SAMPLE, "nonexistent") is None


class TestCollectionHelpers:
    def test_elements(self):
        payload = {"_embedded": {"elements": [{"id": 1}, {"id": 2}]}}
        assert elements(payload) == [{"id": 1}, {"id": 2}]

    def test_elements_empty(self):
        assert elements({}) == []

    def test_page_meta_has_more(self):
        payload = {"total": 50, "count": 25, "pageSize": 25, "offset": 1}
        meta = page_meta(payload, 25)
        assert meta["total"] == 50
        assert meta["hasMore"] is True

    def test_page_meta_last_page(self):
        payload = {"total": 30, "count": 5, "pageSize": 25, "offset": 2}
        meta = page_meta(payload, 25)
        assert meta["hasMore"] is False


if __name__ == "__main__":
    import subprocess
    raise SystemExit(subprocess.call(["python", "-m", "pytest", __file__, "-v"]))
