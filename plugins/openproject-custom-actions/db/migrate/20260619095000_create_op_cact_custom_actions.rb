# frozen_string_literal: true

# Rails 7.1 migration (OpenProject 17 runs on Rails 7.1+). VERIFY the exact Rails
# version against the running image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
#
# Namespaced table prefix op_cact_ keeps the schema isolated from core tables.
class CreateOpCactCustomActions < ActiveRecord::Migration[7.1]
  def change
    create_table :op_cact_custom_actions do |t|
      t.string  :name,       null: false
      t.integer :position,   null: false, default: 1
      # When the action is applicable: { "status_id":1, "type_ids":[3,4] }
      t.jsonb   :conditions, null: false, default: {}
      # What the action applies: { "status_id":7, "assigned_to_id":12, "priority_id":5 }.
      # Named change_set (not "changes") to avoid clashing with ActiveModel::Dirty.
      t.jsonb   :change_set, null: false, default: {}
      t.timestamps
    end

    add_index :op_cact_custom_actions, :position
  end
end
