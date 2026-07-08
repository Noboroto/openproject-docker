# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module McpCe
  # Administration -> MCP Server.
  #
  # Admin-only (OpenProject's built-in `require_admin`). Surfaces the connection
  # path for the standalone op-mcp server and runs a server-side health check
  # against it. Persists only two URLs to the `Setting` store — no DB table.
  class AdminSettingsController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :mcp_ce_settings

    # Timeouts for the health probe (seconds). Kept short so a hung/unreachable
    # server never blocks the admin request thread for long.
    HEALTH_OPEN_TIMEOUT = 3
    HEALTH_READ_TIMEOUT = 3

    # The MCP server runs in per-user mode: each client authenticates with the
    # connecting user's OWN OpenProject API token, sent as this header. Snippets
    # embed a placeholder the user replaces with a token from My account → Access
    # tokens. (The server also accepts `Authorization: Bearer <token>`.)
    TOKEN_HEADER = "X-OpenProject-Token"
    TOKEN_PLACEHOLDER = "opapi-YOUR_TOKEN"

    def show
      @settings    = current_settings
      @base_url    = base_url
      @mcp_endpoint = join_url(@base_url, "mcp")
      @health_url   = join_url(@base_url, "health")

      # Public endpoint is DYNAMIC: derived from the OpenProject host the admin is
      # currently on, so the guide is correct on any domain without hardcoding.
      # An explicit mcp_public_url setting overrides the derived value.
      configured = @settings["mcp_public_url"].to_s.strip
      @public_base     = configured.presence || suggested_public_base
      @public_derived  = configured.blank?
      @public_endpoint = @public_base.present? ? join_url(@public_base, "mcp") : nil

      # The URL clients connect to: the public (proxy) endpoint when available,
      # else the in-stack one. Used for the copy-ready setup snippets.
      @client_path  = @public_endpoint.presence || @mcp_endpoint
      @snippets     = client_snippets(@client_path)
      @token_header = TOKEN_HEADER

      @health = flash[:mcp_health]
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

    def current_settings
      Setting.plugin_openproject_mcp_ce || {}
    end

    def settings_params
      params.require(:settings).permit(:mcp_base_url, :mcp_public_url)
    end

    def base_url
      url = current_settings["mcp_base_url"].to_s.strip
      url.presence || "http://op-mcp:8000"
    end

    # Derive the public MCP base URL from the configured OpenProject host
    # (OPENPROJECT_HOST__NAME -> Setting.host_name) + the instance protocol.
    # The MCP server is exposed on the SAME domain under the `/mcp` path, routed
    # by the proxy (Caddy/NPM forwards /mcp -> op-mcp:8000). So the public MCP
    # endpoint is simply `<scheme>://<host_name>/mcp` — no subdomain. Works for
    # localhost too. NOT derived from the live request, so the guide reflects the
    # canonical deployment domain regardless of how the admin reached this page.
    def suggested_public_base
      raw = Setting.host_name.to_s.strip
      return "" if raw.blank?

      scheme = Setting.protocol.presence || "https"
      "#{scheme}://#{raw}"
    end

    # Copy-ready client setup snippets for the given connection URL. Keyed by a
    # client id (matches the i18n labels + the view's clipboard-copy element ids).
    #
    # Per-user mode: every snippet carries the caller's API token via the
    # TOKEN_HEADER so the connecting user acts as themselves. The user swaps
    # TOKEN_PLACEHOLDER for a real token from My account → Access tokens.
    def client_snippets(url)
      hdr   = TOKEN_HEADER
      token = TOKEN_PLACEHOLDER
      {
        "claude_code" =>
          %(claude mcp add --transport http openproject #{url} --header "#{hdr}: #{token}"),
        "vscode" => <<~JSON.strip,
          // .vscode/mcp.json
          {
            "servers": {
              "openproject": {
                "type": "http",
                "url": "#{url}",
                "headers": { "#{hdr}": "#{token}" }
              }
            }
          }
        JSON
        "codex" => <<~TOML.strip,
          # ~/.codex/config.toml
          [mcp_servers.openproject]
          url = "#{url}"
          http_headers = { "#{hdr}" = "#{token}" }
        TOML
        "json" => <<~JSON.strip
          {
            "mcpServers": {
              "openproject": {
                "type": "http",
                "url": "#{url}",
                "headers": { "#{hdr}": "#{token}" }
              }
            }
          }
        JSON
      }
    end

    # Join a base and a path into a single URL without doubled/missing slashes.
    def join_url(base, path)
      "#{base.to_s.sub(%r{/+\z}, '')}/#{path}"
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
