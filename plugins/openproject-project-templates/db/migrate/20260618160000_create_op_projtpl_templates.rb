# frozen_string_literal: true

# OpenProject 17 runs on Rails 7.1+. Confirm with:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpProjtplTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :op_projtpl_templates, if_not_exists: true do |t|
      # The source project this template clones from. Deleting the project
      # removes the template registration (it is meaningless without a source).
      t.references :project,
                   null: false,
                   foreign_key: { to_table: :projects, on_delete: :cascade },
                   index: { unique: true }

      t.string  :name,        null: false
      t.text    :description
      # When true, the template is offered in the self-service gallery to anyone
      # with create_project_from_template. When false it is admin-only.
      t.boolean :is_public,   null: false, default: false

      t.timestamps
    end

    add_index :op_projtpl_templates, :name, unique: true, if_not_exists: true
  end
end
