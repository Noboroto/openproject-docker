# frozen_string_literal: true

require "spec_helper"

RSpec.describe LdapGroupSync::SyncRun, type: :model do
  it "defaults to running status" do
    run = described_class.create!(started_at: Time.current)
    expect(run).to be_running
  end

  describe ".track" do
    it "marks success and records counts on a clean run" do
      run = described_class.track { { added: 3, removed: 1 } }

      expect(run).to be_success
      expect(run.added_count).to eq(3)
      expect(run.removed_count).to eq(1)
      expect(run.finished_at).to be_present
    end

    it "marks failed and re-raises on error" do
      expect do
        described_class.track { raise "boom" }
      end.to raise_error("boom")

      run = described_class.last
      expect(run).to be_failed
      expect(run.error_text).to eq("boom")
      expect(run.finished_at).to be_present
    end
  end
end
