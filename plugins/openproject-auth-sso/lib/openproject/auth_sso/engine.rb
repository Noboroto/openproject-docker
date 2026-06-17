# frozen_string_literal: true

require "openproject/plugins"

module OpenProject
  module AuthSso
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL plus a Rails initializer that mounts the OmniAuth middleware.
    # No core files are monkey-patched.
    #
    # Strategies (SAML / OIDC) are built at boot from the `op_sso_providers`
    # table. Adding or editing a provider therefore requires an app reload to take
    # effect (the OmniAuth middleware stack is assembled once, at boot) — this is
    # documented in the README and surfaced as a "restart required" banner in the
    # admin UI.
    class Engine < ::Rails::Engine
      engine_name :openproject_auth_sso

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-auth_sso",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Optional comma-separated email-domain allowlist. Empty = allow
                   # any domain the IdP asserts. Prevents open self-registration.
                   "email_domain_allowlist" => "",
                   # When true, never create new users from SSO — only log in users
                   # that already exist locally (provisioning still maps attributes).
                   "disable_auto_provisioning" => false
                 }
               } do
        # Global, admin-only feature: no project_module registration. The admin
        # menu entry is only visible to admins, and the controller additionally
        # guards with require_admin.
        menu :admin_menu,
             :sso_providers,
             { controller: "/auth_sso/admin_providers", action: :index },
             caption: :"auth_sso.menu_caption",
             icon:    "key",
             after:   :authentication
      end

      # Build the OmniAuth middleware from DB-configured providers.
      #
      # VERIFY against the running 17-slim image: OpenProject ships its own
      # OmniAuth integration (`OpenProject::Plugins::AuthPlugin#register_auth_providers`
      # + `OmniAuthLoginController`). This self-contained `OmniAuth::Builder`
      # approach (per the spec) coexists with it because our strategy names are
      # namespaced (`sso_<id>`) and our callback route is constrained to that
      # pattern. If OP's middleware ordering swallows `/auth/:provider`, switch to
      # `register_auth_providers` (see README "Alternative wiring").
      initializer "auth_sso.omniauth", after: :load_config_initializers do |app|
        app.config.middleware.use OmniAuth::Builder do
          # Guard: the providers table may not exist yet (first boot before
          # migrate) or the DB may be unavailable during asset precompile.
          # NOTE: `prov` (not `provider`) deliberately avoids shadowing
          # OmniAuth::Builder#provider, which is what registers the strategy.
          OpenProject::AuthSso::ProviderRegistry.each_active do |prov|
            case prov.kind
            when "saml"
              # omniauth-saml strategy.
              provider :saml, prov.saml_options
            when "oidc"
              # omniauth_openid_connect strategy (registered as :openid_connect).
              provider :openid_connect, prov.oidc_options
            end
          end
        end
      end

      # NOTE: we deliberately do NOT override the global `OmniAuth.config.on_failure`
      # handler — OpenProject sets its own for the strategies it ships, and a global
      # override would clobber them. OmniAuth's default failure behaviour redirects
      # to `/auth/failure`, which our routes map to SessionsController#failure.
      # VERIFY against the running 17-slim image that `/auth/failure` is not already
      # claimed by core; if it is, scope our failure route under `/sso/`.
    end
  end
end
