# frozen_string_literal: true

# Per-user queue of accumulated activity awaiting the next digest. Rows are
# marked `sent` (rather than deleted) within the send window for idempotency.
# Rails 7.1 migration (see note in 20260619097000_create_op_digest_preferences.rb).
class CreateOpDigestQueue < ActiveRecord::Migration[7.1]
  def change
    create_table :op_digest_queue, if_not_exists: true do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :work_package, null: false, foreign_key: true
      t.string   :summary,     null: false
      t.datetime :occurred_at, null: false
      t.boolean  :sent,        null: false, default: false

      t.timestamps
    end

    # Fast lookup of a user's pending items.
    add_index :op_digest_queue, %i[user_id sent], if_not_exists: true

    # Idempotency: at most one pending row per (user, work_package, occurrence).
    # Prevents duplicate captures of the same change across overlapping cron runs.
    add_index :op_digest_queue,
              %i[user_id work_package_id occurred_at],
              unique: true,
              name: "index_op_digest_queue_unique_occurrence",
              if_not_exists: true
  end
end
