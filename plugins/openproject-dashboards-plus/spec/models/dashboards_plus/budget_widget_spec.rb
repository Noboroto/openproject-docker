# frozen_string_literal: true

require "spec_helper"

# Exercises the budget widget presenter. Requires openproject-time_reports to be
# loaded in the same test harness (the two plugins are installed together).
RSpec.describe DashboardsPlus::BudgetWidget, type: :model do
  let(:project) { create(:project) }

  it "reports availability based on TimeReports presence" do
    expect(described_class.available?).to eq(
      defined?(::TimeReports::Budget) && defined?(::TimeReports::BudgetSummary)
    )
  end

  context "when time_reports is available", if: defined?(::TimeReports::Budget) do
    it "returns one row per budget with computed figures" do
      ::TimeReports::CostRate.create!(project: project, rate: 100, currency: "USD",
                                      valid_from: Date.current - 30)
      ::TimeReports::Budget.create!(project: project, name: "Q1", amount: 1000, currency: "USD",
                                    period_start: Date.current - 10, period_end: Date.current + 10)

      rows = described_class.new(project).rows
      expect(rows.size).to eq(1)
      expect(rows.first.name).to eq("Q1")
      expect(rows.first.amount).to eq(1000)
    end
  end
end
