# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Admin viewer + CSV export. Read-only (index only; no create/update/destroy).
  # Helpers: audit_trail_admin_events_path (HTML), .csv format for export.
  scope "admin", as: "audit_trail_admin" do
    get "audit_trail", to: "audit_trail/audit_events#index", as: :events,
                       defaults: { format: "html" }
  end
end
