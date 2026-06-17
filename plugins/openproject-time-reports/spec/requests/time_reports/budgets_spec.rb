# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Budgets", type: :request do
  let(:project) { create(:project, enabled_module_names: %w[time_reports]) }

  let(:manage_role) { create(:project_role, permissions: %i[manage_budgets]) }
  let(:view_role)   { create(:project_role, permissions: %i[view_time_reports]) }

  let(:manager) { create(:user, member_with_roles: { project => manage_role }) }
  let(:viewer)  { create(:user, member_with_roles: { project => view_role }) }

  describe "GET index" do
    it "allows manage_budgets" do
      login_as manager
      get "/projects/#{project.identifier}/time_reports/budgets"
      expect(response).to have_http_status(:ok)
    end

    it "forbids without manage_budgets" do
      login_as viewer
      get "/projects/#{project.identifier}/time_reports/budgets"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST create" do
    it "creates a budget for a manager" do
      login_as manager
      expect do
        post "/projects/#{project.identifier}/time_reports/budgets",
             params: { budget: { name: "Q1", amount: "1000.00", currency: "USD" } }
      end.to change(TimeReports::Budget, :count).by(1)
      expect(response).to have_http_status(:redirect)
    end
  end
end
