# frozen_string_literal: true

class CreateOpBaselines < ActiveRecord::Migration[7.1]
  def change
    create_table :op_baselines, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: true,
                   index: { if_not_exists: true }
      t.references :author,  null: false, foreign_key: { to_table: :users },
                   index: { if_not_exists: true }
      t.string   :name,            null: false
      t.datetime :captured_at,     null: false
      t.jsonb    :filter_snapshot, default: {}
      t.timestamps
    end
  end
end
