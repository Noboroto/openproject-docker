# frozen_string_literal: true

# Rails 7.1 migration (OpenProject 17 runs on Rails 7.1+).
# VERIFY exact Rails version against the running image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpSsoProviders < ActiveRecord::Migration[7.1]
  def change
    create_table :op_sso_providers, if_not_exists: true do |t|
      t.string  :name,   null: false                 # human label + basis of strategy name
      t.string  :kind,   null: false                 # "saml" | "oidc"
      t.boolean :active, null: false, default: false

      # Non-secret IdP/SP configuration (idp_sso_service_url, idp_cert, issuer,
      # client_id, scopes, discovery, ...). Safe to store as plain jsonb.
      t.jsonb   :config, null: false, default: {}

      # Secret material (OIDC client_secret, SAML SP private key, ...).
      # Stored as TEXT — not jsonb — because Rails 7 `encrypts` writes a ciphertext
      # STRING that is not valid JSON. The model serializes a Hash into this text
      # column and `encrypts` it at rest. See AuthSso::Provider.
      t.text    :secrets

      # Attribute mapping from the IdP assertion / userinfo to the OP user.
      t.string  :mapping_email, default: "email"
      t.string  :mapping_name,  default: "name"

      t.timestamps
    end

    add_index :op_sso_providers, :name, unique: true, if_not_exists: true
    add_index :op_sso_providers, %i[active kind], if_not_exists: true
  end
end
