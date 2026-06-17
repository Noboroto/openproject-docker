# frozen_string_literal: true

require "spec_helper"

RSpec.describe TimeReports::BudgetSummary do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }

  before do
    TimeReports::CostRate.create!(project: project, rate: 100, currency: "USD",
                                  valid_from: Date.current - 30)
  end

  def budget(amount:)
    TimeReports::Budget.create!(project: project, name: "B", amount: amount, currency: "USD",
                               period_start: Date.current - 10, period_end: Date.current + 10)
  end

  # Creates a real TimeEntry within the budget period. Uses the core factory.
  def log_hours(hours)
    create(:time_entry, project: project, user: user, hours: hours, spent_on: Date.current)
  end

  it "computes spent, remaining and percent_used" do
    log_hours(2) # 2h * 100 = 200
    summary = described_class.new(budget(amount: 1000))

    expect(summary.spent).to eq(200)
    expect(summary.remaining).to eq(800)
    expect(summary.percent_used).to eq(20.0)
    expect(summary.over_budget?).to be(false)
  end

  it "flags over-budget with negative remaining" do
    log_hours(20) # 20h * 100 = 2000
    summary = described_class.new(budget(amount: 1000))

    expect(summary.remaining).to be_negative
    expect(summary.over_budget?).to be(true)
    expect(summary.percent_used).to eq(200.0)
  end

  it "returns 0 percent for a zero-amount budget" do
    summary = described_class.new(budget(amount: 0))
    expect(summary.percent_used).to eq(0.0)
  end
end
