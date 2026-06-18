# frozen_string_literal: true

require "spec_helper"

RSpec.describe PublicShare::ProjectionService do
  subject { described_class.new }

  let(:work_package) { create(:work_package, subject: "Test WP", done_ratio: 50) }

  describe "#work_package" do
    let(:result) { subject.work_package(work_package) }

    it "includes allowlisted attributes" do
      expect(result).to include(:id, :subject, :status, :type, :done_ratio, :updated_at)
    end

    it "excludes description" do
      expect(result.keys).not_to include(:description)
    end

    it "excludes attachments" do
      expect(result.keys).not_to include(:attachments)
    end

    it "excludes custom_values" do
      expect(result.keys).not_to include(:custom_values)
    end

    it "returns subject correctly" do
      expect(result[:subject]).to eq("Test WP")
    end
  end
end
