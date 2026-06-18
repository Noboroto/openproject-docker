# frozen_string_literal: true

require "spec_helper"

RSpec.describe "CustomFieldsPlus::Admin::FieldsController", type: :request do
  let(:admin) { create(:admin) }
  let(:user)  { create(:user) }

  before { allow(OpenProject::CustomFieldsPlus).to receive(:feature_enabled?).and_return(true) }

  describe "GET /admin/custom_fields_plus/fields" do
    context "as admin" do
      before { login_as admin }

      it "returns 200" do
        get custom_fields_plus_admin_fields_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as non-admin" do
      before { login_as user }

      it "returns 403" do
        get custom_fields_plus_admin_fields_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with feature disabled" do
      before do
        allow(OpenProject::CustomFieldsPlus).to receive(:feature_enabled?).and_return(false)
        login_as admin
      end

      it "returns 404" do
        get custom_fields_plus_admin_fields_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
