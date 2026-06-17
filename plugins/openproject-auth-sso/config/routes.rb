# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Admin CRUD for SSO providers (Administration -> SSO Providers).
  scope "admin", as: "auth_sso" do
    resources :sso_providers,
              controller: "auth_sso/admin_providers",
              except: %i[show] do
      member do
        patch :toggle
      end
    end
  end

  # OmniAuth callback (PUBLIC / pre-auth). Constrained to our namespaced strategy
  # names (sso_<id>) so we never shadow core OmniAuth strategy callbacks.
  #
  # VERIFY against the running 17-slim image: OP defines its own
  # `/auth/:provider/callback` route for core strategies. The `:provider`
  # constraint below keeps our route scoped to `sso_<digits>` only; if core's
  # catch-all is matched first, switch to OP's `register_auth_providers` wiring
  # (see README "Alternative wiring") and delete this route.
  match "/auth/:provider/callback",
        to: "auth_sso/sessions#callback",
        via: %i[get post],
        constraints: { provider: /sso_\d+/ },
        as: :auth_sso_callback

  # OmniAuth default failure endpoint.
  get "/auth/failure", to: "auth_sso/sessions#failure", as: :auth_sso_failure
end
