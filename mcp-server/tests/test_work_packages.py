"""Work package summaries keep every date field OpenProject sends."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tools.work_packages import _summarize


class TestSummarizeDates:
    def test_milestone_keeps_date(self):
        # Milestones expose `date`, not startDate/dueDate.
        out = _summarize({"id": 39, "date": "2026-10-15", "_links": {}})
        assert out["date"] == "2026-10-15"
        assert out["startDate"] is None and out["dueDate"] is None

    def test_task_has_no_date_key(self):
        out = _summarize(
            {"id": 44, "startDate": "2026-10-02", "dueDate": "2026-10-15", "_links": {}}
        )
        assert "date" not in out
        assert out["startDate"] == "2026-10-02"
        assert out["dueDate"] == "2026-10-15"
