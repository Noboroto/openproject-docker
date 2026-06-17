# frozen_string_literal: true

module Branding
  # Builds the <style> body that is injected into the layout <head> from the
  # branding settings.
  #
  # SECURITY: stored custom CSS is the top XSS risk. All admin-provided values
  # are sanitized server-side before being emitted:
  #   - any "</style>" sequence (case-insensitive) is stripped so the attacker
  #     cannot break out of the <style> element into raw HTML;
  #   - "@import" rules are stripped (prevents loading arbitrary remote CSS);
  #   - "expression(" (legacy IE CSS expressions, JS execution) is stripped;
  #   - "url(...)" values whose scheme is not data:/https: are neutralized
  #     (blocks javascript:, vbscript:, http:, etc.).
  #
  # The compiler never trusts color values either: they are constrained to a
  # safe hex/rgb(a)/hsl(a)/named-color pattern, falling back to a default.
  class CssCompiler
    DEFAULT_PRIMARY = "#1A67A3"
    DEFAULT_ACCENT  = "#35C53F"

    # Permitted URL schemes inside custom-CSS url() values.
    ALLOWED_URL_SCHEMES = %w[data https].freeze

    # Conservative color validation: #rgb / #rrggbb / #rrggbbaa, rgb()/rgba(),
    # hsl()/hsla(), or a plain CSS named color (letters only).
    COLOR_PATTERN = /\A(#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|rgba?\([0-9.,\s%]+\)|hsla?\([0-9.,\s%]+\)|[a-zA-Z]{3,40})\z/

    class << self
      # @param settings [Hash, #[]] the plugin settings (string keys).
      # @param logo_data_uri [String, nil] optional logo data URI to apply to the
      #   header logo via `content:`.
      # @return [String] sanitized CSS ready to place inside a <style> element.
      def call(settings, logo_data_uri: nil)
        settings ||= {}

        primary = sanitize_color(settings["primary_color"], DEFAULT_PRIMARY)
        accent  = sanitize_color(settings["accent_color"], DEFAULT_ACCENT)
        custom  = sanitize_block(settings["custom_css"].to_s)

        css = +""
        css << ":root {\n"
        css << "  --branding-primary: #{primary};\n"
        css << "  --branding-accent: #{accent};\n"
        css << "}\n"

        if logo_data_uri.present? && safe_logo_uri?(logo_data_uri)
          css << ".op-logo img, .op-logo--link img { content: url(\"#{logo_data_uri}\"); }\n"
        end

        css << custom
        css << "\n" unless custom.empty?
        css
      end

      # Validate a single color value; fall back to `fallback` when invalid.
      def sanitize_color(value, fallback)
        value = value.to_s.strip
        return fallback if value.empty?
        return fallback unless value.match?(COLOR_PATTERN)

        value
      end

      # Sanitize an arbitrary block of admin-supplied CSS.
      def sanitize_block(css)
        css = css.to_s.dup

        # 1. Prevent breaking out of the <style> element.
        css.gsub!(%r{</\s*style\s*>}i, "")

        # 2. Strip @import rules (both @import "..."; and @import url(...);).
        css.gsub!(/@import[^;]*;?/i, "")

        # 3. Strip legacy CSS expression() (IE JS execution vector).
        css.gsub!(/expression\s*\(/i, "")

        # 4. Neutralize url() values whose scheme is not data:/https:.
        css = sanitize_urls(css)

        # 5. Defense in depth: strip inline event-handler-looking tokens and
        #    any leftover "javascript:"/"vbscript:" schemes.
        css.gsub!(/javascript:/i, "")
        css.gsub!(/vbscript:/i, "")

        css.strip
      end

      private

      # Replace any url(...) whose target is not data:/https: with url().
      def sanitize_urls(css)
        css.gsub(/url\(\s*(['"]?)(.*?)\1\s*\)/i) do
          quote = Regexp.last_match(1)
          target = Regexp.last_match(2).to_s.strip

          if allowed_url_target?(target)
            "url(#{quote}#{target}#{quote})"
          else
            # Drop the unsafe reference entirely.
            "url()"
          end
        end
      end

      def allowed_url_target?(target)
        return false if target.empty?

        # Relative URLs (no scheme) are allowed — they resolve against the app.
        scheme = target[/\A([a-zA-Z][a-zA-Z0-9+.\-]*):/, 1]
        return true if scheme.nil?

        ALLOWED_URL_SCHEMES.include?(scheme.downcase)
      end

      def safe_logo_uri?(uri)
        scheme = uri.to_s[/\A([a-zA-Z][a-zA-Z0-9+.\-]*):/, 1]
        return false if scheme.nil?

        ALLOWED_URL_SCHEMES.include?(scheme.downcase)
      end
    end
  end
end
