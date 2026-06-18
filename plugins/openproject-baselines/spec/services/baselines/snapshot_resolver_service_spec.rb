# frozen_string_literal: true

require "spec_helper"

RSpec.describe Baselines::SnapshotResolverService do
  let(:project)      { create(:project) }
  let(:work_package) { create(:work_package, project: project) }

  subject { described_class.new }

  describe "#attributes_at" do
    context "when no journal exists before the timestamp" do
      it "returns nil" do
        result = subject.attributes_at(work_package, 10.years.ago)
        expect(result).to be_nil
      end
    end

    context "when a journal exists" do
      before do
        # Force at least one journal by saving with an attribute change.
        work_package.update!(subject: "Updated subject")
      end

      it "returns a hash with tracked attributes" do
        result = subject.attributes_at(work_package, 1.second.from_now)
        expect(result).to be_a(Hash)
        expect(result.keys).to include("subject")
      end
    end
  end
end
