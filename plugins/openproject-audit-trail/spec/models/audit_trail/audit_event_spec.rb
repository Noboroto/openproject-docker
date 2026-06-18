# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness (FactoryBot, DB). The plugin's
# migration must have run so op_audit_events exists.
RSpec.describe AuditTrail::AuditEvent, type: :model do
  subject(:event) do
    described_class.create!(event: "member.created", occurred_at: Time.current)
  end

  it "is valid with an event name and occurred_at" do
    expect(event).to be_persisted
  end

  it "requires an event name" do
    record = described_class.new(occurred_at: Time.current)
    expect(record).not_to be_valid
  end

  describe "immutability" do
    it "reports a persisted record as readonly" do
      expect(event.readonly?).to be(true)
    end

    it "raises ActiveRecord::ReadOnlyRecord on update" do
      event # create first
      expect { event.update!(event: "changed") }
        .to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "raises on single-record destroy" do
      expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe ".purge_expired!" do
    let!(:old_event) do
      described_class.create!(event: "old", occurred_at: 400.days.ago)
    end
    let!(:recent_event) do
      described_class.create!(event: "recent", occurred_at: 1.day.ago)
    end

    before do
      Setting.plugin_openproject_audit_trail = { "retention_days" => 365 }
    end

    it "deletes only events older than the retention window" do
      described_class.purge_expired!
      expect(described_class.exists?(old_event.id)).to be(false)
      expect(described_class.exists?(recent_event.id)).to be(true)
    end

    it "keeps everything when retention_days is 0" do
      Setting.plugin_openproject_audit_trail = { "retention_days" => 0 }
      expect { described_class.purge_expired! }.not_to change(described_class, :count)
    end
  end
end
