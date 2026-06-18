# frozen_string_literal: true

require "spec_helper"

RSpec.describe PublicShare::ShareLink, type: :model do
  let(:user)         { create(:user) }
  let(:work_package) { create(:work_package) }
  let(:digest)       { Digest::SHA256.hexdigest("test_token") }

  subject do
    described_class.new(
      work_package: work_package,
      creator:      user,
      token_digest: digest
    )
  end

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires creator" do
      subject.creator = nil
      expect(subject).not_to be_valid
    end

    it "requires work_package or query" do
      subject.work_package = nil
      expect(subject).not_to be_valid
    end

    it "requires unique token_digest" do
      subject.save!
      dup = described_class.new(
        work_package: work_package, creator: user,
        token_digest: digest
      )
      expect(dup).not_to be_valid
    end
  end

  describe "#active?" do
    it "is active when not revoked and not expired" do
      subject.expires_at = 1.week.from_now
      expect(subject).to be_active
    end

    it "is inactive when revoked" do
      subject.revoked_at = 1.hour.ago
      expect(subject).not_to be_active
    end

    it "is inactive when expired" do
      subject.expires_at = 1.day.ago
      expect(subject).not_to be_active
    end
  end
end
