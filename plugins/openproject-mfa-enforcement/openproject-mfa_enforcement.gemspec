# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/mfa_enforcement/version"

Gem::Specification.new do |s|
  s.name        = "openproject-mfa_enforcement"
  s.version     = OpenProject::MfaEnforcement::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Organization-wide 2FA enforcement policy for OpenProject"
  s.description = "Adds an organization-wide enforcement policy on top of " \
                  "OpenProject Community Edition's built-in TOTP/2FA: require all " \
                  "(or a selected group of) users to configure 2FA, with a " \
                  "configurable grace period before access is blocked. Does NOT " \
                  "reimplement TOTP — it only gates on CE's existing 2FA result."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins. This plugin reuses CE's bundled two_factor_authentication
  # module at runtime and needs no third-party runtime gems.
end
