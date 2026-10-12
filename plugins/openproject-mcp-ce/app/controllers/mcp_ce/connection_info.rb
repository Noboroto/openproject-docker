# frozen_string_literal: true

module McpCe
  # Connection details shared by the admin page and the per-user My account page,
  # so both always show the same client path and copy-ready snippets.
  module ConnectionInfo
    # The MCP server runs in per-user mode: each client authenticates with the
    # connecting user's OWN OpenProject API token, sent as this header. Snippets
    # embed a placeholder the user replaces with a token from My account → Access
    # tokens. (The server also accepts `Authorization: Bearer <token>`.)
    TOKEN_HEADER = "X-OpenProject-Token"
    TOKEN_PLACEHOLDER = "opapi-YOUR_TOKEN"

    # Optional: an API token cannot be limited to one project, so a client may
    # send this header to make the MCP server refuse anything outside that
    # project (identifier or numeric id). It narrows the token, never widens it.
    PROJECT_HEADER = "X-OpenProject-Project"
    PROJECT_PLACEHOLDER = "your-project-identifier"

    private

    # Sets the ivars the `_client_setup` partial renders.
    def assign_connection_info
      @settings     = current_settings
      @base_url     = base_url
      @mcp_endpoint = join_url(@base_url, "mcp")

      # Public endpoint is DYNAMIC: derived from the OpenProject host, so the guide
      # is correct on any domain without hardcoding. An explicit mcp_public_url
      # setting overrides the derived value.
      configured = @settings["mcp_public_url"].to_s.strip
      @public_base     = configured.presence || suggested_public_base
      @public_derived  = configured.blank?
      @public_endpoint = @public_base.present? ? join_url(@public_base, "mcp") : nil

      # The URL clients connect to: the public (proxy) endpoint when available,
      # else the in-stack one.
      @client_path  = @public_endpoint.presence || @mcp_endpoint
      @snippets        = client_snippets(@client_path)
      @scoped_snippets = client_snippets(@client_path, project: PROJECT_PLACEHOLDER)
      @token_header    = TOKEN_HEADER
      @project_header  = PROJECT_HEADER
    end

    def current_settings
      Setting.plugin_openproject_mcp_ce || {}
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
    # canonical deployment domain regardless of how the user reached this page.
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
    # With `project:` the snippets also send PROJECT_HEADER.
    def client_snippets(url, project: nil)
      headers = { TOKEN_HEADER => TOKEN_PLACEHOLDER }
      headers[PROJECT_HEADER] = project if project

      cli_flags  = headers.map { |k, v| %(--header "#{k}: #{v}") }.join(" ")
      json_hdrs  = headers.map { |k, v| %("#{k}": "#{v}") }.join(", ")
      toml_hdrs  = headers.map { |k, v| %("#{k}" = "#{v}") }.join(", ")
      {
        "claude_code" =>
          %(claude mcp add --transport http openproject #{url} #{cli_flags}),
        "vscode" => <<~JSON.strip,
          // .vscode/mcp.json
          {
            "servers": {
              "openproject": {
                "type": "http",
                "url": "#{url}",
                "headers": { #{json_hdrs} }
              }
            }
          }
        JSON
        "codex" => <<~TOML.strip,
          # ~/.codex/config.toml
          [mcp_servers.openproject]
          url = "#{url}"
          http_headers = { #{toml_hdrs} }
        TOML
        "json" => <<~JSON.strip
          {
            "mcpServers": {
              "openproject": {
                "type": "http",
                "url": "#{url}",
                "headers": { #{json_hdrs} }
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
  end
end
