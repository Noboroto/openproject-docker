# frozen_string_literal: true

module TimeReports
  # Hourly cost rate, optionally scoped to a user and/or an activity, with
  # effective-date versioning. The applicable rate for a time entry is the rate
  # with the latest `valid_from <= entry.spent_on`, preferring a user-specific
  # rate over a project-wide (user_id IS NULL) one. See CostCalculator.
  class CostRate < ::ApplicationRecord
    self.table_name = "op_cost_rates"

    belongs_to :project
    belongs_to :user, optional: true
    # Activity is a TimeEntryActivity stored in the core `enumerations` table.
    # verify against running 17-slim image: class name "TimeEntryActivity".
    belongs_to :activity,
               optional: true,
               class_name: "TimeEntryActivity",
               foreign_key: :activity_id

    validates :rate,
              presence: true,
              numericality: { greater_than_or_equal_to: 0 }
    validates :currency, presence: true
    validates :valid_from, presence: true

    scope :effective_on, ->(date) { where(arel_table[:valid_from].lteq(date)) }
    scope :for_user, ->(user_id) { where(user_id: user_id) }
    scope :project_wide, -> { where(user_id: nil) }
  end
end
