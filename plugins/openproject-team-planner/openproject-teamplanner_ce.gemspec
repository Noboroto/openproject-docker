# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/teamplanner_ce/version"

Gem::Specification.new do |s|
  s.name        = "openproject-teamplanner_ce"
  s.version     = OpenProject::TeamplannerCe::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Read-only team planner (resource/assignee calendar) for OpenProject"
  s.description = "Adds a project-scoped, read-only resource calendar: rows are assignees, " \
                  "columns are days across a date range, and each assignee's work packages " \
                  "are rendered as bars over their start/due dates. Reads work packages " \
                  "exclusively through WorkPackage.visible(current_user) so read ACL always " \
                  "applies; persists only per-user saved-view preferences. Original " \
                  "re-implementation built on the Community Edition; no Enterprise source is used."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib,frontend}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin needs no
  # third-party runtime gems beyond what the core app already provides.
end
