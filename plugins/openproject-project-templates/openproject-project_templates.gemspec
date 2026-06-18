# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/project_templates/version"

Gem::Specification.new do |s|
  s.name        = "openproject-project_templates"
  s.version     = OpenProject::ProjectTemplates::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Project templates for OpenProject (mark a project as a template, create new projects from it)"
  s.description = "Lets administrators mark existing projects as reusable templates and " \
                  "lets authorized users instantiate brand-new projects from a template. " \
                  "Cloning delegates to OpenProject's core Projects::CopyService so " \
                  "hierarchy, custom field values and ACLs are handled correctly."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency. This plugin needs no
  # third-party runtime gems beyond what the core app already provides.
end
