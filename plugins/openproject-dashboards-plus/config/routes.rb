# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Clean project-scoped route (the malformed `member`-inside-resources form
  # from the original draft is intentionally avoided — see phase-02-custom-plugins).
  scope "projects/:project_id", as: "project" do
    get "dashboards_plus", to: "dashboards_plus/widgets#show",
        as: "dashboards_plus_widgets"
  end
end
