# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/baselines/version"

Gem::Specification.new do |s|
  s.name        = "openproject-baselines"
  s.version     = OpenProject::Baselines::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Project baselines (point-in-time snapshots and diff) for OpenProject"
  s.description = "Snapshot a project's work-package state at a point in time and " \
                  "diff current state against that baseline using core OP journals. " \
                  "Read-only from journals — never writes to core journal tables. " \
                  "Feature-flagged (default OFF). No core monkey-patching."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"
end
