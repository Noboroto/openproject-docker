# frozen_string_literal: true

module DashboardsPlus
  # Plain presenter for the budget dashboard widget. Pulls project budgets from
  # the openproject-time_reports plugin and computes spent / remaining / percent
  # via TimeReports::BudgetSummary.
  #
  # The dependency on openproject-time_reports is SOFT: when that plugin is not
  # installed, `available?` is false and the widget view renders a hint instead
  # of raising.
  class BudgetWidget
    Row = Struct.new(:name, :amount, :spent, :remaining, :percent_used, :over_budget, :currency,
                     keyword_init: true)

    def initialize(project)
      @project = project
    end

    def self.available?
      defined?(::TimeReports::Budget) && defined?(::TimeReports::BudgetSummary)
    end

    def available?
      self.class.available?
    end

    def rows
      return [] unless available?

      ::TimeReports::Budget.where(project: @project).order(:name).map do |budget|
        summary = ::TimeReports::BudgetSummary.new(budget)
        Row.new(
          name:         budget.name,
          amount:       budget.amount,
          spent:        summary.spent,
          remaining:    summary.remaining,
          percent_used: summary.percent_used,
          over_budget:  summary.over_budget?,
          currency:     budget.currency
        )
      end
    end
  end
end
