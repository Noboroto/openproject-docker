# frozen_string_literal: true

OpenProject::Application.routes.draw do
  scope "admin", as: "mcp_ce" do
    get   "mcp",              to: "mcp_ce/admin_settings#show",          as: :settings
    patch "mcp",              to: "mcp_ce/admin_settings#update"
    put   "mcp",              to: "mcp_ce/admin_settings#update"
    post  "mcp/health_check", to: "mcp_ce/admin_settings#health_check", as: :health_check
  end
end
