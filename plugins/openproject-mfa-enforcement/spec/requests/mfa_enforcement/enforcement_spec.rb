# frozen_string_literal: true

require "spec_helper"

# These request specs rely on OpenProject's core spec helpers / FactoryBot
# factories (`create(:admin)`, `create(:user)`, `login_as`) available when the
# plugin runs inside the OpenProject test harness.
#
# VERIFY against running 17-slim image: factory names and the gated paths used
# below ("/my/account") still exist and require login.
RSpec.describe "MFA enforcement gate", type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:admin) }

  def enable_policy(grace_days:, start_at:, group_id: nil)
    Setting.plugin_openproject_mfa_enforcement = {
      "enforced"          => true,
      "grace_period_days" => grace_days,
      "enforced_group_id" => group_id,
      "policy_start_at"   => start_at&.iso8601
    }
  end

  describe "admin settings page" do
    it "denies a non-admin (403)" do
      login_as user
      get "/admin/two_factor_enforcement"
      expect(response).to have_http_status(:forbidden)
    end

    it "allows an admin (200) and is never gated even when non-compliant" do
      enable_policy(grace_days: 0, start_at: 30.days.ago)
      login_as admin
      get "/admin/two_factor_enforcement"
      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to(mfa_enforcement_blocked_path)
    end

    it "stamps policy_start_at when enabling" do
      login_as admin
      patch "/admin/two_factor_enforcement", params: {
        settings: { enforced: "1", grace_period_days: "7", enforced_group_id: "" }
      }
      settings = Setting.plugin_openproject_mfa_enforcement
      expect(settings["enforced"]).to be_truthy
      expect(settings["policy_start_at"]).to be_present
    end
  end

  describe "the gate on browser navigation" do
    it "redirects a non-compliant user to the blocked page after grace" do
      enable_policy(grace_days: 0, start_at: 30.days.ago)
      login_as user
      get "/my/account"
      expect(response).to redirect_to(mfa_enforcement_blocked_path)
    end

    it "does NOT redirect while still within the grace window" do
      enable_policy(grace_days: 30, start_at: 1.day.ago)
      login_as user
      get "/my/account"
      expect(response).not_to redirect_to(mfa_enforcement_blocked_path)
    end

    it "does NOT redirect when enforcement is off" do
      Setting.plugin_openproject_mfa_enforcement = { "enforced" => false }
      login_as user
      get "/my/account"
      expect(response).not_to redirect_to(mfa_enforcement_blocked_path)
    end

    it "never gates the 2FA setup / login paths (no redirect loop)" do
      enable_policy(grace_days: 0, start_at: 30.days.ago)
      login_as user

      # The blocked page itself is reachable (allowlisted) — no loop.
      get mfa_enforcement_blocked_path
      expect(response).to have_http_status(:ok)
    end

    it "exempts a non-member when the policy targets a specific group" do
      group = create(:group)
      enable_policy(grace_days: 0, start_at: 30.days.ago, group_id: group.id)
      login_as user # not a member of `group`
      get "/my/account"
      expect(response).not_to redirect_to(mfa_enforcement_blocked_path)
    end
  end
end
