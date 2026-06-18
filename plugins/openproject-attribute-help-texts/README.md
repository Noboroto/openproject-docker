# openproject-attribute-help-texts

A **thin, view-hook-only** OpenProject plugin that enhances the visibility and
keyboard-accessibility of the attribute help-text tooltips.

## IMPORTANT: Core already provides this feature

OpenProject **Community Edition (free, non-Enterprise)** already ships the full
"Attribute help texts" feature. Verified against `opf/openproject` (OP 17):

| Capability | Provided by core (CE) |
|---|---|
| Admin CRUD UI | `/admin/attribute_help_texts` (core `AttributeHelpTextsController`) |
| Storage / model | `AttributeHelpText`, `AttributeHelpText::WorkPackage`, `AttributeHelpText::Project` |
| Authorization | global permission `:edit_attribute_help_texts` (`authorize_global`) |
| Rendering | a "?" trigger next to attribute labels + a help-text dialog, server-rendered and sanitized |
| Enterprise gate | **None** — it is NOT an Enterprise add-on (no `enterprise_feature` flag on the menu item) |

Because core fully covers authoring, storage, permissions, and rendering,
**re-implementing it would be pure duplication** (a second admin menu, a second
table, a second tooltip). This plugin therefore deliberately does **NOT**:

- create any database table or migration,
- define any model,
- add an admin controller or admin menu entry,
- define any routes,
- expose any read endpoint.

## What this plugin actually does

It injects one small, **static, server-authored** `<style>` block into the
layout `<head>` (via the `view_layouts_base_html_head` view hook) that:

- makes the existing core help-text "?" trigger easier to notice (cursor + hover
  opacity), and
- adds a visible `:focus-visible` outline so the trigger is keyboard-friendly.

No user input is interpolated into the CSS, so there is no XSS surface. The
selectors target core's existing markup; if core renames its classes the rules
simply no-op (no breakage).

### Safe-mode escape hatch

Append `?aht_enhance=off` to any URL to skip the injected CSS for that request.

## Architecture & conventions

This plugin follows `OP17-PLUGIN-CONVENTIONS.md`:

- `require "open_project/plugins"` (underscore form).
- Engine ignores its own `lib/` in zeitwerk (manual require) to avoid the
  `Openproject` camelize crash on eager-load.
- The view hook class is loaded in `config.to_prepare` (not an initializer),
  because `OpenProject::Hook` / `ApplicationHelper` are not available earlier.
- The hook partial guards `controller.params` with a `rescue` (no live request
  in the view-hook context).
- No `openproject-core` gem dependency.
- Valid octicon (`checklist`) referenced in the engine for any future menu use
  (currently no menu is registered, to avoid duplicating core's admin menu).

## Files

```
openproject-attribute-help-texts/
├── lib/
│   ├── openproject-attribute-help-texts.rb        # gem entry
│   └── openproject/attribute_help_texts/
│       ├── version.rb
│       ├── engine.rb                               # zeitwerk ignore + to_prepare hook load
│       └── hooks.rb                                # ViewListener (view_layouts_base_html_head)
├── app/views/attribute_help_texts/_head.html.erb   # injected static CSS (guarded params)
├── config/routes.rb                                # intentionally empty
├── config/locales/{en,vi}.yml
├── openproject-attribute-help-texts.gemspec
└── README.md
```

## Installation

Add to `/Gemfile.plugins`:

```ruby
gem "openproject-attribute-help-texts",
    path: "plugins/openproject-attribute-help-texts"
```

Then rebuild per `OP17-PLUGIN-CONVENTIONS.md` (install `git` + `build-essential`,
unset bundler deployment/frozen). No migration to run.

## If you need MORE than core offers

If a future requirement exceeds core (e.g. additional scopes beyond WorkPackage/
Project, or a different tooltip presentation), prefer extending core's
`AttributeHelpText` model and its dialog rather than adding a parallel store.
Should you ever add a companion table, follow the conventions: use
`ActiveRecord::Migration[7.1]` with an `op_aht_`-namespaced table.
