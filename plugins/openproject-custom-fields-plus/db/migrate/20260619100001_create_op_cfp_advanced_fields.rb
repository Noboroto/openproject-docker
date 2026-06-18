# frozen_string_literal: true

class CreateOpCfpAdvancedFields < ActiveRecord::Migration[7.1]
  def change
    create_table :op_cfp_advanced_fields, if_not_exists: true do |t|
      t.string  :name,       null: false
      t.integer :field_type, null: false, default: 0
      t.text    :scope_project_ids
      t.text    :scope_group_ids
      t.timestamps
    end

    add_index :op_cfp_advanced_fields, :name, unique: true, if_not_exists: true
  end
end
