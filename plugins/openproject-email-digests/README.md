# openproject-email_digests

Email digests and notification customization for OpenProject 17 (Community).

Batches accumulated work-package activity into a periodic email (daily or weekly)
per user, instead of (or in addition to) instant notifications, with per-user
delivery rules:

- **Frequency**: off / daily / weekly.
- **Mute by project**: skip activity in chosen projects.
- **Mute by work-package type**: skip activity on chosen types.
- **Quiet hours**: suppress activity occurring inside a window (wrap-around
  supported, e.g. 22:00 -> 06:00).

Admins set the instance-wide default **send hour**.

## How it works

Two GoodJob cron jobs are registered via `config.good_job.cron` (the real OP 17
mechanism — no `add_cron_jobs` hook):

| Job | Schedule | Role |
|-----|----------|------|
| `EmailDigests::EnqueueDigestItemsJob` | hourly | Captures recently-changed work packages into each interested user's queue (assignee, responsible, watchers), honouring mutes, quiet hours, and **work-package visibility** (`wp.visible?(user)`). |
| `EmailDigests::SendDigestsJob` | hourly | Self-gates on the configured `digest_send_hour`; flushes daily queues every day and weekly queues on Mondays. |

Cron only fires when `OPENPROJECT_GOOD__JOB__ENABLE__CRON=true` (set by the OP
`cron` service); otherwise the jobs are registered but dormant.

`DigestBuilder` re-checks `work_package.visible?(user)` at send time (permissions
may have changed since capture) before including an item.

## Pages

- **My account -> Email digests** — per-user preferences. Authenticated users
  manage only their own row (keyed by `current_user.id`; no id from params, so
  IDOR-safe). Uses `no_authorization_required!` for the personal page.
- **Administration -> Email digests** — instance default send hour
  (`require_admin`).

## Data model

- `op_digest_preferences` — one row per user (frequency, muted project/type ids,
  quiet-hours window).
- `op_digest_queue` — pending digest items; marked `sent` rather than deleted for
  idempotency. Unique index on `(user_id, work_package_id, occurred_at)` prevents
  duplicate captures across overlapping cron runs.

Both migrations are `ActiveRecord::Migration[7.1]` with `op_digest_`-namespaced
tables.

## Install

Add to `Gemfile.plugins`:

```ruby
gem "openproject-email_digests", path: "plugins/openproject-email-digests"
```

then `bundle install` and run migrations.

## Notes / assumptions

- "Activity" is approximated by `WorkPackage#updated_at` within the cron window.
  Hook into core's journals/notifications for finer-grained capture if needed.
- No `openproject-core` gem dependency (it does not exist); core is resolved via
  the `path:` entry in `Gemfile.plugins`.
- `lib/` is zeitwerk-ignored (loaded manually) to avoid the
  `openproject` -> `Openproject` camelize crash on eager-load.
