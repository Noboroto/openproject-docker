# OpenProject Team Planner

A project-scoped, **read-only** resource/assignee calendar for OpenProject
Community Edition. Rows are assignees; columns are days across a chosen date
range; each assignee's work packages render as bars over their start/due dates.
This is the Community re-implementation of the Enterprise "Team planner"
feature — no Enterprise source is used.

## What it does

- Adds a `teamplanner_ce` **project module** with a project-menu entry
  (octicon `calendar`, after Work packages).
- `show` renders a server-side grid of visible, assigned work packages
  overlapping the selected window.
- Per-user **saved views** persist a date range + assignee filter
  (`op_teamplanner_ce_saved_views`). No work-package tables are created.

## Security model

- Reads work packages **exclusively** via `WorkPackage.visible(current_user)`,
  then filters by project — a user never sees a card they cannot read.
- Controller uses `before_action :find_project, :authorize`; permissions are
  inferred from controller/action by OpenProject's zero-trust `authorize`.
  - `show` → `view_teamplanner_ce`
  - `save` / `destroy` → `manage_teamplanner_ce_views`
- Saved views are scoped to `(project, current_user)`, so a user can only read
  or destroy their own (no IDOR; satisfies `view.user_id == User.current.id`).
- Read-only v1 has no write path. If drag-to-reschedule is added later, route
  the change through `WorkPackages::UpdateService` — never raw `update`.

## Architecture

| Layer | File |
|-------|------|
| Engine / registration | `lib/openproject/teamplanner_ce/engine.rb` |
| Query (ACL-scoped) | `app/services/teamplanner_ce/assignment_query.rb` |
| Grid geometry (PORO) | `app/models/teamplanner_ce/assignment_grid.rb` |
| Saved view model | `app/models/teamplanner_ce/saved_view.rb` |
| Controller | `app/controllers/teamplanner_ce/planner_controller.rb` |
| Views | `app/views/teamplanner_ce/planner/{show,_row}.html.erb` |

`AssignmentQuery` returns `{ User => [WorkPackage, ...] }`; `AssignmentGrid`
converts each work package into a positioned bar (column offset + span, clamped
to the visible window) for the ERB template. The grid PORO does no DB access and
is trivially unit-testable.

## Routes (project-scoped)

`config/routes.rb` wraps everything in `scope "projects/:project_id", as: "project"`,
so generated helpers are **`project_`-prefixed**:

| Helper | Verb | Action |
|--------|------|--------|
| `project_teamplanner_ce_path(project)` | GET | `show` |
| `project_save_teamplanner_ce_path(project)` | POST | `save` |
| `project_teamplanner_ce_view_path(project, id)` | DELETE | `destroy` |

The views reference exactly these names.

## Where Angular would go

OpenProject's native Team planner is an Angular calendar with
drag-to-reschedule. A production-grade integration would register an Angular
component via the OP frontend module system and PATCH moves through
`WorkPackages::UpdateService`. This styled server-rendered grid is the
deliberate read-only first iteration; the ERB views note the insertion point.

## Installation

Registered in `/Gemfile.plugins`:

```ruby
gem "openproject-teamplanner_ce", path: "plugins/openproject-team-planner"
```

Then run the migration (`op_teamplanner_ce_saved_views`) and enable the
**Team planner** module in each project's settings.

## i18n

English + Vietnamese under `config/locales/{en,vi}.yml`.

## Conventions / verification notes

Built per `OP17-PLUGIN-CONVENTIONS.md`. Items to VERIFY against the running
`openproject/openproject:17-slim` image:

- `WorkPackage.visible(current_user)` scope name.
- `permissible_on:` keyword/value on the permission DSL.
- `User#allowed_in_project?` vs `#allowed_to?` (helper falls back).
- Exact `ActiveRecord::Migration[7.1]` version line.
