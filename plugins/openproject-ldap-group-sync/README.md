# OpenProject LDAP Group Sync

Synchronizes **LDAP group membership** into OpenProject groups. OpenProject
Community already ships LDAP **authentication** (`LdapAuthSource`); this plugin
adds the missing piece: map an LDAP group (by distinguished name) to an
OpenProject group, and keep OP membership mirroring LDAP on a schedule and
(optionally) after each LDAP login. EE-equivalent of "LDAP group synchronization".

## Hard constraints (this plugin obeys all four)

1. **Original implementation only.** Built from the public feature description of
   the corresponding OpenProject Enterprise add-on. No EE gem source is read,
   copied, decompiled, or transcribed, and no license/enterprise token check is
   stripped, stubbed, or bypassed.
2. **Official engine API only.** Hooks through
   `OpenProject::Plugins::ActsAsOpEngine` (`register`, `menu`, `settings`),
   `config.good_job.cron`, and `OpenProject::Notifications`. No core-file
   monkey-patching; no editing of files under OP `app/`, `lib/`, or `config/`.
3. **Rails 7.1+.** All migrations subclass `ActiveRecord::Migration[7.1]`. Tables
   are namespaced `op_ldap_gs_*`.
4. **Quality bar.** Engine + namespaced migrations · model + service + request
   specs · I18n `en` and `vi` · admin settings UI gated by `require_admin` ·
   loads clean under `RAILS_ENV=production` · this README.

## How it works

| Concern             | Where                                                                    |
|---------------------|--------------------------------------------------------------------------|
| Mapping             | `LdapGroupSync::SynchronizedGroup`, table `op_ldap_gs_synchronized_groups` |
| Audit of a run      | `LdapGroupSync::SyncRun`, table `op_ldap_gs_sync_runs` (status enum)      |
| LDAP query          | `LdapGroupSync::GroupMembershipResolver` (Net::LDAP, paged + capped)      |
| Apply diff          | `LdapGroupSync::SynchronizeService` (core Groups services, `User.system`) |
| Schedule            | `LdapGroupSync::SynchronizationJob` via `config.good_job.cron`            |
| Per-login sync      | subscribe to the CE login event (inert if event name differs)            |
| Admin UI            | `LdapGroupSync::SynchronizedGroupsController` (`require_admin`)           |

The resolver only decides **who** should be in the group; the service computes
`desired - current` (add) and, when `remove_orphaned_memberships` is enabled,
`current - desired` (remove). All writes go through core
`Groups::AddUsersService` / `Groups::RemoveUsersService` as `User.system` inside
a transaction — **no ACL bypass**.

## Settings (Administration, plugin defaults)

- `sync_on_login` (default `true`) — sync a user's groups after LDAP login.
- `remove_orphaned_memberships` (default `true`) — remove users who left the LDAP
  group. Set `false` for additive-only sync of privileged groups.
- `max_members_per_run` (default `5000`) — cap LDAP entries processed per group.

## Configuration

- `OPENPROJECT_GOOD__JOB__ENABLE__CRON=true` must be set for the daily cron to
  fire (registered either way; runs only when cron is enabled).
- Cron expression: `0 2 * * *` (daily at 02:00 instance-local). Adjust in
  `lib/openproject/ldap_group_sync/engine.rb`.

## Installation

Add to `Gemfile.plugins`:

```ruby
gem "openproject-ldap_group_sync", path: "plugins/openproject-ldap-group-sync"
```

Then `bundle install` and `rails db:migrate`.

## Version-dependent integration points

Flagged with `verify against running 17-slim image` comments in source:

- CE LDAP auth source class/columns (`LdapAuthSource`: `host`, `port`, `account`,
  `account_password`, `base_dn`, `attr_login`, `attr_mail`).
- Core Groups services signatures
  (`Groups::AddUsersService.new(group, current_user:).call(ids:)` and the
  `RemoveUsersService` counterpart) and their `ServiceResult` return.
- The successful-login event name (`OpenProject::Events::USER_LOGGED_IN`) — the
  subscription is inert if it differs, and the cron still keeps groups in sync.
- `ApplicationJob` base class + GoodJob cron entry shape.

## Security

- **Never logs bind credentials or full LDAP entries** (PII) — only DNs and
  counts are surfaced; job failures log the class only, with the DN redacted.
- Membership writes use `User.system` as the actor so journals attribute
  correctly, and run inside a transaction so a partial failure rolls back.
- Mapping a group whose name starts with `admin` requires an explicit
  confirmation checkbox, to avoid a wide LDAP group mass-granting admin access.
- All admin actions are gated by `require_admin`; the menu lives under
  Authentication and is admin-visible only.

## Specs

- `spec/models/ldap_group_sync/synchronized_group_spec.rb` — unique DN per source.
- `spec/models/ldap_group_sync/sync_run_spec.rb` — enum + `track` transitions.
- `spec/services/ldap_group_sync/synchronize_service_spec.rb` — add/remove counts,
  `remove_orphaned_memberships=false` skips removals (stubbed resolver).
- `spec/requests/ldap_group_sync/synchronized_groups_spec.rb` — admin CRUD,
  non-admin 403, "Sync now" enqueues the job.

Specs assume the OpenProject core test harness (FactoryBot factories, `login_as`).
