# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/pdf_styler/version"

Gem::Specification.new do |s|
  s.name        = "openproject-pdf_styler"
  s.version     = OpenProject::PdfStyler::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Styled PDF export templates for OpenProject"
  s.description = "Admin-managed styled PDF export templates (cover, header, footer, " \
                  "font, accent colour). Adds a parallel export action alongside the " \
                  "core export — does not override core exports. Admin HTML is sanitized, " \
                  "never eval'd as ERB (no SSTI). Feature-flagged (default OFF)."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # Pure-Ruby PDF generation — no binary system dep (wkhtmltopdf/WeasyPrint).
  # If the OP image already ships WeasyPrint the RenderService detects it and
  # uses it instead; prawn is the safe fallback.
  # OP 17-slim already ships prawn 2.4.0, prawn-table 0.2.2, sanitize 7.0.0.
  # Use loose lower bounds so bundler picks the existing locked versions.
  s.add_dependency "prawn",       ">= 2.4", "< 3"
  s.add_dependency "prawn-table", "~> 0.2"
  s.add_dependency "sanitize",    ">= 6.0", "< 8"
end
