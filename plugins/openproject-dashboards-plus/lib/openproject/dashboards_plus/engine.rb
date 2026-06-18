# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module DashboardsPlus
    # Rails engine + OpenProject plugin registration.
    #
    # Provides server-rendered dashboard widgets (project-health KPI card,
    # work-package status summary, and a budget widget). Hooks exclusively
    # through the official ActsAsOpEngine `register` DSL — no core monkey-patching.
    class Engine < ::Rails::Engine
      engine_name :openproject_dashboards_plus

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_dashboards_plus.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-dashboards_plus",
               author_url: "https://example.com",
               bundled: false,
               settings: { default: { "widget_refresh_seconds" => 60 } } do
        project_module :dashboards_plus do
          permission :view_dashboards_plus_widgets,
                     { "dashboards_plus/widgets" => %i[show] },
                     permissible_on: :project
        end

        menu :project_menu,
             :dashboards_plus,
             { controller: "/dashboards_plus/widgets", action: :show },
             param: :project_id,
             caption: :"dashboards_plus.menu_caption",
             icon: "meter",
             after: :overview,
             if: ->(project) { project.module_enabled?(:dashboards_plus) }
      end

      # Register custom Grids widgets.
      #
      # verify against running 17-slim image: the real signature in OP 17 is
      #   Grids::Configuration.register_widget(identifier_string, grid_classes)
      # where `grid_classes` is a Grid subclass (e.g. Grids::Dashboard) or an
      # array — NOT a `modules:` keyword. The plan's `modules:` form is kept
      # below only as a fallback for older APIs; the rescue covers signature
      # drift so a boot never fails on this optional integration.
      initializer "dashboards_plus.register_widgets" do
        next unless defined?(::Grids::Configuration)

        register = lambda do |identifier|
          if defined?(::Grids::Dashboard)
            ::Grids::Configuration.register_widget(identifier, ::Grids::Dashboard)
          else
            ::Grids::Configuration.register_widget(identifier, modules: [:dashboards_plus])
          end
        end

        %w[
          DashboardsPlus::ProjectHealthWidget
          DashboardsPlus::WpStatusSummaryWidget
          DashboardsPlus::BudgetWidget
        ].each do |identifier|
          begin
            register.call(identifier)
          rescue StandardError => e
            Rails.logger.warn("[dashboards_plus] widget #{identifier} not registered: #{e.message}")
          end
        end
      end
    end
  end
end
