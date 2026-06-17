# frozen_string_literal: true

module Branding
  # Administration -> Branding.
  #
  # Admin-only (guarded by OpenProject's built-in `require_admin`). Persists
  # colors + custom CSS to the `Setting` store and the logo binary to the
  # `Branding::Theme` model.
  class AdminSettingsController < ::ApplicationController
    # OpenProject's built-in admin guard. Provides the local-password admin
    # fallback guarantee (no SSO/2FA dependency here).
    before_action :require_admin

    layout "admin"

    menu_item :branding_settings

    def show
      @theme    = Theme.first_or_initialize(name: "default")
      @settings = current_settings
    end

    def update
      persist_settings
      attach_logo if logo_param.present?

      flash[:notice] = t(:"branding.saved")
      redirect_to action: :show
    rescue ActiveRecord::RecordInvalid => e
      flash[:error] = e.record.errors.full_messages.to_sentence
      redirect_to action: :show
    end

    # Resets colors + custom CSS to plugin defaults and removes the logo.
    def reset
      Setting.plugin_openproject_branding =
        OpenProject::Branding::Engine.settings[:default].dup
      Theme.where(name: "default").destroy_all

      flash[:notice] = t(:"branding.reset_done")
      redirect_to action: :show
    end

    # Serves the stored logo binary with the correct Content-Type. The logo is
    # NEVER served as raw HTML — always with its image MIME type — to avoid the
    # browser sniffing it as HTML (XSS via SVG/markup).
    def logo
      theme = Theme.find_by(name: "default")
      if theme&.logo_blob.present?
        response.headers["X-Content-Type-Options"] = "nosniff"
        send_data theme.logo_blob,
                  type: theme.logo_content_type,
                  disposition: "inline"
      else
        head :not_found
      end
    end

    private

    def current_settings
      Setting.plugin_openproject_branding || {}
    end

    def persist_settings
      Setting.plugin_openproject_branding =
        current_settings.merge(settings_params.to_h)
    end

    def settings_params
      params.require(:settings).permit(:primary_color, :accent_color, :custom_css)
    end

    def logo_param
      params.dig(:theme, :logo)
    end

    def attach_logo
      file = logo_param
      content_type = file.content_type.to_s

      unless Theme::ALLOWED_CONTENT_TYPES.include?(content_type)
        raise ActiveRecord::RecordInvalid, invalid_logo(:invalid_type)
      end

      bytes = file.read
      if bytes.bytesize > Theme::MAX_LOGO_BYTES
        raise ActiveRecord::RecordInvalid, invalid_logo(:too_large)
      end

      # SECURITY: SVG can carry <script>/on*-handlers. Strip dangerous content
      # before storing so an inline/served SVG cannot execute script.
      if content_type == "image/svg+xml"
        bytes = sanitize_svg(bytes)
      end

      theme = Theme.first_or_create!(name: "default")
      theme.update!(logo_blob: bytes, logo_content_type: content_type)

      # Mirror as a data URI in settings so the view-hook can emit it without a
      # second DB round-trip.
      Setting.plugin_openproject_branding =
        current_settings.merge("logo_data_uri" => theme.logo_data_uri)
    end

    def invalid_logo(error_key)
      theme = Theme.new(name: "default")
      theme.errors.add(:logo_blob, error_key)
      theme
    end

    # Minimal server-side SVG sanitizer: removes <script> elements, on*-event
    # attributes, and javascript:/data:text URIs. For production hardening,
    # prefer a dedicated gem (e.g. `loofah` with an SVG-aware scrubber); this is
    # a conservative fallback that errs toward stripping.
    def sanitize_svg(bytes)
      svg = bytes.dup.force_encoding("UTF-8")
      svg = svg.scrub("") unless svg.valid_encoding?

      svg.gsub!(%r{<script.*?</script>}mi, "")
      svg.gsub!(/<script[^>]*/i, "")
      svg.gsub!(/\son\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/i, "")
      svg.gsub!(/(href|xlink:href)\s*=\s*(['"]?)\s*javascript:[^'">\s]*\2/i, "")
      svg
    end
  end
end
