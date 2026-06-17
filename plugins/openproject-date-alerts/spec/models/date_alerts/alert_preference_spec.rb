# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness + FactoryBot factories
# (`create(:user)`), available when the plugin runs inside the OP test suite.
RSpec.describe DateAlerts::AlertPreference, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "is valid for a user with sane attributes" do
      expect(described_class.new(user_id: user.id, lead_days: 1)).to be_valid
    end

    it "enforces one preference per user (unique user_id)" do
      described_class.create!(user_id: user.id, lead_days: 1)
      dup = described_class.new(user_id: user.id, lead_days: 2)
      expect(dup).not_to be_valid
      expect(dup.errors[:user_id]).to be_present
    end

    it "rejects a negative lead time" do
      pref = described_class.new(user_id: user.id, lead_days: -1)
      expect(pref).not_to be_valid
      expect(pref.errors[:lead_days]).to be_present
    end
  end

  describe ".for" do
    it "returns the persisted preference when one exists" do
      pref = described_class.create!(user_id: user.id, lead_days: 5, due_date_enabled: false)
      found = described_class.for(user)
      expect(found).to eq(pref)
      expect(found.due_date_enabled).to be(false)
    end

    it "returns an unsaved default when the user has none" do
      default = described_class.for(user)
      expect(default).to be_a(described_class)
      expect(default).to be_new_record
      expect(default.due_date_enabled).to be(true)
      expect(default.start_date_enabled).to be(true)
    end

    it "returns a default for nil (no user)" do
      default = described_class.for(nil)
      expect(default).to be_a(described_class)
      expect(default).to be_new_record
    end

    it "seeds the default lead time from the instance settings" do
      Setting.plugin_openproject_date_alerts = { "default_lead_days" => 7 }
      expect(described_class.for(user).lead_days).to eq(7)
    end
  end
end
