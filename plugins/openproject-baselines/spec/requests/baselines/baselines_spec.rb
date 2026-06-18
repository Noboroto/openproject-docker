# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Baselines::BaselinesController", type: :request do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }
  let(:manager_role) do
    create(:role, permissions: %i[view_baselines manage_baselines])
  end

  before do
    allow(OpenProject::Baselines).to receive(:feature_enabled?).and_return(true)
    project.update!(enabled_module_names: project.enabled_module_names + ["baselines"])
  end

  describe "GET /projects/:id/baselines" do
    context "with view_baselines permission" do
      before do
        create(:member, user: user, project: project, roles: [manager_role])
        login_as user
      end

      it "returns 200" do
        get project_baselines_path(project)
        expect(response).to have_http_status(:ok)
      end
    end

    context "without permission" do
      before { login_as user }

      it "returns 403" do
        get project_baselines_path(project)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with feature disabled" do
      before do
        allow(OpenProject::Baselines).to receive(:feature_enabled?).and_return(false)
        create(:member, user: user, project: project, roles: [manager_role])
        login_as user
      end

      it "returns 404" do
        get project_baselines_path(project)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
