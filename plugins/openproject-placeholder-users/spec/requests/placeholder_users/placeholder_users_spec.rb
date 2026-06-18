# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Placeholder users admin", type: :request do
  let(:admin)   { create(:admin) }
  let(:regular) { create(:user) }

  context "as an admin" do
    before { login_as(admin) }

    it "lists placeholder users" do
      get "/admin/placeholder_users"
      expect(response).to have_http_status(:ok)
    end

    it "creates a placeholder user" do
      expect do
        post "/admin/placeholder_users",
             params: { placeholder_user: { name: "QA slot" } }
      end.to change(PlaceholderUsers::PlaceholderUser, :count).by(1)
    end
  end

  context "as a non-admin" do
    before { login_as(regular) }

    it "is forbidden (require_admin guards every action)" do
      get "/admin/placeholder_users"
      expect(response).not_to have_http_status(:ok)
    end
  end
end
