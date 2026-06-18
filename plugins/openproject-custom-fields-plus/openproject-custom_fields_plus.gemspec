# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/custom_fields_plus/version"

Gem::Specification.new do |s|
  s.name        = "openproject-custom_fields_plus"
  s.version     = OpenProject::CustomFieldsPlus::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Advanced custom field types for OpenProject"
  s.description = "Adds multi-select list, hierarchy (tree), multi-user, and " \
                  "multi-version custom field types stored in plugin-namespaced " \
                  "tables. Renders via documented view hooks alongside core CFs. " \
                  "Feature-flagged (default OFF). No core monkey-patching."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"
end
