# OpenProject Branding

Custom branding for an OpenProject instance: replace the logo/favicon, set
primary/accent colors, and inject sanitized custom CSS — **without rebuilding the
Docker image**. Administration → Branding.

This is an original implementation built only against OpenProject's public plugin
API (`OpenProject::Plugins::ActsAsOpEngine`). It does **not** contain, copy, or
bypass any OpenProject Enterprise (EE) source or license check.

## Features

- Primary / accent color pickers, surfaced as CSS variables
  (`--branding-primary`, `--branding-accent`) on `:root`.
- Logo / favicon upload (PNG, JPG, WEBP, SVG), capped at 1 MB.
- Free-form custom CSS, **sanitized server-side**.
- View-hook injection into every layout `<head>` (no core templates edited).
- `?branding=off` safe-mode query param to bypass injection if custom CSS breaks
  the UI, plus a "Reset to defaults" button.
- English + Vietnamese locales.

## How it works

| Concern        | Where                                                         |
|----------------|--------------------------------------------------------------|
| Colors, CSS    | OpenProject `Setting` store (`plugin_openproject_branding`)   |
| Logo binary    | `Branding::Theme` model, table `op_branding_themes`           |
| CSS build      | `Branding::CssCompiler` (sanitizes + emits `<style>` body)    |
| Head injection | `OpenProject::Branding::Hooks` → `app/views/hooks/_theme_head.html.erb` |

## Security

Stored XSS via custom CSS is the dominant risk. `CssCompiler` sanitizes every
admin-supplied value server-side:

- strips any `</style>` sequence (prevents breaking out of the `<style>` element);
- strips `@import` rules (prevents loading remote CSS);
- strips `expression(` (legacy IE JS execution);
- neutralizes `url(...)` whose scheme is not `data:` or `https:` (blocks
  `javascript:`, `http:`, etc.);
- color values are validated against a strict hex/rgb(a)/hsl(a)/named pattern and
  fall back to defaults when invalid.

Logo handling:

- MIME type restricted to `image/png`, `image/jpeg`, `image/webp`,
  `image/svg+xml`; size capped at 1 MB.
- **SVG is sanitized** (`<script>`, `on*` handlers, and `javascript:` hrefs
  removed) before storage. For stronger guarantees, swap the built-in scrubber
  for a dedicated library (e.g. `loofah` with an SVG scrubber).
- Logo is served via a controller action with the correct image `Content-Type`
  and `X-Content-Type-Options: nosniff` — never as raw HTML.

## Version-dependent integration points (verify against the running 17-slim image)

- **View hook name** `:view_layouts_base_html_head` — confirm it still exists:
  ```
  docker run --rm openproject/openproject:17-slim \
    grep -rn "view_layouts_base_html_head" /app/app/views
  ```
  If renamed, update `lib/openproject/branding/hooks.rb`.
- **Rails version** for the migration superclass (`ActiveRecord::Migration[7.1]`):
  ```
  docker run --rm openproject/openproject:17-slim \
    cat /app/Gemfile.lock | grep -E '^    rails '
  ```

## Installation (dev container)

1. Add to `Gemfile.plugins`:
   ```ruby
   gem "openproject-branding", path: "plugins/openproject-branding"
   ```
2. `bundle install`
3. `bundle exec rails db:migrate`
4. Restart the web process; the menu item appears under Administration → Branding.

## Tests

```
bundle exec rspec plugins/openproject-branding/spec
```

- `spec/models/branding/theme_spec.rb` — model validations + `CssCompiler`
  sanitization.
- `spec/requests/branding/admin_settings_spec.rb` — non-admin 403, admin 200,
  `Setting` update, logo storage, malicious-CSS sanitization.

## License

GPL-3.0-or-later (same family as OpenProject Community Edition).
