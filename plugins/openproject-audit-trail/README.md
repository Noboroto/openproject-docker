# openproject-audit_trail

Append-only **audit trail / security logging** for OpenProject 17 (Community Edition).
Records security-relevant events into an **immutable** table with an admin viewer and
CSV export. EE-equivalent of "Audit trail / security logging" — an original
reimplementation of the *feature idea*, not a copy of the Enterprise add-on.

## What it does

- Subscribes to OpenProject's published `ActiveSupport::Notifications` (membership /
  role changes, project deletion, account activation, login events) and writes an
  audit row per event: actor, event, target, scrubbed change set, IP, timestamp.
- Stores events in `op_audit_events` — **append-only**: the model is `readonly?` once
  persisted, so any UPDATE raises `ActiveRecord::ReadOnlyRecord`. Rows are created
  ONLY by the recorder (no HTTP write path) and removed only by the retention purge.
- Admin-only viewer (`Administration → Audit trail`) with event/date filters,
  pagination, and a CSV export. **Authorization runs before any data is streamed.**
- Daily retention purge via OpenProject's GoodJob cron (`config.good_job.cron`),
  controlled by the `retention_days` setting (0 = keep forever).

## Security

- **Secrets are never stored.** The recorder scrubs password / hashed_password / salt /
  token / secret / api_key / auth_source_token / private_key / otp keys (case-insensitive,
  recursive) from every change set before persistence.
- **Immutability** is enforced at the model layer (`readonly?`) — UPDATE raises. For
  defense in depth you may additionally revoke UPDATE/DELETE on `op_audit_events` from
  the app DB role.
- **IP capture is PII** and is gated behind the `capture_ip` setting (default on); document
  your retention policy accordingly. The `retention_days` purge bounds how long PII is kept.
- The viewer and CSV export are gated by OpenProject's built-in `require_admin` on every
  action; CSV sets `Cache-Control: no-store`.

## Settings (`Setting.plugin_openproject_audit_trail`)

| key              | default | meaning                                            |
|------------------|---------|----------------------------------------------------|
| `retention_days` | `365`   | Days to keep events; `0` disables the purge.        |
| `capture_ip`     | `true`  | Whether to record the client IP (PII).              |

## Event names — VERIFY against the running image

The subscribed event names are centralized in
`AuditTrail::Recorder::SUBSCRIBED_EVENTS`. They are the *likely* OpenProject 17 names but
must be confirmed against the running `17-slim` image; an event that never fires simply
produces no rows (no crash). To confirm:

```bash
docker run --rm openproject/openproject:17-slim \
  grep -rn "OpenProject::Notifications.send" /app/app /app/lib | grep -iE "member|project|user"
```

Adjust `SUBSCRIBED_EVENTS` (and the `audit_trail.events.*` i18n keys) if the names differ.

## Hard constraints (verbatim — apply to every plugin in this tier)

1. **Original implementation only.** Build from the *public feature description* of the
   corresponding OpenProject Enterprise add-on. **NEVER** read, copy, decompile, or
   transcribe the EE gem source. **NEVER** strip, stub, or bypass a license/enterprise
   token check.
2. **Official engine API only.** Hook through `OpenProject::Plugins::ActsAsOpEngine`
   (`register`, `permission`, `menu`, `project_module`, `settings`, patch *registration*
   helpers, `ActiveSupport::Notifications`). **No core-file monkey-patching.**
3. **Rails 7.1+.** All migrations subclass `ActiveRecord::Migration[7.1]`. Table names are
   namespaced per plugin (`op_audit_*`) to avoid collisions.
4. **Quality bar (per plugin):** engine + namespaced migrations · RSpec **model + request**
   specs · I18n `en` **and** `vi` · permissions / admin gating · loads clean under
   `RAILS_ENV=production` · README.

## Layout

```
openproject-audit-trail/
├── openproject-audit_trail.gemspec
├── lib/openproject-audit_trail.rb            # gem entry (requires engine)
├── lib/openproject/audit_trail/{engine.rb,version.rb}
├── app/
│   ├── controllers/audit_trail/audit_events_controller.rb   # admin viewer + CSV
│   ├── models/audit_trail/audit_event.rb                    # append-only, readonly?
│   ├── services/audit_trail/recorder.rb                     # subscribe + scrub
│   └── jobs/audit_trail/retention_purge_job.rb              # good_job cron target
├── app/views/audit_trail/audit_events/index.html.erb
├── config/{routes.rb,locales/en.yml,locales/vi.yml}
├── db/migrate/20260619096000_create_op_audit_events.rb
├── spec/{models,services,requests}/...
└── README.md
```

## Console escape / manual purge

```ruby
# Force a purge using the configured retention window:
AuditTrail::AuditEvent.purge_expired!
```
