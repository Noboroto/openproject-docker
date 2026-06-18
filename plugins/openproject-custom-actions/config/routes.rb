# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Admin catalog management (global, admin-only via require_admin).
  scope "custom_actions", as: "custom_actions" do
    resources :actions,
              controller: "custom_actions/actions",
              only: %i[index new create edit update destroy]
  end

  # Project-scoped apply endpoint. Maps to custom_actions/executions#create, which
  # the engine guards with :execute_custom_actions (permissible_on: :project) and
  # which routes the change through the core WorkPackages::UpdateService.
  scope "projects/:project_id", as: "project" do
    post "custom_actions/:action_id/work_packages/:work_package_id/apply",
         to: "custom_actions/executions#create",
         as: :apply_custom_action
  end
end
