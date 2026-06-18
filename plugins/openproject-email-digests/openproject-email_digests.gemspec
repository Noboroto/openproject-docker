# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/email_digests/version"

Gem::Specification.new do |s|
  s.name        = "openproject-email_digests"
  s.version     = OpenProject::EmailDigests::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "Email digests and notification customization for OpenProject"
  s.description = "Batches accumulated work-package activity into periodic digest " \
                  "emails (daily/weekly) per user, with per-user delivery rules: " \
                  "mute by project or type and quiet-hours suppression. Digest " \
                  "items are visibility-filtered per recipient. Admins set the " \
                  "instance default send hour."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # OpenProject plugins resolve the core app via the `path:` entry in
  # Gemfile.plugins. This plugin relies only on the background-job (GoodJob),
  # mailer and notification infrastructure the core app ships.
end
