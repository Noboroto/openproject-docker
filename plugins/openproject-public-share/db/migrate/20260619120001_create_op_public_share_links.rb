# frozen_string_literal: true

class CreateOpPublicShareLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :op_public_share_links, if_not_exists: true do |t|
      t.references :work_package, foreign_key: true,
                   index: { if_not_exists: true }
      t.references :query, foreign_key: true,
                   index: { if_not_exists: true }
      t.references :creator, null: false,
                   foreign_key: { to_table: :users },
                   index: { if_not_exists: true }
      t.string   :token_digest, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.integer  :access_count, default: 0, null: false
      t.timestamps
    end

    add_index :op_public_share_links, :token_digest,
              unique: true, if_not_exists: true
  end
end
