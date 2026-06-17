# frozen_string_literal: true

module TimeReports
  # Computes spent / remaining / percent-used for a Budget by costing the time
  # entries that fall within the budget's project and (optional) period using
  # CostCalculator.
  class BudgetSummary
    def initialize(budget)
      @budget = budget
    end

    def amount
      @budget.amount.to_d
    end

    def spent
      @spent ||= CostCalculator.new(entries, currency: @budget.currency).total.to_d
    end

    def remaining
      amount - spent
    end

    # Negative remaining => over budget.
    def over_budget?
      remaining.negative?
    end

    def percent_used
      return 0.0 if amount.zero?

      (spent / amount * 100).round(1).to_f
    end

    private

    def entries
      scope = ::TimeEntry.where(project_id: @budget.project_id)
                         .includes(:user, :activity)
      if @budget.period_start && @budget.period_end
        scope = scope.where(spent_on: @budget.period_start..@budget.period_end)
      end
      scope
    end
  end
end
