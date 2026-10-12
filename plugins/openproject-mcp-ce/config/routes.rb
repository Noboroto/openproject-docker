# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # My account -> MCP Server (read-only connection guide, any logged-in user).
  scope "my", as: "mcp_ce" do
    get "mcp", to: "mcp_ce/connection#show", as: :connection
  end

  # Administration -> MCP Server (health check + settings, admin only).
  scope "admin", as: "mcp_ce" do
    get   "mcp",              to: "mcp_ce/admin_settings#show",          as: :settings
    patch "mcp",              to: "mcp_ce/admin_settings#update"
    put   "mcp",              to: "mcp_ce/admin_settings#update"
    post  "mcp/health_check", to: "mcp_ce/admin_settings#health_check", as: :health_check
  end
end
