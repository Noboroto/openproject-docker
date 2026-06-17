# frozen_string_literal: true

module AuthSso
  # A DB-configured SSO identity provider (SAML or OIDC).
  #
  # Non-secret settings live in `config` (jsonb). Secret material lives in
  # `secrets`, a text column that is serialized as JSON and ENCRYPTED AT REST with
  # Rails 7 `encrypts`.
  #
  # VERIFY against the running 17-slim image that ActiveRecord::Encryption keys are
  # configured (OpenProject sets `active_record_encryption.primary_key` etc. from
  # its secret store). If keys are absent, `encrypts` raises on read/write — the
  # README documents the required env/config. We never fall back to plaintext for
  # secrets.
  class Provider < ApplicationRecord
    self.table_name = "op_sso_providers"

    KINDS = %w[saml oidc].freeze

    # Serialize the secrets Hash into the text column, then encrypt the result.
    serialize :secrets, coder: JSON, type: Hash
    encrypts :secrets

    validates :name, presence: true, uniqueness: true,
                     format: { with: /\A[\w \-]+\z/,
                               message: "only letters, numbers, spaces, _ and -" }
    validates :kind, presence: true, inclusion: { in: KINDS }

    validate :validate_kind_specific_config

    # Stable, namespaced OmniAuth strategy name. Namespacing with "sso_" keeps our
    # callback routes from colliding with core OmniAuth strategies.
    def strategy_name
      "sso_#{id}"
    end

    def config
      super || {}
    end

    def secrets
      super || {}
    end

    # ---- OmniAuth option builders -----------------------------------------

    # Options for the omniauth-saml strategy.
    # See https://github.com/omniauth/omniauth-saml for the full option list.
    def saml_options
      c = config.with_indifferent_access
      {
        name:                       strategy_name,
        # IdP single-sign-on redirect endpoint.
        idp_sso_service_url:        c[:idp_sso_service_url],
        # IdP signing certificate (PEM). Required so we can VALIDATE the assertion
        # signature and reject unsigned/forged assertions.
        idp_cert:                   c[:idp_cert],
        idp_cert_fingerprint:       c[:idp_cert_fingerprint],
        # SP entity id + ACS URL.
        issuer:                     c[:sp_entity_id],
        assertion_consumer_service_url: c[:callback_url] || default_callback_url,
        name_identifier_format:     c[:name_identifier_format].presence ||
                                    "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress",
        # SECURITY: require signed assertions; reject unsigned ones.
        security: {
          want_assertions_signed: true,
          want_assertions_encrypted: false
        },
        allowed_clock_drift:        (c[:allowed_clock_drift].presence || 5).to_f,
        # Optional SP private key for signed AuthnRequests / decryption.
        private_key:                secrets["sp_private_key"],
        attribute_statements: {
          email: [mapping_email.presence || "email"],
          name:  [mapping_name.presence || "name"]
        }
      }.compact
    end

    # Options for the omniauth_openid_connect strategy.
    # See https://github.com/omniauth/omniauth_openid_connect for the option list.
    def oidc_options
      c = config.with_indifferent_access
      {
        name:          strategy_name,
        issuer:        c[:issuer],
        discovery:     ActiveModel::Type::Boolean.new.cast(c.fetch(:discovery, true)),
        scope:         parsed_scopes(c[:scopes]),
        response_type: :code,
        uid_field:     c[:uid_field].presence || "sub",
        client_options: {
          identifier:   c[:client_id],
          secret:       secrets["client_secret"],
          redirect_uri: c[:callback_url] || default_callback_url,
          # host/endpoints are filled by discovery when enabled; provided here
          # only for the manual (discovery:false) path.
          host:                   c[:host],
          authorization_endpoint: c[:authorization_endpoint],
          token_endpoint:         c[:token_endpoint],
          userinfo_endpoint:      c[:userinfo_endpoint],
          jwks_uri:               c[:jwks_uri]
        }.compact
      }.compact
    end

    # The OmniAuth callback URL for this provider (shown in the admin UI / used as
    # the SP ACS / OIDC redirect_uri). VERIFY the host: derive it from
    # `Setting.protocol`/`Setting.host_name` in OP at request time; this helper is
    # a fallback when no explicit callback_url is configured.
    def default_callback_url
      "/auth/#{strategy_name}/callback"
    end

    private

    def parsed_scopes(raw)
      list = Array(raw).flat_map { |s| s.to_s.split(/[\s,]+/) }.map(&:strip).reject(&:blank?)
      list = %w[openid email profile] if list.empty?
      list.map(&:to_sym)
    end

    def validate_kind_specific_config
      c = config.with_indifferent_access
      case kind
      when "saml"
        if c[:idp_sso_service_url].blank?
          errors.add(:config, "SAML requires an IdP SSO service URL")
        end
        if c[:idp_cert].blank? && c[:idp_cert_fingerprint].blank?
          # SECURITY: without a cert/fingerprint we cannot validate signatures.
          errors.add(:config, "SAML requires an IdP certificate or fingerprint")
        end
      when "oidc"
        errors.add(:config, "OIDC requires an issuer") if c[:issuer].blank?
        if c[:client_id].blank?
          errors.add(:config, "OIDC requires a client_id")
        end
      end
    end
  end
end
