# frozen_string_literal: true

# OpenProject 17 runs on Rails 7.1+.
class CreateOpLdapGsSyncRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :op_ldap_gs_sync_runs do |t|
      # Nullable: a "full run" covers all mappings and has no single group.
      t.references :synchronized_group, null: true,
                   foreign_key: { to_table: :op_ldap_gs_synchronized_groups }
      t.datetime :started_at,  null: false
      t.datetime :finished_at, null: true
      t.integer  :added_count,   null: false, default: 0
      t.integer  :removed_count, null: false, default: 0
      # enum: 0=running, 1=success, 2=failed (see SyncRun model).
      t.integer  :status, null: false, default: 0
      t.text     :error_text

      t.timestamps
    end

    add_index :op_ldap_gs_sync_runs, %i[status started_at]
  end
end
