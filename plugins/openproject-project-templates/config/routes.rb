# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Admin-style management of the template registry.
  scope "admin", as: "project_templates_admin" do
    get    "project_templates",          to: "project_templates/templates#index",   as: :index
    post   "project_templates",          to: "project_templates/templates#create"
    delete "project_templates/:id",      to: "project_templates/templates#destroy", as: :destroy
  end

  # Self-service gallery + "create from template" flow.
  scope "project_templates", as: "project_templates" do
    get  "gallery",                          to: "project_templates/templates#gallery",     as: :gallery
    get  "templates/:template_id/new",       to: "project_templates/templates#new",         as: :new
    post "templates/:template_id/instantiate", to: "project_templates/templates#instantiate", as: :instantiate
  end
end
