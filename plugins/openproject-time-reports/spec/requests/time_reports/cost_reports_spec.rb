# frozen_string_literal: true

require "spec_helper"

# Request specs depend on OP's core helpers / factories and on the project
# module + permissions being registered. `view_cost_reports` is distinct from
# `view_time_reports`, so a user holding only the latter must be forbidden.
RSpec.describe "Cost reports", type: :request do
  let(:project) { create(:project, enabled_module_names: %w[time_reports]) }

  let(:cost_role) { create(:project_role, permissions: %i[view_cost_reports]) }
  let(:time_role) { create(:project_role, permissions: %i[view_time_reports]) }

  let(:cost_user) { create(:user, member_with_roles: { project => cost_role }) }
  let(:time_user) { create(:user, member_with_roles: { project => time_role }) }

  describe "GET index" do
    it "allows a user with view_cost_reports" do
      login_as cost_user
      get "/projects/#{project.identifier}/time_reports/cost_reports"
      expect(response).to have_http_status(:ok)
    end

    it "forbids a user who only has view_time_reports" do
      login_as time_user
      get "/projects/#{project.identifier}/time_reports/cost_reports"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET export" do
    it "streams CSV only after authorize passes" do
      login_as cost_user
      get "/projects/#{project.identifier}/time_reports/cost_reports/export"
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "forbids CSV export without view_cost_reports" do
      login_as time_user
      get "/projects/#{project.identifier}/time_reports/cost_reports/export"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
