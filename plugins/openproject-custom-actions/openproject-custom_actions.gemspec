# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/custom_actions/version"

Gem::Specification.new do |s|
  s.name        = "openproject-custom_actions"
  s.version     = OpenProject::CustomActions::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Config-driven custom work-package actions (one-click status/assignee/priority changes)"
  s.description = "Admins define reusable custom actions: a set of conditions (status / type) " \
                  "plus a set of attribute changes (status, assignee, priority). Members apply " \
                  "a matching action to a work package with one click. Every change is routed " \
                  "through the core WorkPackages::UpdateService, so workflow rules, contracts and " \
                  "permissions always apply — an illegal change fails with 422 and never bypasses " \
                  "the ACL. Original re-implementation built on the Community Edition; no " \
                  "Enterprise source is used."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin needs no
  # third-party runtime gems beyond what the core app already provides.
end
