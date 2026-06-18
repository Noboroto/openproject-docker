# openproject-pdf_styler

Styled PDF export templates for OpenProject CE.

## What it does

Adds an admin-managed PDF export template system with:

- Cover page (HTML, sanitized)
- Header / footer HTML
- Font family (Helvetica, Times, Courier)
- Accent color

A "Styled PDF Export" action is added to project work-package views alongside (not replacing) the core CSV/PDF export.

## PDF rendering

Uses **Prawn** (pure Ruby, no binary system dependencies). If the OpenProject image ships WeasyPrint, the RenderService can be extended to use it.

## Security

- Admin HTML is **sanitized** via `Sanitize` before use — never executed as ERB or template code (no SSTI).
- `<script>`, `<style>`, event handlers (`onerror`, `onclick`, etc.) stripped.
- Image `src` restricted to `https:` and `data:` URIs (SSRF mitigation).
- Export size capped by `max_work_packages` setting (default 200).

## Feature flag

Disabled by default. Enable via Administration → Plugins → PDF Styler → `enabled: true`.

## Known limitations

- Rich text / description not included in Prawn table (text-only rendering).
- No attachment thumbnails.
