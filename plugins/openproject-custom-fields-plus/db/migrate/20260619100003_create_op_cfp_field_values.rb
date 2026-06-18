# frozen_string_literal: true

class CreateOpCfpFieldValues < ActiveRecord::Migration[7.1]
  def change
    create_table :op_cfp_field_values, if_not_exists: true do |t|
      t.references :advanced_field, null: false,
                   foreign_key: { to_table: :op_cfp_advanced_fields },
                   index: { if_not_exists: true }
      t.references :work_package, null: false,
                   foreign_key: true,
                   index: { if_not_exists: true }
      t.text :value_ids
      t.timestamps
    end

    add_index :op_cfp_field_values, %i[advanced_field_id work_package_id],
              unique: true, name: "idx_cfp_values_field_wp", if_not_exists: true
  end
end
