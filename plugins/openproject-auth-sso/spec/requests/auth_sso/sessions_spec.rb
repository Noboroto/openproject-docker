# frozen_string_literal: true

require "spec_helper"

# Uses OmniAuth test mode to mock the IdP round-trip. VERIFY against the running
# 17-slim image: the callback route (`/auth/<strategy>/callback`) and the
# session-login helper (`login_user!`) — both are flagged in the source with
# "verify" comments.
RSpec.describe "AuthSso SSO sessions", type: :request do
  let!(:provider) do
    AuthSso::Provider.create!(
      name: "Keycloak", kind: "oidc", active: true,
      config: { "issuer" => "https://idp.example.com", "client_id" => "op" },
      secrets: { "client_secret" => "s3cr3t" }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    Setting.plugin_openproject_auth_sso = {
      "email_domain_allowlist" => "", "disable_auto_provisioning" => false
    }
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:default] = nil
  end

  def mock_auth(email: "alice@example.com")
    OmniAuth.config.add_mock(
      provider.strategy_name.to_sym,
      provider: provider.strategy_name,
      uid: "uid-1",
      info: { "email" => email, "name" => "Alice Smith" }
    )
  end

  it "logs in and creates a user on a successful callback" do
    mock_auth
    expect do
      post "/auth/#{provider.strategy_name}/callback"
    end.to change(User, :count).by(1)
    expect(response).to have_http_status(:redirect)
  end

  it "rejects a callback for a deactivated provider" do
    provider.update!(active: false)
    mock_auth
    post "/auth/#{provider.strategy_name}/callback"
    expect(response).to redirect_to(%r{/login})
    expect(flash[:error]).to be_present
  end

  it "redirects with a flash on the failure path" do
    get "/auth/failure", params: { message: "invalid_credentials" }
    expect(response).to have_http_status(:redirect)
    expect(flash[:error]).to be_present
  end

  it "keeps local-password login available (break-glass)" do
    # The plugin must never disable the core /login route.
    get "/login"
    expect(response).to have_http_status(:ok).or have_http_status(:redirect)
  end
end
