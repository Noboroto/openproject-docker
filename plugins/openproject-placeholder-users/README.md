# openproject-placeholder_users

CE-native **placeholder users** for OpenProject: login-less principals you can
assign to work packages (as assignee/responsible) or use for resource planning
before a real account exists — plus an admin UI and a one-click
**promote-to-real-user** action.

## Why this plugin exists (core already has `PlaceholderUser`)

OpenProject **core already ships a `PlaceholderUser` model** — but its creation
is hard-gated behind the Enterprise token:

```ruby
EnterpriseToken.allows_to?(:placeholder_users)
```

On a Community Edition instance (no EE token) you simply **cannot create** core
placeholder users — the admin controller and API both refuse with
"Placeholder Users is only available in the OpenProject Enterprise edition."

This plugin gives CE the same capability **without** touching or duplicating
core's gated class:

| Aspect            | Core (EE-gated)            | This plugin (CE)                                  |
| ----------------- | -------------------------- | ------------------------------------------------- |
| STI `type` value  | `PlaceholderUser`          | `PlaceholderUsers::PlaceholderUser` (namespaced)  |
| Table             | `users` (STI on Principal) | `users` (STI on Principal) — same table, no dup   |
| Admin path        | `/placeholder_users`       | `/admin/placeholder_users`                        |
| Availability      | Enterprise only            | Always (Community)                                |

Because the STI `type` value and the route are distinct, the two never collide:
this is a thin, additive management extension, not a re-implementation.

## What it adds

- **Model** `PlaceholderUsers::PlaceholderUser < ::Principal` — a Principal STI
  subtype on the shared `users` table. **Authentication is structurally
  impossible**: `active_for_authentication?`, `check_password?`, `logged?` all
  return `false`; `password=`, `login=`, `mail=` are no-ops; `login`/`mail`/
  `password` read as `nil`.
- **Admin controller** at `/admin/placeholder_users` (`require_admin` on every
  action) — list / create / edit / delete.
- **Promote-to-real-user service** (`ConvertToUserService`) — flips the STI
  `type` to `User` **in place, preserving the primary key**, so every existing
  `work_packages.assigned_to_id` / `responsible_id` reference transfers
  automatically. The promoted account starts in `invited` status.
- **Migration** — a partial index `idx_op_phusers_placeholder_users` on
  `users(id) WHERE type = 'PlaceholderUsers::PlaceholderUser'` for fast lookups.
  **No new table** is created (the user is STI on `users`).
- Admin menu entry, routes, EN + VI locales.

## Security

- Placeholders can never sign in: all credential/session paths are overridden to
  return a non-authenticating value and the record carries no usable login or
  password. A request spec asserts this.
- Every controller action is guarded by OpenProject's built-in `require_admin`
  (OP enforces a zero-trust authorization check per action).
- Finds are scoped to the placeholder STI subtype, so a real `User` id can never
  be resolved through this controller (IDOR-safe).

## Install

Already wired into `/Gemfile.plugins`:

```ruby
gem "openproject-placeholder_users", path: "plugins/openproject-placeholder-users"
```

Rebuild the app image / run migrations as per the repo's Docker workflow.

## Verify-against-running-image notes

A few core API touchpoints are flagged with `verify:` comments in the source and
should be confirmed against the running `openproject/openproject:17-slim` image:

- The STI `type` column is `type` and the principals table is `users`.
- `Principal.statuses` / `User.statuses` enum keys (`:locked`, `:invited`).
- `Principal`/`User` expose a `lastname` column used here to store the label.

If any differ, adjust the model accessors, the migration `where:` clause, and the
service's `update_columns` attribute names accordingly.
