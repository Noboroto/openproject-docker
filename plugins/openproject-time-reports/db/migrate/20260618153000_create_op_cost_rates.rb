# frozen_string_literal: true

# Rails 7.1 — OpenProject 17 runs on Rails 7.1+.
# verify against running 17-slim image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpCostRates < ActiveRecord::Migration[7.1]
  def change
    create_table :op_cost_rates do |t|
      # Nullable user → a NULL user_id means a project-wide (any user) rate.
      t.references :user, foreign_key: true, null: true

      # Activity is a TimeEntryActivity, stored in the core `enumerations` STI
      # table. Nullable → a NULL activity_id means the rate applies to any
      # activity. verify against running 17-slim image: confirm TimeEntryActivity
      # rows live in `enumerations` (STI type = "TimeEntryActivity").
      t.references :activity, foreign_key: { to_table: :enumerations }, null: true

      t.references :project, foreign_key: true, null: false

      # Money: decimal, never float.
      t.decimal :rate, precision: 12, scale: 2, null: false
      t.string  :currency, null: false, default: "USD"

      # Effective-date versioning: the applicable rate for a time entry is the
      # one with the latest valid_from <= entry.spent_on.
      t.date    :valid_from, null: false

      t.timestamps
    end

    # Supports the effective-rate selection query (project + user + valid_from).
    add_index :op_cost_rates, %i[project_id user_id valid_from]
  end
end
