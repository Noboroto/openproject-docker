# frozen_string_literal: true

require "spec_helper"

RSpec.describe MfaEnforcement::EnforcementChecker do
  # Build a user double whose CE 2FA association reports has/lacks an active
  # device, and that looks logged-in.
  def build_user(has_2fa:, created_at: 30.days.ago)
    user     = double("User", logged?: true, created_at: created_at)
    active   = double("active_scope", exists?: has_2fa)
    devices  = double("otp_devices", get_active: active)
    allow(user).to receive(:respond_to?).and_call_original
    allow(user).to receive(:respond_to?).with(:otp_devices).and_return(true)
    allow(user).to receive(:otp_devices).and_return(devices)
    user
  end

  def build_policy(enforced:, applies: true, grace_days: 7, start_at: nil)
    instance_double(
      MfaEnforcement::Policy,
      enforced?: enforced,
      grace_period_days: grace_days,
      policy_start_at: start_at
    ).tap { |p| allow(p).to receive(:applies_to?).and_return(applies) }
  end

  describe "#must_set_up? truth table" do
    it "is false when enforcement is off" do
      checker = described_class.new(build_user(has_2fa: false), build_policy(enforced: false))
      expect(checker.must_set_up?).to be(false)
    end

    it "is false when the policy does not apply to the user" do
      checker = described_class.new(build_user(has_2fa: false),
                                    build_policy(enforced: true, applies: false))
      expect(checker.must_set_up?).to be(false)
    end

    it "is false when the user already has an active 2FA device" do
      checker = described_class.new(build_user(has_2fa: true), build_policy(enforced: true))
      expect(checker.must_set_up?).to be(false)
    end

    it "is false during the grace period" do
      policy  = build_policy(enforced: true, grace_days: 7, start_at: 1.day.ago)
      checker = described_class.new(build_user(has_2fa: false), policy)
      expect(checker.must_set_up?).to be(false)
    end

    it "is true after the grace period for a non-compliant, in-scope user" do
      policy  = build_policy(enforced: true, grace_days: 7, start_at: 30.days.ago)
      checker = described_class.new(build_user(has_2fa: false), policy)
      expect(checker.must_set_up?).to be(true)
    end

    it "uses created_at when policy_start_at is nil" do
      policy  = build_policy(enforced: true, grace_days: 7, start_at: nil)
      user    = build_user(has_2fa: false, created_at: 30.days.ago)
      expect(described_class.new(user, policy).must_set_up?).to be(true)
    end
  end

  describe "#in_grace?" do
    it "is true for a non-compliant user still within grace" do
      policy  = build_policy(enforced: true, grace_days: 7, start_at: 1.day.ago)
      checker = described_class.new(build_user(has_2fa: false), policy)
      expect(checker.in_grace?).to be(true)
    end

    it "is false once grace has expired" do
      policy  = build_policy(enforced: true, grace_days: 7, start_at: 30.days.ago)
      checker = described_class.new(build_user(has_2fa: false), policy)
      expect(checker.in_grace?).to be(false)
    end
  end

  describe "fail-safe behavior" do
    it "treats a user as compliant if the CE 2FA API raises (never lock out)" do
      user = double("User", logged?: true, created_at: 30.days.ago)
      allow(user).to receive(:respond_to?).and_call_original
      allow(user).to receive(:respond_to?).with(:otp_devices).and_return(true)
      allow(user).to receive(:otp_devices).and_raise(StandardError, "API changed")

      policy  = build_policy(enforced: true, grace_days: 0, start_at: 30.days.ago)
      checker = described_class.new(user, policy)
      expect(checker.must_set_up?).to be(false)
    end
  end
end
