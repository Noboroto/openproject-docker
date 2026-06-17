# frozen_string_literal: true

OpenProject::Application.routes.draw do
  scope "admin", as: "branding" do
    get    "branding",        to: "branding/admin_settings#show",  as: :settings
    patch  "branding",        to: "branding/admin_settings#update"
    put    "branding",        to: "branding/admin_settings#update"
    post   "branding/reset",  to: "branding/admin_settings#reset", as: :reset
    get    "branding/logo",   to: "branding/admin_settings#logo",  as: :logo
  end
end
