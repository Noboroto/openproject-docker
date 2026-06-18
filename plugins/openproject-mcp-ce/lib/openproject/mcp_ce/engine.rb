# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module McpCe
    # Rails engine + OpenProject plugin registration for "MCP-CE".
    #
    # MCP-CE is a thin, admin-only companion to the standalone OpenProject MCP
    # server (the `op-mcp` service already defined in docker-compose). It does NOT
    # run the MCP server itself — it only surfaces, inside OpenProject:
    #   1. the connection PATH/URL AI clients should point at, and
    #   2. a live HEALTH CHECK against that server.
    #
    # Settings-only (Setting store) — NO database table, hence NO migration:
    # nothing to migrate, so deploying it can never block a production DB migrate.
    class Engine < ::Rails::Engine
      engine_name :openproject_mcp_ce

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_mcp_ce.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-mcp-ce",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # In-stack base URL of the op-mcp service (Docker network name).
                   # The MCP protocol endpoint is <base>/mcp; health is <base>/health.
                   "mcp_base_url" => "http://op-mcp:8000",
                   # Externally reachable URL clients use (set once a proxy/subdomain
                   # is wired in NPM). Blank = not yet exposed publicly.
                   "mcp_public_url" => ""
                 }
               } do
        # Global, admin-only feature: no project_module. Adds "MCP Server" under
        # Administration. Guarded by require_admin in the controller.
        menu :admin_menu,
             :mcp_ce_settings,
             { controller: "/mcp_ce/admin_settings", action: :show },
             caption: :"mcp_ce.menu_caption",
             icon:    "pulse",
             after:   :settings
      end
    end
  end
end
