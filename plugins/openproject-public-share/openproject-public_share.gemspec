# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/public_share/version"

Gem::Specification.new do |s|
  s.name        = "openproject-public_share"
  s.version     = OpenProject::PublicShare::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Tokenized public read-only links for work packages"
  s.description = "Generates tokenized public links exposing a single work package " \
                  "read-only to unauthenticated users. Stores only the SHA-256 digest " \
                  "of the token. Supports expiry, revocation, and a global kill-switch. " \
                  "Feature-flagged (default OFF). Highest-security plugin in Tier 3."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"
end
