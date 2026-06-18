# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/audit_trail/version"

Gem::Specification.new do |s|
  s.name        = "openproject-audit_trail"
  s.version     = OpenProject::AuditTrail::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Append-only audit trail / security logging for OpenProject"
  s.description = "Records security-relevant events (membership/role changes, " \
                  "project deletion, user activation, login events) into an " \
                  "append-only, immutable audit table with an admin viewer and " \
                  "CSV export. Subscribes to OpenProject's published " \
                  "ActiveSupport::Notifications — no core monkey-patching. " \
                  "Secrets (passwords, tokens) are scrubbed before persistence."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins. This plugin needs no third-party runtime gems (CSV ships
  # with Ruby; retention runs on the core GoodJob backend).
end
