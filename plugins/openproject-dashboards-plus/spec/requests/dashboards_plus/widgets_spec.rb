# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Dashboards Plus widgets", type: :request do
  let(:project) { create(:project, enabled_module_names: %w[dashboards_plus]) }
  let(:role)    { create(:project_role, permissions: %i[view_dashboards_plus_widgets]) }
  let(:user)    { create(:user, member_with_roles: { project => role }) }
  let(:other)   { create(:user) }

  it "renders for a permitted member" do
    login_as user
    get "/projects/#{project.identifier}/dashboards_plus"
    expect(response).to have_http_status(:ok)
  end

  it "forbids a user without the permission" do
    login_as other
    get "/projects/#{project.identifier}/dashboards_plus"
    expect(response).to have_http_status(:forbidden)
  end
end
