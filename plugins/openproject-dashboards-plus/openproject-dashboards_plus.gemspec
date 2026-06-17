# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/dashboards_plus/version"

Gem::Specification.new do |s|
  s.name        = "openproject-dashboards_plus"
  s.version     = OpenProject::DashboardsPlus::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Custom dashboard widgets for OpenProject"
  s.description = "Adds project-health KPI cards, a cross-project work-package " \
                  "status summary, and a budget widget (spent / remaining / " \
                  "percent-used, backed by openproject-time_reports) to OP " \
                  "dashboards."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # The budget widget reuses TimeReports::BudgetSummary. The dependency is soft
  # (guarded with `defined?`), so it is documented rather than hard-required here
  # to keep the plugins independently installable.

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
end
