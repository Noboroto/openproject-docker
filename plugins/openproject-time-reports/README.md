# openproject-time_reports

Advanced time tracking **plus cost / budget reporting** for OpenProject 17
(Community Edition), implemented as an original Rails engine plugin via the
official `OpenProject::Plugins::ActsAsOpEngine` API. No core files are
monkey-patched and no Enterprise Edition source is used.

## Features

- **Time report** — list time entries filtered by date range / user, with total
  hours and CSV export.
- **Pivot view** — users (rows) × work packages (columns), cells = hours.
- **Cost rates** (`op_cost_rates`) — hourly rates scoped to a project and
  optionally to a user and/or activity, with effective-date versioning
  (`valid_from`). The applicable rate for a time entry is the latest
  `valid_from <= spent_on`; a user-specific rate beats a project-wide one, and
  an activity-specific rate beats an activity-agnostic one.
- **Cost report** — time entries × effective rate with a grand total, gated by a
  dedicated `view_cost_reports` permission (separate from time viewing because
  monetary data is confidential).
- **Budgets** (`op_cost_budgets`) — per-project budget records with
  spent / remaining / percent-used (over-budget detection), reused by the
  dashboards-plus budget widget.

## Permissions (project module `time_reports`)

| Permission | Grants |
|---|---|
| `view_time_reports` | time report list, pivot, CSV export (hours only) |
| `view_cost_reports` | cost report + cost CSV export (money) |
| `manage_budgets` | budget CRUD |

Cost figures never appear in the plain time report — they require
`view_cost_reports`. CSV streaming endpoints run `before_action :authorize`
before any data is sent.

## Tables

- `op_cost_rates` — `project_id`, nullable `user_id`, nullable `activity_id`
  (FK → `enumerations`, STI `TimeEntryActivity`), `rate` (decimal 12,2),
  `currency`, `valid_from`. Index on `(project_id, user_id, valid_from)`.
- `op_cost_budgets` — `project_id`, `name`, `amount` (decimal 14,2), `currency`,
  optional `period_start` / `period_end`.

Money is stored as `decimal`, never float; rounding happens at display only.

## Installation

Add to `Gemfile.plugins`:

```ruby
gem "openproject-time_reports", path: "plugins/openproject-time-reports"
```

then `bundle install` and `bundle exec rails db:migrate`.

## Verify-against-image notes

Lines flagged `verify against running 17-slim image` mark OP-version-dependent
assumptions (Rails migration version, `TimeEntryActivity` STI in `enumerations`,
project-menu parent symbols). Confirm before deploying to a new OP release.
