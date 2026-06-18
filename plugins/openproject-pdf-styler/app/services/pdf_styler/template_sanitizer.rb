# frozen_string_literal: true

module PdfStyler
  # Sanitizes admin-authored HTML — never eval'd as ERB/template code.
  # Strict allowlist prevents SSTI and XSS from admin-supplied HTML.
  # img src restricted to data: and https: only (SSRF mitigation).
  class TemplateSanitizer
    ALLOWED_ELEMENTS = %w[
      h1 h2 h3 h4 p span div br hr strong em b i
      ul ol li table thead tbody tr td th
    ].freeze

    ALLOWED_ATTRIBUTES = {
      "img"  => %w[src width height alt],
      "div"  => %w[class style],
      "span" => %w[class style],
      "p"    => %w[class style],
      "td"   => %w[colspan rowspan],
      "th"   => %w[colspan rowspan]
    }.freeze

    # Only data: URIs and https: URLs; block file:, http:, javascript:, etc.
    SAFE_SRC_PATTERN = /\A(https:|data:image\/)/i

    def self.call(html)
      return "" if html.blank?

      Sanitize.fragment(
        html.to_s,
        elements:   ALLOWED_ELEMENTS,
        attributes: ALLOWED_ATTRIBUTES,
        protocols:  { "img" => { "src" => %w[https data] } }
      )
    end
  end
end
