# openproject-baselines

Project baseline snapshots and diff for OpenProject CE.

## What it does

Captures a point-in-time snapshot (name + timestamp) of a project and diffs the current work-package state against it, showing:

- **Added** — WPs created after the baseline
- **Removed** — WPs deleted after the baseline
- **Changed** — WPs whose tracked attributes (subject, status, assignee, dates, done ratio) differ

Diff is computed from OP's core **journals** — read-only access, no writes to core tables.

## Feature flag

Disabled by default. Enable via Administration → Plugins → Baselines → `enabled: true`.

## Limits

- Diff is capped at `max_work_packages` (default 2 000) to prevent DoS on large projects.
- Diff is scoped to WPs visible to the current user.
- No Gantt baseline highlighting (that is an EE surface — out of scope).

## Known limitations

- Baseline diff relies on journal existence; WPs never journaled before `captured_at` appear as "added".
- Journal `data` schema sliced to known safe attributes to be version-resilient.
