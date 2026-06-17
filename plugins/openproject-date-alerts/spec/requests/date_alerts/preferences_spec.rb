# frozen_string_literal: true

require "spec_helper"

# Relies on the OP request-spec harness (`login_as`, core factories).
RSpec.describe "Date alert preferences", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  describe "GET /my/date_alerts" do
    it "requires authentication" do
      get "/my/date_alerts"
      expect(response).not_to have_http_status(:ok)
    end

    it "renders for a logged-in user" do
      login_as user
      get "/my/date_alerts"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /my/date_alerts" do
    before { login_as user }

    it "creates/updates only the current user's preference" do
      patch "/my/date_alerts", params: {
        alert_preference: {
          start_date_enabled: "0",
          due_date_enabled: "1",
          lead_days: "3",
          email: "1"
        }
      }

      expect(response).to have_http_status(:redirect)
      pref = DateAlerts::AlertPreference.find_by(user_id: user.id)
      expect(pref.lead_days).to eq(3)
      expect(pref.due_date_enabled).to be(true)
      expect(pref.start_date_enabled).to be(false)
      expect(pref.email).to be(true)
    end

    it "cannot affect another user's preference (keyed by current_user only)" do
      other_pref = DateAlerts::AlertPreference.create!(user_id: other.id, lead_days: 9)

      patch "/my/date_alerts", params: {
        alert_preference: { lead_days: "1" }
      }

      expect(other_pref.reload.lead_days).to eq(9)
      expect(DateAlerts::AlertPreference.find_by(user_id: user.id).lead_days).to eq(1)
    end
  end
end
