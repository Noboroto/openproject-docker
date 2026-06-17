# frozen_string_literal: true

require "spec_helper"
require "rack/test"

# These request specs rely on OpenProject's core spec helpers / FactoryBot
# factories (`create(:admin)`, `create(:user)`, `log_in`) which are available
# when the plugin is run inside the OpenProject test harness.
RSpec.describe "Branding admin settings", type: :request do
  let(:admin) { create(:admin) }
  let(:user)  { create(:user) }

  describe "GET /admin/branding" do
    it "denies a non-admin user (403)" do
      login_as user
      get "/admin/branding"
      expect(response).to have_http_status(:forbidden)
    end

    it "allows an admin (200)" do
      login_as admin
      get "/admin/branding"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /admin/branding" do
    before { login_as admin }

    it "updates the Setting store" do
      patch "/admin/branding", params: {
        settings: {
          primary_color: "#111111",
          accent_color:  "#222222",
          custom_css:    "body { color: red; }"
        }
      }

      expect(response).to have_http_status(:redirect)
      settings = Setting.plugin_openproject_branding
      expect(settings["primary_color"]).to eq("#111111")
      expect(settings["accent_color"]).to eq("#222222")
      expect(settings["custom_css"]).to include("color: red")
    end

    it "sanitizes malicious custom CSS so it does not appear in the rendered head" do
      patch "/admin/branding", params: {
        settings: {
          primary_color: "#111111",
          accent_color:  "#222222",
          custom_css:    "x{}</style><script>alert(1)</script>@import url('http://evil/x.css');"
        }
      }

      # Render any page that includes the layout head hook.
      get "/admin/branding"
      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).not_to match(/@import/i)
    end

    it "stores an uploaded logo blob with its content type" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("\x89PNG\r\n\x1a\nfake"), "image/png", original_filename: "logo.png"
      )

      patch "/admin/branding", params: {
        settings: { primary_color: "#111111", accent_color: "#222222", custom_css: "" },
        theme:    { logo: file }
      }

      theme = Branding::Theme.find_by(name: "default")
      expect(theme).to be_present
      expect(theme.logo_content_type).to eq("image/png")
      expect(theme.logo_blob).to be_present
    end

    it "rejects a logo with a disallowed MIME type" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("%PDF-1.4"), "application/pdf", original_filename: "x.pdf"
      )

      patch "/admin/branding", params: {
        settings: { primary_color: "#111111", accent_color: "#222222", custom_css: "" },
        theme:    { logo: file }
      }

      expect(Branding::Theme.find_by(name: "default")&.logo_blob).to be_blank
    end
  end

  describe "POST /admin/branding/reset" do
    it "resets settings to defaults" do
      login_as admin
      Setting.plugin_openproject_branding = { "primary_color" => "#000000" }

      post "/admin/branding/reset"

      expect(response).to have_http_status(:redirect)
      expect(Setting.plugin_openproject_branding["primary_color"])
        .to eq(OpenProject::Branding::Engine.settings[:default]["primary_color"])
    end
  end
end
