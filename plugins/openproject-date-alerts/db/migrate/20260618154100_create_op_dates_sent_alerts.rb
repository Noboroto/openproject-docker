# frozen_string_literal: true

# Idempotency ledger: one row per (user, alert key, day) that has already been
# notified, so repeated scans on the same day never double-send the same alert.
# Rails 7.1 migration (see note in 20260618154000_create_op_dates_alert_preferences.rb).
class CreateOpDatesSentAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :op_dates_sent_alerts do |t|
      t.references :user, null: false, foreign_key: true
      # e.g. "date_alert:due:1234" — identifies the work package + alert kind.
      t.string :alert_key, null: false
      t.date   :sent_on,   null: false

      t.timestamps
    end

    # The DB-level uniqueness is the real idempotency guarantee: even under
    # concurrent scans, only one (user, alert_key, day) row can exist.
    add_index :op_dates_sent_alerts,
              %i[user_id alert_key sent_on],
              unique: true,
              name: "index_op_dates_sent_alerts_unique"
  end
end
