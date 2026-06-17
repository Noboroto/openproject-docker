# frozen_string_literal: true

require "spec_helper"

RSpec.describe TimeReports::CostCalculator do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }

  # Minimal stand-in for a TimeEntry so the spec does not depend on the full
  # TimeEntry factory graph. Mirrors the attributes CostCalculator reads.
  let(:entry_struct) do
    Struct.new(:project_id, :user_id, :activity_id, :spent_on, :hours, keyword_init: true)
  end

  def entry(hours:, on: Date.current)
    entry_struct.new(project_id: project.id, user_id: user.id, activity_id: nil,
                     spent_on: on, hours: hours)
  end

  it "totals hours x effective rate" do
    TimeReports::CostRate.create!(project: project, rate: 100, currency: "USD", valid_from: Date.current - 1)
    calc = described_class.new([entry(hours: 2), entry(hours: 3)])
    expect(calc.total).to eq(500.0)
  end

  it "picks the latest valid_from <= spent_on" do
    TimeReports::CostRate.create!(project: project, rate: 50,  currency: "USD", valid_from: Date.current - 30)
    TimeReports::CostRate.create!(project: project, rate: 80,  currency: "USD", valid_from: Date.current - 5)
    TimeReports::CostRate.create!(project: project, rate: 999, currency: "USD", valid_from: Date.current + 5) # future, ignored

    calc = described_class.new([entry(hours: 1)])
    expect(calc.total).to eq(80.0)
  end

  it "prefers a user-specific rate over a project-wide one" do
    TimeReports::CostRate.create!(project: project, user: nil,  rate: 60, currency: "USD", valid_from: Date.current - 1)
    TimeReports::CostRate.create!(project: project, user: user, rate: 90, currency: "USD", valid_from: Date.current - 1)

    calc = described_class.new([entry(hours: 1)])
    expect(calc.total).to eq(90.0)
  end

  it "returns 0 cost when no rate is configured" do
    calc = described_class.new([entry(hours: 5)])
    expect(calc.total).to eq(0.0)
  end
end
