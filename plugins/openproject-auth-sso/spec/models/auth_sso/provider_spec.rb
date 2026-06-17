# frozen_string_literal: true

require "spec_helper"

# Runs inside the OpenProject test harness (DB + ActiveRecord::Encryption keys
# configured). VERIFY against the running 17-slim image that encryption keys are
# present; otherwise `encrypts :secrets` raises.
RSpec.describe AuthSso::Provider, type: :model do
  let(:valid_oidc) do
    described_class.new(
      name: "Keycloak",
      kind: "oidc",
      config: { "issuer" => "https://idp.example.com", "client_id" => "op" },
      secrets: { "client_secret" => "s3cr3t" }
    )
  end

  let(:valid_saml) do
    described_class.new(
      name: "ADFS",
      kind: "saml",
      config: {
        "idp_sso_service_url" => "https://idp.example.com/sso",
        "idp_cert" => "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----"
      }
    )
  end

  describe "validations" do
    it "is valid for a complete OIDC config" do
      expect(valid_oidc).to be_valid
    end

    it "is valid for a complete SAML config" do
      expect(valid_saml).to be_valid
    end

    it "requires a name" do
      valid_oidc.name = nil
      expect(valid_oidc).not_to be_valid
    end

    it "enforces unique name" do
      valid_oidc.save!
      dup = described_class.new(name: "Keycloak", kind: "oidc",
                               config: { "issuer" => "x", "client_id" => "y" })
      expect(dup).not_to be_valid
    end

    it "rejects an unknown kind" do
      valid_oidc.kind = "ldap"
      expect(valid_oidc).not_to be_valid
    end

    it "requires issuer + client_id for OIDC" do
      valid_oidc.config = {}
      expect(valid_oidc).not_to be_valid
    end

    it "requires idp url + cert/fingerprint for SAML" do
      valid_saml.config = { "idp_sso_service_url" => "https://x/sso" }
      expect(valid_saml).not_to be_valid
    end
  end

  describe "secret encryption at rest" do
    it "does not store the secret as plaintext in the DB column" do
      valid_oidc.save!
      raw = described_class.connection.select_value(
        "SELECT secrets FROM op_sso_providers WHERE id = #{valid_oidc.id}"
      )
      expect(raw).not_to include("s3cr3t")
      expect(valid_oidc.reload.secrets["client_secret"]).to eq("s3cr3t")
    end
  end

  describe "#strategy_name" do
    it "is namespaced with sso_<id>" do
      valid_oidc.save!
      expect(valid_oidc.strategy_name).to eq("sso_#{valid_oidc.id}")
    end
  end

  describe "#oidc_options" do
    it "builds a valid options hash" do
      valid_oidc.save!
      opts = valid_oidc.oidc_options
      expect(opts[:name]).to eq(valid_oidc.strategy_name)
      expect(opts[:issuer]).to eq("https://idp.example.com")
      expect(opts[:client_options][:identifier]).to eq("op")
      expect(opts[:client_options][:secret]).to eq("s3cr3t")
      expect(opts[:scope]).to eq(%i[openid email profile])
    end
  end

  describe "#saml_options" do
    it "builds a valid options hash that requires signed assertions" do
      valid_saml.save!
      opts = valid_saml.saml_options
      expect(opts[:name]).to eq(valid_saml.strategy_name)
      expect(opts[:idp_sso_service_url]).to eq("https://idp.example.com/sso")
      expect(opts[:security][:want_assertions_signed]).to be(true)
    end
  end
end
