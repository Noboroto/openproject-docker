# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness / FactoryBot factories
# (`create(:project)`, `create(:user)`). Run inside the OP test harness.
RSpec.describe TimeReports::CostRate, type: :model do
  let(:project) { create(:project) }

  it "requires a rate, currency and valid_from" do
    rate = described_class.new(project: project)
    expect(rate).not_to be_valid
    expect(rate.errors.attribute_names).to include(:rate, :currency, :valid_from)
  end

  it "rejects a negative rate" do
    rate = described_class.new(project: project, rate: -1, currency: "USD", valid_from: Date.current)
    expect(rate).not_to be_valid
  end

  it "is valid with a project-wide (no user) rate" do
    rate = described_class.new(project: project, rate: 50, currency: "USD", valid_from: Date.current)
    expect(rate).to be_valid
  end

  describe "scopes" do
    it "effective_on returns only rates whose valid_from <= date" do
      old = described_class.create!(project: project, rate: 10, currency: "USD", valid_from: Date.current - 10)
      future = described_class.create!(project: project, rate: 20, currency: "USD", valid_from: Date.current + 10)

      result = described_class.effective_on(Date.current)
      expect(result).to include(old)
      expect(result).not_to include(future)
    end
  end
end
