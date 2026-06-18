# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/placeholder_users/version"

Gem::Specification.new do |s|
  s.name        = "openproject-placeholder_users"
  s.version     = OpenProject::PlaceholderUsers::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "CE placeholder users for OpenProject (no-login assignees)"
  s.description = "Adds login-less placeholder principals usable as work package " \
                  "assignees/responsibles for resource planning before a real " \
                  "account exists, plus an admin UI and a promote-to-real-user " \
                  "service. CE-native: does NOT use core's Enterprise-gated " \
                  "PlaceholderUser STI type."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. No third-party runtime gems
  # are required beyond what the core app already provides.
end
