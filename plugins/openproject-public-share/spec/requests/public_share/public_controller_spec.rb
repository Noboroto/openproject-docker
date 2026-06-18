# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PublicShare::PublicController", type: :request do
  let(:user)         { create(:user) }
  let(:work_package) { create(:work_package) }
  let(:service)      { PublicShare::TokenService.new }

  before do
    allow(OpenProject::PublicShare).to receive(:feature_enabled?).and_return(true)
    allow(OpenProject::PublicShare).to receive(:kill_switch_active?).and_return(false)
  end

  describe "GET /share/:token" do
    context "with a valid active token" do
      let(:raw) do
        r, d = service.generate
        PublicShare::ShareLink.create!(
          work_package: work_package, creator: user,
          token_digest: d, expires_at: 1.week.from_now
        )
        r
      end

      it "returns 200" do
        get public_share_show_path(token: raw)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an expired token" do
      it "returns 404" do
        _, d = service.generate
        PublicShare::ShareLink.create!(
          work_package: work_package, creator: user,
          token_digest: d, expires_at: 1.day.ago
        )
        get public_share_show_path(token: "any_raw_token")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a garbage token" do
      it "returns 404" do
        get public_share_show_path(token: "garbage")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with feature disabled" do
      before { allow(OpenProject::PublicShare).to receive(:feature_enabled?).and_return(false) }

      it "returns 404" do
        get public_share_show_path(token: "any")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
