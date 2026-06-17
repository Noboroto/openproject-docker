# frozen_string_literal: true

# OpenProject 17 runs on Rails 7.1+. Confirm with:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpDatesAlertPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :op_dates_alert_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :start_date_enabled, null: false, default: true
      t.boolean :due_date_enabled,   null: false, default: true
      t.integer :lead_days,          null: false, default: 1
      t.boolean :email,              null: false, default: false

      t.timestamps
    end
  end
end
