# openproject-custom_fields_plus

Adds advanced custom field types to OpenProject CE:

- **Multi-select list** — select multiple options from a list
- **Hierarchy (tree)** — options with parent/child relationships
- **Multi-user** — select multiple users
- **Multi-version** — select multiple versions

## Feature flag

Disabled by default. Enable via Administration → Plugins → Custom Fields Plus → `enabled: true`.

## Scope

Fields can be scoped to specific projects and/or groups. Leave blank for global visibility.

## Architecture

- New fields are stored in `op_cfp_advanced_fields` (plugin-namespaced).
- Options in `op_cfp_field_options` (supports hierarchy via `parent_id`).
- Values in `op_cfp_field_values` (polymorphic, per work package).
- Renders on WP show/print via `work_packages_show_attributes` view hook.
- Angular inline-edit does **not** render these fields (known limitation — use the dedicated XHR panel).

## Known limitations

- Advanced CFs do not appear in the Angular inline-edit form (hook only reaches Rails-rendered show/print).
- Not integrated into the WP query/filter engine.
