# frozen_string_literal: true

require "spec_helper"

# Relies on OP's FactoryBot factories (`create(:user)`) and the User model.
RSpec.describe AuthSso::UserProvisioner do
  let(:provider) do
    AuthSso::Provider.create!(
      name: "Keycloak", kind: "oidc",
      config: { "issuer" => "https://idp.example.com", "client_id" => "op" },
      secrets: { "client_secret" => "s3cr3t" }
    )
  end

  def auth_hash(email: "alice@example.com", name: "Alice Smith", uid: "uid-1")
    OmniAuth::AuthHash.new(
      provider: provider.strategy_name,
      uid: uid,
      info: { "email" => email, "name" => name }
    )
  end

  before do
    Setting.plugin_openproject_auth_sso = {
      "email_domain_allowlist" => "",
      "disable_auto_provisioning" => false
    }
  end

  it "creates a user on first login" do
    expect { described_class.new(provider, auth_hash).call }
      .to change(User, :count).by(1)
  end

  it "maps email and name" do
    user = described_class.new(provider, auth_hash).call
    expect(user.mail).to eq("alice@example.com")
    expect(user.firstname).to eq("Alice")
    expect(user.lastname).to eq("Smith")
  end

  it "NEVER grants admin to a provisioned user" do
    user = described_class.new(provider, auth_hash).call
    expect(user.admin).to be(false)
  end

  it "reuses the same user on a second login (by identity_url)" do
    first = described_class.new(provider, auth_hash).call
    expect { described_class.new(provider, auth_hash).call }
      .not_to change(User, :count)
    second = described_class.new(provider, auth_hash).call
    expect(second.id).to eq(first.id)
  end

  it "links an existing local account by email and stores identity_url" do
    existing = create(:user, mail: "bob@example.com")
    user = described_class.new(provider, auth_hash(email: "bob@example.com", uid: "bob")).call
    expect(user.id).to eq(existing.id)
    expect(user.reload.identity_url).to eq("#{provider.strategy_name}:bob")
  end

  it "rejects an auth hash with no email" do
    result = described_class.new(provider, auth_hash(email: nil)).result
    expect(result).not_to be_success
    expect(result.error).to eq(:missing_email)
  end

  it "enforces the email-domain allowlist" do
    Setting.plugin_openproject_auth_sso =
      Setting.plugin_openproject_auth_sso.merge("email_domain_allowlist" => "corp.com")
    result = described_class.new(provider, auth_hash(email: "alice@example.com")).result
    expect(result.error).to eq(:domain_not_allowed)
  end

  it "refuses to create users when auto-provisioning is disabled" do
    Setting.plugin_openproject_auth_sso =
      Setting.plugin_openproject_auth_sso.merge("disable_auto_provisioning" => true)
    result = described_class.new(provider, auth_hash).result
    expect(result.error).to eq(:provisioning_disabled)
  end
end
