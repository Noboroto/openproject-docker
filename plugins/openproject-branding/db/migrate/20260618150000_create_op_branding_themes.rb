# frozen_string_literal: true

# OpenProject 17 runs on Rails 7.1+. Confirm with:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpBrandingThemes < ActiveRecord::Migration[7.1]
  def change
    create_table :op_branding_themes do |t|
      t.string :name, null: false, default: "default"
      t.binary :logo_blob           # raw image bytes (capped at 1 MB by the model)
      t.string :logo_content_type

      t.timestamps
    end

    add_index :op_branding_themes, :name, unique: true
  end
end
