# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # My account -> Date alerts (per-user preferences, current user only).
  scope "my", as: "date_alerts" do
    get   "date_alerts", to: "date_alerts/preferences#show",   as: :preferences
    patch "date_alerts", to: "date_alerts/preferences#update"
    put   "date_alerts", to: "date_alerts/preferences#update"
  end

  # Administration -> Date alerts (instance defaults, admin only).
  scope "admin", as: "date_alerts_admin" do
    get   "date_alerts", to: "date_alerts/admin_settings#show",   as: :settings
    patch "date_alerts", to: "date_alerts/admin_settings#update"
    put   "date_alerts", to: "date_alerts/admin_settings#update"
  end
end
