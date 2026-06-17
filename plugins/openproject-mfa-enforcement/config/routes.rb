# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Gate page (logged-in, non-compliant users land here after grace expires).
  # Helper: mfa_enforcement_blocked_path
  scope "mfa_enforcement", as: "mfa_enforcement" do
    get "blocked", to: "mfa_enforcement/enforcement#blocked", as: :blocked
  end

  # Admin settings page. Helper: mfa_enforcement_admin_settings_path
  scope "admin", as: "mfa_enforcement_admin" do
    get   "two_factor_enforcement", to: "mfa_enforcement/admin_settings#show",   as: :settings
    patch "two_factor_enforcement", to: "mfa_enforcement/admin_settings#update"
    put   "two_factor_enforcement", to: "mfa_enforcement/admin_settings#update"
  end
end
