# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness (FactoryBot factories `create(:admin)`,
# `create(:user)` and the `login_as` helper).
RSpec.describe "Audit trail viewer", type: :request do
  let(:admin) { create(:admin) }
  let(:user)  { create(:user) }

  before do
    Setting.plugin_openproject_audit_trail = { "retention_days" => 365, "capture_ip" => false }
    AuditTrail::AuditEvent.create!(event: "project.deleted", occurred_at: Time.current)
  end

  describe "GET /admin/audit_trail" do
    it "denies a non-admin user (403)" do
      login_as user
      get "/admin/audit_trail"
      expect(response).to have_http_status(:forbidden)
    end

    it "allows an admin (200)" do
      login_as admin
      get "/admin/audit_trail"
      expect(response).to have_http_status(:ok)
    end

    it "filters by event name" do
      login_as admin
      AuditTrail::AuditEvent.create!(event: "user.activated", occurred_at: Time.current)
      get "/admin/audit_trail", params: { event: "user.activated" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "CSV export" do
    it "denies a non-admin before streaming (403)" do
      login_as user
      get "/admin/audit_trail.csv"
      expect(response).to have_http_status(:forbidden)
    end

    it "streams CSV for an admin with the correct headers" do
      login_as admin
      get "/admin/audit_trail.csv"
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.body).to include("occurred_at,event")
      expect(response.body).to include("project.deleted")
    end
  end
end
