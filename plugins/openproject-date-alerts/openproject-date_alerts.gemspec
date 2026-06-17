# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/date_alerts/version"

Gem::Specification.new do |s|
  s.name        = "openproject-date_alerts"
  s.version     = OpenProject::DateAlerts::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Date alerts / reminders for OpenProject work packages"
  s.description = "A background job scans work packages for upcoming or overdue start " \
                  "and due dates and creates de-duplicated in-app notifications (and " \
                  "optional email) for assignees, honouring per-user lead-time " \
                  "preferences and work-package visibility."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin relies only on the
  # background-job (GoodJob) and notification infrastructure the core app ships.
end
