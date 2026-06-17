# frozen_string_literal: true

module AuthSso
  # Administration -> SSO Providers.
  #
  # Admin-only CRUD for SAML/OIDC provider configs. Guarded by OpenProject's
  # built-in `require_admin`, which depends only on local session/admin state —
  # so it keeps working even if SSO itself is broken (break-glass).
  class AdminProvidersController < ::ApplicationController
    before_action :require_admin
    before_action :find_provider, only: %i[edit update destroy toggle]

    layout "admin"

    menu_item :sso_providers

    def index
      @providers = ::AuthSso::Provider.order(:name)
    end

    def new
      @provider = ::AuthSso::Provider.new(kind: "oidc", active: false)
    end

    def edit; end

    def create
      @provider = ::AuthSso::Provider.new(provider_attributes)
      if @provider.save
        flash[:notice] = t(:"auth_sso.saved_restart")
        redirect_to action: :index
      else
        flash.now[:error] = @provider.errors.full_messages.to_sentence
        render :new
      end
    end

    def update
      if @provider.update(provider_attributes)
        flash[:notice] = t(:"auth_sso.saved_restart")
        redirect_to action: :index
      else
        flash.now[:error] = @provider.errors.full_messages.to_sentence
        render :edit
      end
    end

    def toggle
      @provider.update(active: !@provider.active)
      flash[:notice] = t(:"auth_sso.saved_restart")
      redirect_to action: :index
    end

    def destroy
      @provider.destroy
      flash[:notice] = t(:"auth_sso.deleted")
      redirect_to action: :index
    end

    private

    def find_provider
      @provider = ::AuthSso::Provider.find(params[:id])
    end

    # Map the flat admin form into name/kind/active + config(jsonb)/secrets(text).
    # Secrets are only overwritten when a non-blank value is submitted, so editing
    # a provider without retyping the secret preserves the stored (encrypted) one.
    def provider_attributes
      p = params.require(:provider)
      kind = p[:kind]

      attrs = {
        name:          p[:name],
        kind:          kind,
        active:        ActiveModel::Type::Boolean.new.cast(p[:active]),
        mapping_email: p[:mapping_email].presence || "email",
        mapping_name:  p[:mapping_name].presence  || "name",
        config:        build_config(p, kind)
      }

      secrets = build_secrets(p, kind)
      attrs[:secrets] = secrets if secrets.present?
      attrs
    end

    def build_config(p, kind)
      case kind
      when "saml"
        {
          "idp_sso_service_url"    => p[:idp_sso_service_url],
          "idp_cert"               => p[:idp_cert],
          "idp_cert_fingerprint"   => p[:idp_cert_fingerprint],
          "sp_entity_id"           => p[:sp_entity_id],
          "name_identifier_format" => p[:name_identifier_format],
          "allowed_clock_drift"    => p[:allowed_clock_drift],
          "callback_url"           => p[:callback_url]
        }.compact_blank
      when "oidc"
        {
          "issuer"                 => p[:issuer],
          "client_id"              => p[:client_id],
          "discovery"              => p[:discovery],
          "scopes"                 => p[:scopes],
          "uid_field"              => p[:uid_field],
          "host"                   => p[:host],
          "authorization_endpoint" => p[:authorization_endpoint],
          "token_endpoint"         => p[:token_endpoint],
          "userinfo_endpoint"      => p[:userinfo_endpoint],
          "jwks_uri"               => p[:jwks_uri],
          "callback_url"           => p[:callback_url]
        }.compact_blank
      else
        {}
      end
    end

    # Only the secret fields go here; encrypted at rest by the model.
    def build_secrets(p, kind)
      case kind
      when "saml"
        { "sp_private_key" => p[:sp_private_key] }.compact_blank
      when "oidc"
        { "client_secret" => p[:client_secret] }.compact_blank
      else
        {}
      end
    end
  end
end
