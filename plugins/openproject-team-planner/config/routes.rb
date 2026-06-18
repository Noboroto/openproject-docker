# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # `scope as: "project"` prefixes generated helpers with `project_`, e.g.
  # `project_teamplanner_ce_path(project_id:)` and `project_save_teamplanner_ce_path`.
  # Reference those prefixed helpers in views/controllers — NOT the bare names.
  scope "projects/:project_id", as: "project" do
    # Singular planner resource (one grid per project, driven by query params).
    get   "teamplanner_ce",      to: "teamplanner_ce/planner#show",    as: :teamplanner_ce
    post  "teamplanner_ce/save", to: "teamplanner_ce/planner#save",    as: :save_teamplanner_ce
    delete "teamplanner_ce/views/:id",
           to: "teamplanner_ce/planner#destroy",
           as: :teamplanner_ce_view
  end
end
