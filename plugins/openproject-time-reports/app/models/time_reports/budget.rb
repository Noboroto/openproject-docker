# frozen_string_literal: true

module TimeReports
  # A project budget. "Spent" and "remaining" are computed on demand by
  # TimeReports::BudgetSummary (hours x effective rate within the period).
  class Budget < ::ApplicationRecord
    self.table_name = "op_cost_budgets"

    belongs_to :project

    validates :name, presence: true
    validates :amount,
              presence: true,
              numericality: { greater_than_or_equal_to: 0 }
    validates :currency, presence: true

    validate :period_order

    private

    def period_order
      return if period_start.blank? || period_end.blank?
      return if period_end >= period_start

      errors.add(:period_end, :greater_than_or_equal_to_start)
    end
  end
end
