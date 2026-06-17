# frozen_string_literal: true

module Branding
  # Stores the branding logo / favicon binary. Colors and custom CSS are small
  # enough to live in OpenProject's `Setting` store (declared in the engine);
  # the logo binary is too large for a Setting, so it lives here.
  #
  # A single "default" row is used for the instance-wide theme, but the model
  # supports multiple named themes for future use.
  class Theme < ApplicationRecord
    self.table_name = "op_branding_themes"

    ALLOWED_CONTENT_TYPES = %w[
      image/png
      image/jpeg
      image/jpg
      image/webp
      image/svg+xml
    ].freeze

    # 1 MB cap on the stored logo binary.
    MAX_LOGO_BYTES = 1.megabyte

    validates :name, presence: true, uniqueness: true

    validates :logo_content_type,
              inclusion: { in: ALLOWED_CONTENT_TYPES },
              allow_nil: true

    validate :logo_within_size_limit

    # Returns the logo as a base64 data URI suitable for embedding in CSS/HTML,
    # or nil when no logo is stored.
    def logo_data_uri
      return nil if logo_blob.blank? || logo_content_type.blank?

      "data:#{logo_content_type};base64,#{Base64.strict_encode64(logo_blob)}"
    end

    private

    def logo_within_size_limit
      return if logo_blob.blank?

      if logo_blob.bytesize > MAX_LOGO_BYTES
        errors.add(:logo_blob, :too_large)
      end
    end
  end
end
