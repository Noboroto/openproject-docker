# openproject-dashboards_plus

Custom dashboard widgets for OpenProject 17 (Community Edition), implemented as
an original Rails engine plugin via the official
`OpenProject::Plugins::ActsAsOpEngine` API. No core monkey-patching, no
Enterprise Edition source.

## Widgets

- **Project health KPI card** — open / closed / overdue work-package counts.
- **Work-package status summary** — counts grouped by status.
- **Budget widget** — per-project budgets with amount / spent / remaining /
  percent-used and a progress bar. Reuses `TimeReports::BudgetSummary` from the
  **openproject-time_reports** plugin (soft dependency: when that plugin is
  absent the widget renders a hint instead of failing).

The widgets are server-rendered and reachable at
`/projects/:project_id/dashboards_plus` (project module `dashboards_plus`,
permission `view_dashboards_plus_widgets`). They are also offered to OP's Grids
dashboard via `Grids::Configuration.register_widget`.

## Grids registration caveat

`verify against running 17-slim image`: in OP 17 the real signature is
`Grids::Configuration.register_widget(identifier_string, grid_classes)` (a Grid
subclass / array), **not** the `modules:` keyword shown in some older docs. The
engine initializer tries the modern form first, falls back to the keyword form,
and rescues any signature drift so a boot never fails on this optional
integration. OP 17 dashboard widgets are normally `Grids::WidgetComponent`
ViewComponents; if full Grids integration is required, wrap the presenters in a
`Grids::WidgetComponent` subclass — the server-rendered route works regardless.

## Installation

```ruby
# Gemfile.plugins
gem "openproject-dashboards_plus", path: "plugins/openproject-dashboards-plus"
# install alongside time_reports for the budget widget:
gem "openproject-time_reports",   path: "plugins/openproject-time-reports"
```

then `bundle install`.
