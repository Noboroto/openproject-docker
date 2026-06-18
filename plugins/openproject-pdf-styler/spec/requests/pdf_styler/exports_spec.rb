# frozen_string_literal: true

require "spec_helper"

RSpec.describe "PdfStyler::ExportsController", type: :request do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }
  let(:role)    { create(:role, permissions: [:export_styled_pdf]) }
  let(:template) do
    create(:pdf_export_template, name: "Test", active: true)
  end

  before do
    allow(OpenProject::PdfStyler).to receive(:feature_enabled?).and_return(true)
    project.update!(enabled_module_names: project.enabled_module_names + ["pdf_styler"])
    template
  end

  describe "POST /projects/:id/pdf_styler/exports" do
    context "with permission" do
      before do
        create(:member, user: user, project: project, roles: [role])
        login_as user
      end

      it "returns a PDF" do
        post pdf_styler_project_exports_path(project)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/pdf")
        expect(response.body[0, 4]).to eq("%PDF")
      end
    end

    context "without permission" do
      before { login_as user }

      it "returns 403" do
        post pdf_styler_project_exports_path(project)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with feature disabled" do
      before do
        allow(OpenProject::PdfStyler).to receive(:feature_enabled?).and_return(false)
        create(:member, user: user, project: project, roles: [role])
        login_as user
      end

      it "returns 404" do
        post pdf_styler_project_exports_path(project)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
