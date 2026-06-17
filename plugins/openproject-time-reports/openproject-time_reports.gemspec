# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/time_reports/version"

Gem::Specification.new do |s|
  s.name        = "openproject-time_reports"
  s.version     = OpenProject::TimeReports::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Advanced time tracking reports + cost/budget reporting for OpenProject"
  s.description = "Adds CSV export, a pivot view, hourly cost rates (per user / " \
                  "activity / project with effective-date versioning), a cost " \
                  "report (hours x rate), and project budgets with spent / " \
                  "remaining / percent-used tracking."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # `csv` is part of the OpenProject core bundle, but it ships as a default gem
  # that may be unbundled in future Rubies; declare it explicitly so the CSV
  # export service has a guaranteed dependency.
  s.add_dependency "csv"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency.
end
