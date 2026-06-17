# frozen_string_literal: true

require "spec_helper"

RSpec.describe MfaEnforcement::Policy do
  def policy(overrides = {})
    described_class.new({ "enforced" => true, "grace_period_days" => 7 }.merge(overrides))
  end

  describe "#enforced?" do
    it "is true when the setting is on" do
      expect(policy("enforced" => true).enforced?).to be(true)
    end

    it "casts truthy strings" do
      expect(policy("enforced" => "1").enforced?).to be(true)
    end

    it "is false when off" do
      expect(policy("enforced" => false).enforced?).to be(false)
    end

    it "is false when the ENV kill switch is set, regardless of setting" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with(described_class::KILL_SWITCH_ENV).and_return("true")
      expect(policy("enforced" => true).enforced?).to be(false)
    end
  end

  describe "#grace_period_days" do
    it "returns the configured value" do
      expect(policy("grace_period_days" => 14).grace_period_days).to eq(14)
    end

    it "falls back to the default when blank" do
      expect(policy("grace_period_days" => "").grace_period_days)
        .to eq(described_class::DEFAULT_GRACE_DAYS)
    end
  end

  describe "#enforced_group_id" do
    it "returns nil (all users) when blank" do
      expect(policy("enforced_group_id" => "").enforced_group_id).to be_nil
    end

    it "returns the integer id when set" do
      expect(policy("enforced_group_id" => "42").enforced_group_id).to eq(42)
    end
  end

  describe "#policy_start_at" do
    it "parses an ISO8601 string" do
      t = Time.utc(2026, 6, 18, 12, 0, 0)
      expect(policy("policy_start_at" => t.iso8601).policy_start_at).to be_within(1.second).of(t)
    end

    it "returns nil for a blank/invalid value" do
      expect(policy("policy_start_at" => "").policy_start_at).to be_nil
      expect(policy("policy_start_at" => "not-a-date").policy_start_at).to be_nil
    end
  end

  describe "#applies_to?" do
    let(:user) { double("User") }

    it "applies to everyone when no group is set" do
      expect(policy("enforced_group_id" => nil).applies_to?(user)).to be(true)
    end

    it "applies to a member of the target group" do
      groups = double("groups")
      allow(groups).to receive(:exists?).with(id: 5).and_return(true)
      allow(user).to receive(:groups).and_return(groups)
      expect(policy("enforced_group_id" => 5).applies_to?(user)).to be(true)
    end

    it "does not apply to a non-member of the target group" do
      groups = double("groups")
      allow(groups).to receive(:exists?).with(id: 5).and_return(false)
      allow(user).to receive(:groups).and_return(groups)
      expect(policy("enforced_group_id" => 5).applies_to?(user)).to be(false)
    end
  end
end
