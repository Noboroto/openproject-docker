# frozen_string_literal: true

module PdfStyler
  class ExportTemplate < ApplicationRecord
    self.table_name = "op_pdf_styler_templates"

    validates :name, presence: true, length: { maximum: 255 }

    scope :active, -> { where(active: true).order(:name) }

    ALLOWED_FONT_FAMILIES = %w[Helvetica Times Courier].freeze
    ACCENT_COLOR_PATTERN  = /\A#[0-9a-fA-F]{6}\z/

    validates :font_family, inclusion: { in: ALLOWED_FONT_FAMILIES }
    validates :accent_color, format: { with: ACCENT_COLOR_PATTERN }
  end
end
