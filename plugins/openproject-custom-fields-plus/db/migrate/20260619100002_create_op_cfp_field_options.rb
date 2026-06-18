# frozen_string_literal: true

class CreateOpCfpFieldOptions < ActiveRecord::Migration[7.1]
  def change
    create_table :op_cfp_field_options, if_not_exists: true do |t|
      t.references :advanced_field, null: false,
                   foreign_key: { to_table: :op_cfp_advanced_fields },
                   index: { if_not_exists: true }
      t.references :parent, foreign_key: { to_table: :op_cfp_field_options },
                   index: { if_not_exists: true }
      t.string  :label,    null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
  end
end
