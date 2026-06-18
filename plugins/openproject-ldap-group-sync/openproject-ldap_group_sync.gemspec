# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/ldap_group_sync/version"

Gem::Specification.new do |s|
  s.name        = "openproject-ldap_group_sync"
  s.version     = OpenProject::LdapGroupSync::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "LDAP group membership synchronization for OpenProject"
  s.description = "Maps LDAP groups (by distinguished name) to OpenProject groups " \
                  "and synchronizes membership so that OpenProject group membership " \
                  "mirrors LDAP, on a schedule and optionally after each LDAP login. " \
                  "Builds on CE LdapAuthSource authentication; all membership writes " \
                  "go through core Groups services so ACLs and journals are respected."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency.
  #
  # `net-ldap` is already a CE dependency (it powers LdapAuthSource), so it is
  # NOT re-declared here to avoid version conflicts with OP's pinned gem.
end
