# frozen_string_literal: true

class CreateOpPdfStylerTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :op_pdf_styler_templates, if_not_exists: true do |t|
      t.string  :name,         null: false
      t.text    :header_html
      t.text    :footer_html
      t.text    :cover_html
      t.string  :font_family,  default: "Helvetica"
      t.string  :accent_color, default: "#1A67A3"
      t.boolean :active,       default: true, null: false
      t.timestamps
    end

    add_index :op_pdf_styler_templates, :name, unique: true, if_not_exists: true
  end
end
