# frozen_string_literal: true

# One row per user holding their digest delivery rules. OpenProject 17 runs on
# Rails 7.1+ — verify with:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpDigestPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :op_digest_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      # off / daily / weekly
      t.string  :frequency, null: false, default: "daily"
      # Muted project ids and type ids — items matching these are never queued.
      t.jsonb   :muted_project_ids, null: false, default: []
      t.jsonb   :muted_type_ids,    null: false, default: []
      # Quiet-hours window (instance-local hours 0..23). When set, items that
      # occur inside the window are suppressed. Supports wrap-around (22 -> 6).
      t.integer :quiet_from_hour
      t.integer :quiet_to_hour

      t.timestamps
    end
  end
end
