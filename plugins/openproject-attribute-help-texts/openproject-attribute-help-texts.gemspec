# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/attribute_help_texts/version"

Gem::Specification.new do |s|
  s.name        = "openproject-attribute-help-texts"
  s.version     = OpenProject::AttributeHelpTexts::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Accessibility/visibility enhancement for OpenProject's built-in attribute help texts"
  s.description = "OpenProject Community Edition already ships the full 'Attribute help texts' " \
                  "feature (admin CRUD + label tooltips). This thin plugin only injects a small, " \
                  "sanitized CSS/a11y enhancement for the existing core tooltips via a view hook. " \
                  "It adds no storage, no admin controller, and no routes."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin needs no
  # third-party runtime gems beyond what the core app already provides.
end
