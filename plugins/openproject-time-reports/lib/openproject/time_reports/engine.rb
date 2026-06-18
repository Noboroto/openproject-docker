# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module TimeReports
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. Provides advanced time
    # tracking reports (CSV export, pivot view) plus cost-rate / budget reporting.
    #
    # Cost data is sensitive, so it is gated behind a dedicated `view_cost_reports`
    # permission that is *separate* from the broader time-report permission.
    class Engine < ::Rails::Engine
      engine_name :openproject_time_reports

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_time_reports.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-time_reports",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Default currency used when a cost rate / budget does not
                   # specify one and as the cost-report display currency.
                   "default_currency" => "USD"
                 }
               } do
        project_module :time_reports do
          # Time-report viewing (hours only — no monetary data).
          permission :view_time_reports,
                     { "time_reports/reports" => %i[index pivot export] },
                     permissible_on: :project

          # Cost reports expose money (hours x rate). Kept DISTINCT from
          # view_time_reports so a user can see hours without seeing cost.
          permission :view_cost_reports,
                     { "time_reports/cost_reports" => %i[index export] },
                     permissible_on: :project

          # Budget CRUD.
          permission :manage_budgets,
                     { "time_reports/budgets" => %i[index new create edit update destroy] },
                     permissible_on: :project
        end

        # verify against running 17-slim image: the :project_menu name and the
        # `if:` module-enabled predicate API are stable across recent OP releases,
        # but confirm the menu parent (:work_packages) still exists.
        menu :project_menu,
             :time_reports,
             { controller: "/time_reports/reports", action: :index },
             param: :project_id,
             caption: :"time_reports.menu_caption",
             icon: "stats",
             after: :work_packages,
             if: ->(project) { project.module_enabled?(:time_reports) }

        menu :project_menu,
             :time_reports_cost,
             { controller: "/time_reports/cost_reports", action: :index },
             param: :project_id,
             caption: :"cost.menu_caption",
             icon: "budget",
             parent: :time_reports,
             if: ->(project) { project.module_enabled?(:time_reports) }

        menu :project_menu,
             :time_reports_budgets,
             { controller: "/time_reports/budgets", action: :index },
             param: :project_id,
             caption: :"budget.menu_caption",
             icon: "budget",
             parent: :time_reports,
             if: ->(project) { project.module_enabled?(:time_reports) }
      end
    end
  end
end
