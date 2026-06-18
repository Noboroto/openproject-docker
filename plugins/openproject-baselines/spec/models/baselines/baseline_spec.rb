# frozen_string_literal: true

require "spec_helper"

RSpec.describe Baselines::Baseline, type: :model do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }

  describe "validations" do
    it "is valid with required attributes" do
      baseline = described_class.new(
        name: "Sprint 1",
        captured_at: 1.week.ago,
        project: project,
        author: user
      )
      expect(baseline).to be_valid
    end

    it "requires name" do
      baseline = described_class.new(captured_at: 1.week.ago, project: project, author: user)
      expect(baseline).not_to be_valid
    end

    it "requires captured_at" do
      baseline = described_class.new(name: "Sprint 1", project: project, author: user)
      expect(baseline).not_to be_valid
    end
  end
end
