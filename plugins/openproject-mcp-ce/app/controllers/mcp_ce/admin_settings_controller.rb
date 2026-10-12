# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module McpCe
  # Administration -> MCP Server.
  #
  # Admin-only (OpenProject's built-in `require_admin`). Surfaces the connection
  # path for the standalone op-mcp server, runs a server-side health check
  # against it, and edits its two URLs in the `Setting` store — no DB table.
  # Employees get the read-only connection guide under My account instead.
  class AdminSettingsController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :mcp_ce_settings

    # Timeouts for the health probe (seconds). Kept short so a hung/unreachable
    # server never blocks the admin request thread for long.
    HEALTH_OPEN_TIMEOUT = 3
    HEALTH_READ_TIMEOUT = 3

    include ConnectionInfo

    def show
      assign_connection_info
      @health_url = join_url(@base_url, "health")
      @health     = flash[:mcp_health]
    end

    def update
      Setting.plugin_openproject_mcp_ce =
        current_settings.merge(settings_params.to_h)

      flash[:notice] = t(:"mcp_ce.saved")
      redirect_to action: :show
    end

    # Pings <base>/health server-side and stashes the result for the show page.
    # The base URL is admin-configured (no per-request user-supplied host), so
    # this is not an open SSRF vector.
    def health_check
      flash[:mcp_health] = probe_health(join_url(base_url, "health"))
      redirect_to action: :show
    end

    private

    def settings_params
      params.require(:settings).permit(:mcp_base_url, :mcp_public_url)
    end

    # Returns a plain hash (flash-serializable): reachable?, status, latency, msg.
    def probe_health(url)
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        return { "ok" => false, "message" => t(:"mcp_ce.health.bad_url") }
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = HEALTH_OPEN_TIMEOUT
      http.read_timeout = HEALTH_READ_TIMEOUT

      response = http.get(uri.request_uri)
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      ok = response.is_a?(Net::HTTPSuccess)
      {
        "ok"         => ok,
        "status"     => response.code,
        "latency_ms" => latency_ms,
        "body"       => parse_body(response.body),
        "message"    => ok ? t(:"mcp_ce.health.ok") : t(:"mcp_ce.health.bad_status", status: response.code)
      }
    rescue StandardError => e
      # Connection refused / timeout / DNS -> server is down or unreachable.
      { "ok" => false, "message" => t(:"mcp_ce.health.unreachable", error: e.message) }
    end

    def parse_body(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      body.to_s.byteslice(0, 200)
    end
  end
end
