# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # My account -> Email digests (per-user preferences, current user only).
  scope "my", as: "email_digests" do
    get   "email_digests", to: "email_digests/preferences#show",   as: :preferences
    patch "email_digests", to: "email_digests/preferences#update"
    put   "email_digests", to: "email_digests/preferences#update"
  end

  # Administration -> Email digests (instance defaults, admin only).
  scope "admin", as: "email_digests_admin" do
    get   "email_digests", to: "email_digests/admin_settings#show",   as: :settings
    patch "email_digests", to: "email_digests/admin_settings#update"
    put   "email_digests", to: "email_digests/admin_settings#update"
  end
end
