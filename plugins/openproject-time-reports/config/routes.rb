# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Project-scoped. Route names: project_time_reports_reports, etc.
  scope "projects/:project_id", as: "project" do
    namespace :time_reports do
      resources :reports, only: %i[index] do
        collection do
          get :pivot
          get :export
        end
      end

      resources :cost_reports, only: %i[index] do
        collection do
          get :export
        end
      end

      resources :budgets, except: %i[show]
    end
  end
end
