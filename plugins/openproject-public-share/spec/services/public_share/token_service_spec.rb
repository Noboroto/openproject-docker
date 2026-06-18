# frozen_string_literal: true

require "spec_helper"

RSpec.describe PublicShare::TokenService do
  subject { described_class.new }

  describe "#generate" do
    it "returns a 2-element array [raw, digest]" do
      raw, digest = subject.generate
      expect(raw).to be_a(String)
      expect(raw.length).to be >= 32
      expect(digest).to eq(Digest::SHA256.hexdigest(raw))
    end

    it "generates unique tokens" do
      r1, _ = subject.generate
      r2, _ = subject.generate
      expect(r1).not_to eq(r2)
    end
  end

  describe "#find_active" do
    let(:user)         { create(:user) }
    let(:work_package) { create(:work_package) }

    before do
      allow(OpenProject::PublicShare).to receive(:feature_enabled?).and_return(true)
      allow(OpenProject::PublicShare).to receive(:kill_switch_active?).and_return(false)
    end

    it "returns nil for garbage token" do
      expect(subject.find_active("garbage")).to be_nil
    end

    it "returns nil when kill switch is active" do
      allow(OpenProject::PublicShare).to receive(:kill_switch_active?).and_return(true)
      raw, digest = subject.generate
      PublicShare::ShareLink.create!(work_package: work_package, creator: user, token_digest: digest)
      expect(subject.find_active(raw)).to be_nil
    end

    it "returns link for valid active token" do
      raw, digest = subject.generate
      link = PublicShare::ShareLink.create!(
        work_package: work_package, creator: user, token_digest: digest,
        expires_at: 1.week.from_now
      )
      expect(subject.find_active(raw)).to eq(link)
    end

    it "returns nil for expired token" do
      raw, digest = subject.generate
      PublicShare::ShareLink.create!(
        work_package: work_package, creator: user, token_digest: digest,
        expires_at: 1.day.ago
      )
      expect(subject.find_active(raw)).to be_nil
    end

    it "returns nil for revoked token" do
      raw, digest = subject.generate
      PublicShare::ShareLink.create!(
        work_package: work_package, creator: user, token_digest: digest,
        revoked_at: 1.hour.ago
      )
      expect(subject.find_active(raw)).to be_nil
    end
  end
end
