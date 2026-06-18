# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject/mcp_ce/version"

Gem::Specification.new do |s|
  s.name        = "openproject-mcp-ce"
  s.version     = OpenProject::McpCe::VERSION
  s.authors     = ["Your Organization"]
  s.email       = ["dev@example.com"]
  s.homepage    = "https://example.com"
  s.summary     = "In-app guide + health check for the OpenProject MCP server"
  s.description = "Admin-only companion to the standalone OpenProject MCP server " \
                  "(op-mcp). Surfaces the connection path AI clients should use " \
                  "and runs a live health check against the server. Settings-only " \
                  "— no database table, no migration."
  s.license     = "GPL-3.0-or-later"

  s.files         = Dir["{app,config,db,lib}/**/*", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.0"

  # NOTE: Do NOT add `s.add_dependency "openproject-core"` — no such gem exists.
  # Health checks use Ruby's stdlib net/http; no third-party runtime gems needed.
end
