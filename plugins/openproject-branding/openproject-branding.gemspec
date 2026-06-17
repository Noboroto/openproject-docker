# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/branding/version"

Gem::Specification.new do |s|
  s.name        = "openproject-branding"
  s.version     = OpenProject::Branding::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Custom branding for OpenProject (logo, colors, custom CSS)"
  s.description = "Lets administrators rebrand an OpenProject instance: replace the " \
                  "logo, set primary/accent colors, and inject sanitized custom CSS " \
                  "without rebuilding the Docker image."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin needs no
  # third-party runtime gems beyond what the core app already provides.
end
