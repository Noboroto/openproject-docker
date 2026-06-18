# OpenProject Project templates

Mark an existing project as a reusable **template**, then let authorized users
create brand-new projects from it. Cloning delegates to OpenProject's **core
`Projects::CopyService`** (the same engine the built-in "Copy project" uses), so
the work-package hierarchy, custom field values, members/roles, versions,
categories, wiki and ACLs are handled correctly. The plugin's value is the
**template registry + gallery + governance**, not re-implementing copy.

- Administration → Project templates: register/unregister templates.
- Top menu → Project templates (gallery): self-service "create from template".

## Hard constraints (this plugin obeys all four)

1. **Original implementation only.** Built from the *public feature description* of
   the OpenProject Enterprise "Project templates" add-on. No EE gem source was
   read, copied, decompiled, or transcribed; no license/enterprise token check is
   stripped, stubbed, or bypassed.
2. **Official engine API only.** Hooks through
   `OpenProject::Plugins::ActsAsOpEngine` (`register`, `permission`, `menu`,
   `settings`). No core-file monkey-patching. Cloning goes through the documented
   core `Projects::CopyService`.
3. **Rails 7.1+.** The migration subclasses `ActiveRecord::Migration[7.1]`. The
   table is namespaced (`op_projtpl_templates`).
4. **Quality bar.** Engine + namespaced migration · RSpec model + service +
   request specs · I18n `en` **and** `vi` · two global permissions + admin/gallery
   UI · README. Designed to load clean under `RAILS_ENV=production`.

## How it works

| Concern              | Where                                                              |
|----------------------|-------------------------------------------------------------------|
| Template registry    | `ProjectTemplates::Template` model, table `op_projtpl_templates`   |
| Cloning              | `ProjectTemplates::CreateFromTemplateService` → core `Projects::CopyService` |
| Management UI        | `project_templates/templates#index` (Administration)              |
| Gallery + flow       | `project_templates/templates#gallery` / `#new` / `#instantiate`   |
| Settings             | `plugin_openproject_project_templates` (`max_work_packages`, `copy_attachments`) |

### Permissions (both global — project creation is a global action)

- `manage_project_templates` — register/unregister templates (admin-style).
- `create_project_from_template` — browse the gallery + instantiate a project.

The controller gates every action with `authorize_global`, satisfying
OpenProject's zero-trust "every action must check authorization" rule. The clone
runs as the **current user** (never `User.system`) so core ACLs apply.

## Security

- Both permissions gate project creation and are verified before instantiation.
- Cloning runs as `current_user`, so the user can only copy what they may see and
  create; identifier uniqueness is enforced by the core service.
- IDOR-safe scoping: templates are loaded through `visible_templates` (public
  templates for ordinary users, all for managers), never a bare `Template.find`.
- **`max_work_packages` guard** (default 2000) refuses to clone an oversized
  template in a single request (DoS / long-transaction protection). Very large
  templates should be cloned via a background job.
- Attachment copying multiplies storage and is **off by default**
  (`copy_attachments=false`).

## Version-dependent integration points (verify against the running 17-slim image)

- **`Projects::CopyService` signature** — this plugin assumes:
  ```ruby
  Projects::CopyService.new(user:, source:)
    .call(target_project_params: <hash>, only: <array>)  # => ServiceResult
  ```
  Confirm the keyword names (`target_project_params`, `only`) and the result API
  (`success?`, `result`) on the image; adjust `CreateFromTemplateService` only.
- **`global: true`** permission keyword and **`authorize_global`** before_action —
  confirm both exist; recent releases also accept `permissible_on: :global`.
- **`Project.visible(user)` / `project.work_packages`** scope names.
- **Rails version** for the migration superclass:
  ```
  docker run --rm openproject/openproject:17-slim \
    cat /app/Gemfile.lock | grep -E '^    rails '
  ```

## Installation (dev container)

1. Add to `Gemfile.plugins`:
   ```ruby
   gem "openproject-project_templates", path: "plugins/openproject-project-templates"
   ```
2. `bundle install`
3. `bundle exec rails db:migrate`
4. Restart the web process. "Project templates" appears under Administration and
   (for authorized users) in the top menu.

## Tests

```
bundle exec rspec plugins/openproject-project-templates/spec
```

- `spec/models/...` — validations, unique project/name, public scope.
- `spec/services/...` — delegation to `Projects::CopyService`, `workspace_type`,
  attachment toggle, size guard, failure path.
- `spec/requests/...` — non-privileged 403, admin manage + gallery, instantiate
  redirect, too-large friendly error.

## License

GPL-3.0-or-later (same family as OpenProject Community Edition).
