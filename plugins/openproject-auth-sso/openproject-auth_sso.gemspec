# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/auth_sso/version"

Gem::Specification.new do |s|
  s.name        = "openproject-auth_sso"
  s.version     = OpenProject::AuthSso::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Enterprise SSO (SAML 2.0 / OpenID Connect) for OpenProject"
  s.description = "Adds DB-configurable SAML and OpenID Connect single sign-on to " \
                  "OpenProject, built on the standard OmniAuth strategies. Admins " \
                  "configure IdP metadata in the UI; local-password admin login " \
                  "always remains as a break-glass fallback."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # Genuine third-party runtime dependencies. Both are MIT-licensed, fully free
  # open-source OmniAuth strategies — we build on them rather than reimplement
  # SAML/OIDC. They must ALSO be listed in the repo-level Gemfile.plugins so
  # Bundler resolves them inside the OpenProject app.
  s.add_dependency "omniauth-saml"            # SAML 2.0 strategy (MIT)
  s.add_dependency "omniauth_openid_connect"  # OpenID Connect strategy (MIT)

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins, not via a gemspec dependency.
end
