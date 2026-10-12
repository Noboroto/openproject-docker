# frozen_string_literal: true

module McpCe
  # My account -> MCP Server.
  #
  # Read-only connection guide for every logged-in user: the client path and
  # copy-ready snippets. Health check, in-stack endpoint and settings stay on
  # the admin page — employees need only what their own client config uses.
  class ConnectionController < ::ApplicationController
    include ConnectionInfo

    before_action :require_login

    # OP enforces zero-trust: every action MUST declare an authorization check.
    # The page shows no data beyond instance-wide connection info, and the MCP
    # server itself acts with the caller's own token, so no permission applies.
    no_authorization_required! :show

    layout "my"

    menu_item :mcp_ce_connection

    def show
      assign_connection_info
    end
  end
end
