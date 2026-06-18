# OpenProject Custom Work-Package Actions (`openproject-custom_actions`)

Config-driven, one-click custom actions for work packages — the Community-Edition
re-implementation of the Enterprise "Custom actions" feature. An admin defines a
catalog of actions (a set of **conditions** + a set of **attribute changes**); a
member then applies a matching action to a work package with a single click.

No scripting is involved: actions are plain data. Every change is applied through
the core `WorkPackages::UpdateService`, so workflow rules, contracts and the
acting user's own permissions are always enforced — an illegal change fails with
HTTP **422** and the work package is left unchanged. An action can never escalate
privileges.

## How it works

```
admin defines CustomAction  ──►  member clicks "Apply"
  conditions: {status_id, type_ids}        │
  change_set: {status_id,                   ▼
               assigned_to_id,     ExecutionsController#create
               priority_id}          (find_project + authorize,
                                       :execute_custom_actions)
                                            │
                                            ▼
                                  ExecuteActionService
                                  ├─ Applicability re-checked server-side
                                  └─ WorkPackages::UpdateService  ◄── CORE
                                       (workflows + contracts + ACL + journals)
```

## Surfaces

| Surface | Route | Auth |
|---|---|---|
| Admin catalog | `/custom_actions/actions` | `require_admin` |
| Apply action | `POST /projects/:id/custom_actions/:action_id/work_packages/:wp_id/apply` | `find_project` + `authorize` (`:execute_custom_actions`, `permissible_on: :project`) |

The `custom_actions/executions/_buttons` partial renders the applicable buttons
for a work package (only when the user has `:execute_custom_actions`).

## Data model

Single namespaced table `op_cact_custom_actions`:

| Column | Type | Notes |
|---|---|---|
| `name` | string | |
| `position` | integer | display order |
| `conditions` | jsonb | `{ "status_id": 1, "type_ids": [3,4] }` (each key optional, AND-combined) |
| `change_set` | jsonb | `{ "status_id": 7, "assigned_to_id": 12, "priority_id": 5 }` (named `change_set`, not `changes`, to avoid clashing with `ActiveModel::Dirty`) |

Only `status_id`, `assigned_to_id`, `priority_id` are whitelisted as changeable
(`CustomAction::CHANGEABLE_ATTRIBUTES`).

## Conventions / hard rules followed

- `require "open_project/plugins"` (underscore form).
- Engine ignores this plugin's `lib/` in zeitwerk (manual require) — avoids the
  `Openproject` camelize eager-load crash.
- Octicon `workflow` for the admin menu.
- Permission declared with `permissible_on: :project`.
- Every controller action is auth-guarded (`require_admin` / `find_project +
  authorize`).
- All writes go through `WorkPackages::UpdateService` — never `update_column` /
  `update!`. Illegal → 422.
- Migration is `ActiveRecord::Migration[7.1]`, table prefixed `op_cact_`.
- No `openproject-core` gemspec dependency.

## Verify against the running 17-slim image

- `WorkPackages::UpdateService.new(user:, model:).call(**attrs)` signature and the
  `ServiceResult#success?/errors` API (flagged in `ExecuteActionService`).
- `WorkPackage.visible(user)` scope name.
- `User#allowed_in_project?` vs `allowed_to?` (helper handles both).
- `permissible_on:` keyword on the permission DSL.
- Exact Rails version for the migration base class.

## Install

Add to `/Gemfile.plugins`:

```ruby
gem "openproject-custom_actions", path: "plugins/openproject-custom-actions"
```

then rebuild and run migrations.
