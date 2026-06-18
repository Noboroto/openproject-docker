# frozen_string_literal: true

# Rails 7.1 migration. Namespaced table; FK targets the plugin's own
# op_boards_boards table.
class CreateOpBoardsColumns < ActiveRecord::Migration[7.1]
  def change
    create_table :op_boards_columns, if_not_exists: true do |t|
      t.references :board, null: false,
                           foreign_key: { to_table: :op_boards_boards }
      t.string  :title,    null: false
      t.bigint  :value_id, null: false # status_id / user_id / version_id
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :op_boards_columns, %i[board_id position], if_not_exists: true
  end
end
