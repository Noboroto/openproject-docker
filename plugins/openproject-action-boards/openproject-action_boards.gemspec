# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/action_boards/version"

Gem::Specification.new do |s|
  s.name        = "openproject-action_boards"
  s.version     = OpenProject::ActionBoards::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Agile action boards for OpenProject (status / assignee / version drag-drop)"
  s.description = "Adds project-scoped action boards where dragging a work-package card " \
                  "between columns changes its status, assignee, or version. Every move is " \
                  "routed through the core WorkPackages::UpdateService so workflow rules and " \
                  "permissions always apply. Original re-implementation built on the " \
                  "Community Edition; no Enterprise source is used."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib,frontend}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin needs no
  # third-party runtime gems beyond what the core app already provides.
end
