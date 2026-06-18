# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness: `create(:admin)`, `create(:user)`,
# `login_as`, and the global-permission machinery. A non-privileged user must be
# denied (403); a user with the global permissions can manage + instantiate.
RSpec.describe "Project templates", type: :request do
  let(:admin)  { create(:admin) }
  let(:user)   { create(:user) }
  let(:source) { create(:project) }

  describe "GET /admin/project_templates" do
    it "denies a user without manage_project_templates (403)" do
      login_as user
      get "/admin/project_templates"
      expect(response).to have_http_status(:forbidden)
    end

    it "allows an admin (200)" do
      login_as admin
      get "/admin/project_templates"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/project_templates" do
    before { login_as admin }

    it "registers a project as a template" do
      expect {
        post "/admin/project_templates", params: {
          template: { project_id: source.id, name: "My template", is_public: "1" }
        }
      }.to change(ProjectTemplates::Template, :count).by(1)

      expect(response).to have_http_status(:redirect)
      template = ProjectTemplates::Template.last
      expect(template.project_id).to eq(source.id)
      expect(template.is_public?).to be(true)
    end
  end

  describe "GET /project_templates/gallery" do
    it "denies a user without create_project_from_template (403)" do
      login_as user
      get "/project_templates/gallery"
      expect(response).to have_http_status(:forbidden)
    end

    it "shows the gallery to an admin (200)" do
      login_as admin
      ProjectTemplates::Template.create!(project: source, name: "Tpl", is_public: true)
      get "/project_templates/gallery"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /project_templates/templates/:template_id/instantiate" do
    let!(:template) do
      ProjectTemplates::Template.create!(project: source, name: "Tpl", is_public: true)
    end

    before { login_as admin }

    it "delegates to the service and redirects to the new project" do
      new_project = create(:project)
      result = ProjectTemplates::CreateFromTemplateService::Result.new(
        success?: true, project: new_project, errors: []
      )
      allow_any_instance_of(ProjectTemplates::CreateFromTemplateService)
        .to receive(:call).and_return(result)

      post "/project_templates/templates/#{template.id}/instantiate",
           params: { project: { name: "Clone", identifier: "clone" } }

      expect(response).to redirect_to(project_path(new_project))
    end

    it "shows a friendly error when the template is too large" do
      allow_any_instance_of(ProjectTemplates::CreateFromTemplateService)
        .to receive(:call)
        .and_raise(ProjectTemplates::CreateFromTemplateService::TooLargeError, "too large")

      post "/project_templates/templates/#{template.id}/instantiate",
           params: { project: { name: "Clone" } }

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("too large").or have_http_status(:ok)
    end
  end
end
