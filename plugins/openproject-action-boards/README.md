# openproject-action_boards

Agile **action boards** for OpenProject: project-scoped boards where dragging a
work-package card between columns performs an action — change its **status**,
**assignee**, or **version**.

This is an **original re-implementation** of the action-board *idea* built on the
Community Edition. It contains **no OpenProject Enterprise source** and never
strips or bypasses any license check. AGPLv3.

## How it works

- Each `Board` has an `action_type` (`status` | `assignee` | `version`) and a set
  of ordered `Column`s. A column's `value_id` is the target attribute value
  (status_id / user_id / version_id) it represents.
- `BoardsController#show` loads the project's **visible** work packages and
  buckets them into columns by the board's grouping attribute.
- Dropping a card issues `PATCH /projects/:id/action_boards/:board_id/move`.
  `CardMovesController#update` validates the target column belongs to the board,
  then calls `ActionBoards::CardMover`.
- **Every move goes through the core `WorkPackages::UpdateService`.** No attribute
  is written directly, so OpenProject's workflow rules, contracts, and ACL always
  apply. An **illegal status transition fails the contract → HTTP 422**, and the
  card is reverted in the UI. The work package is never silently changed.

### Why not the Grids API?

The plan suggested layering boards onto OpenProject's Grids API. We instead use
dedicated namespaced tables (`op_boards_boards`, `op_boards_columns`) for an
explicit, testable schema, while still routing all writes through the core
service layer. To surface boards as dashboard widgets later, register them via
`Grids::Configuration.register_widget` (verify that API against the running
image).

## Permissions (project module `action_boards`)

| Permission              | Allows                                        |
|-------------------------|-----------------------------------------------|
| `view_action_boards`    | list and view boards                          |
| `manage_action_boards`  | create/delete boards, move cards (drop PATCH) |

Enable the **Action boards** module in *Project settings → Modules*.

## Frontend

First iteration is **server-rendered** columns plus a thin Stimulus controller
(`frontend/board_drag_controller.js`) that issues the move PATCH and reverts on a
422. A full OpenProject-native experience would register an **Angular** component
under `frontend/module/` via the OP frontend module system
(<https://www.openproject.org/docs/development/frontend/>).

## Layout

```
app/
  controllers/action_boards/{boards_controller,card_moves_controller}.rb
  models/action_boards/{board,column}.rb
  services/action_boards/card_mover.rb
  helpers/action_boards/boards_helper.rb
  views/action_boards/boards/{index,new,show}.html.erb
config/{routes.rb, locales/{en,vi}.yml}
db/migrate/{...create_op_boards_boards,...create_op_boards_columns}.rb
frontend/board_drag_controller.js
lib/openproject/action_boards/{engine,version}.rb
spec/{models,services,requests}/action_boards/*.rb
```

## Hard constraints honored

- Original work only; no EE source; no license bypass.
- Official `OpenProject::Plugins::ActsAsOpEngine` `register` DSL — no core
  monkey-patching.
- Rails 7.1 migrations; namespaced tables (`op_boards_*`).
- All writes go through core services — workflow/ACL never bypassed.

## Verify against the running 17-slim image

These OpenProject APIs are version-sensitive and are flagged with
`VERIFY`/`# VERIFY` comments in the source:

- `WorkPackages::UpdateService.new(user:, model:).call(**attrs)` signature and the
  `ServiceResult` interface (`success?`, `errors`, `result`).
- `permission ..., permissible_on: :project` keyword (required in OP 13.1+).
- `WorkPackage.visible(user)` scope name.
- `User#allowed_in_project?` vs `User#allowed_to?` permission check.
- Stimulus/plugin frontend controller registration path.
- `Grids::Configuration.register_widget` (only if integrating as a widget).
- Spec factories: `member_with_permissions`, `:project_role`, `:workflow`.

Confirm Rails version:

```
docker run --rm openproject/openproject:17-slim \
  cat /app/Gemfile.lock | grep -E '^    rails '
```

## Installation

Add to `Gemfile.plugins`:

```ruby
gem "openproject-action_boards", path: "plugins/openproject-action-boards"
```

then `bundle install` and `rails db:migrate`.
