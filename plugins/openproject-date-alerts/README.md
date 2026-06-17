# OpenProject Date Alerts

Background date alerts / reminders for OpenProject work packages. A daily job
scans open work packages and creates **de-duplicated in-app notifications** (and
an optional email) for assignees whose work packages have an upcoming or overdue
**start** or **due** date, according to each user's configured lead time.

This is an original implementation built only against OpenProject's public plugin
API (`OpenProject::Plugins::ActsAsOpEngine`, `Notifications::CreateService`, and
GoodJob cron via `add_cron_jobs`). It does **not** contain, copy, or bypass any
OpenProject Enterprise (EE) source or license check.

## Features

- Per-user preferences under **My account → Date alerts**: toggle start/due
  alerts, set lead days (0–365), opt into email.
- Instance defaults under **Administration → Date alerts** (default lead days +
  global email opt-in), applied to users who have not set their own.
- Daily scan via OpenProject's GoodJob cron (`0 6 * * *`, instance-local).
- Idempotent: never sends the same work-package + kind alert to the same user
  twice in one day (DB-unique ledger).
- Respects work-package visibility per user (`wp.visible?(user)`).
- English + Vietnamese locales.

## How it works

| Concern              | Where                                                                 |
|----------------------|-----------------------------------------------------------------------|
| User preferences     | `DateAlerts::AlertPreference`, table `op_dates_alert_preferences`      |
| Idempotency ledger   | `DateAlerts::SentAlert`, table `op_dates_sent_alerts` (unique index)   |
| Instance defaults    | `Setting` store (`plugin_openproject_date_alerts`)                     |
| Scan / select        | `DateAlerts::Scanner` (open WPs, assignee, in-window, prefs)           |
| Notify / dedupe      | `DateAlerts::Notifier` (visibility + same-day idempotency + core svc)  |
| Schedule             | `DateAlerts::ScanJob` registered via `add_cron_jobs`                   |
| Notification         | core `Notifications::CreateService`, reasons `date_alert_*`            |
| Optional email       | `DateAlerts::Mailer#alert` (opt-in)                                    |

The Scanner only decides *which* alerts are in range; the Notifier owns
visibility and idempotency. Re-running the job on the same day is a safe no-op.

## Notifications

Notifications are created through core's `Notifications::CreateService` using the
existing `Notification#reason` enum values `date_alert_start_date` /
`date_alert_due_date`, so they appear in the standard OpenProject notification
center.

## Configuration

- `OPENPROJECT_GOOD__JOB__ENABLE__CRON=true` must be set for the cron entry to
  fire (it is registered either way, but only runs when cron is enabled).
- Cron expression: `0 6 * * *` (daily at 06:00 instance-local time). Adjust in
  `lib/openproject/date_alerts/engine.rb`.

## Installation

Add to `Gemfile.plugins`:

```ruby
gem "openproject-date_alerts", path: "plugins/openproject-date-alerts"
```

Then `bundle install` and `rails db:migrate`.

## Performance

The scan is O(open work packages) per day. It uses `find_each` batching and
relies on indexes for `due_date` / `start_date` (provided by core) and only
considers open work packages with an assignee. For very large instances consider
narrowing the base scope further (e.g. projects with the module active).

## Version-dependent integration points

These are flagged with `verify against running 17-slim image` comments in source:

- `add_cron_jobs` ActsAsOpEngine hook + `{ cron:, class: }` entry shape.
- `Notifications::CreateService` instantiation (`user:`) and call attributes,
  plus the `date_alert_start_date` / `date_alert_due_date` reason enum values.
- `WorkPackage.open` scope name.
- `require_login` controller filter and the `"my"` account layout name.

## Security

- A user can only read/write **their own** preference — the record is always
  keyed by `current_user.id`; no id is taken from params.
- The Notifier checks `wp.visible?(user)` before every alert — a user is never
  told about a work package they cannot see.
- Same-day idempotency (DB unique index) prevents notification spam and
  double-sends across concurrent scans.
- Instance defaults are admin-only (`require_admin`).

## Specs

- `spec/models/date_alerts/alert_preference_spec.rb` — one-per-user, `.for`
  fallback to defaults.
- `spec/services/date_alerts/scanner_spec.rb` — window selection, per-user
  toggles, skips closed/assignee-less WPs, start + due.
- `spec/services/date_alerts/notifier_spec.rb` — creates notification, same-day
  dedupe, visibility, email opt-in.
- `spec/jobs/date_alerts/scan_job_spec.rb` — wiring + idempotent re-run.
- `spec/requests/date_alerts/preferences_spec.rb` — own-only view/update.

Specs assume the OpenProject core test harness (FactoryBot factories, `login_as`).
