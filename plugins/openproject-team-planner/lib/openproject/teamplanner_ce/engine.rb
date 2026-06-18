# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module TeamplannerCe
    # Rails engine + OpenProject plugin registration.
    #
    # Exposes a resource/assignee calendar (FullCalendar resource-timeline) as a
    # project module (`teamplanner_ce`). The Angular standalone app (compiled in
    # Dockerfile.app) is served from /public/teamplanner_ce/ and bootstrapped via
    # the <op-team-planner-ce> custom element in the show view.
    # WP data is served by PlannerController#data (JSON), scoped through
    # WorkPackage.visible(current_user) — never leaks across permission boundaries.
    class Engine < ::Rails::Engine
      engine_name :openproject_teamplanner_ce

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_teamplanner_ce.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-teamplanner_ce",
               author_url: "https://example.com",
               bundled: false do
        # NOTE: `permissible_on:` is required by the permission DSL in recent
        # OpenProject releases (13.1+). VERIFY the keyword/value against the
        # running 17-slim image; older releases omit it.
        project_module :teamplanner_ce do
          permission :view_teamplanner_ce,
                     { "teamplanner_ce/planner" => %i[show data] },
                     permissible_on: :project
          permission :manage_teamplanner_ce_views,
                     { "teamplanner_ce/planner" => %i[save destroy] },
                     permissible_on: :project
        end

        menu :project_menu,
             :teamplanner_ce,
             { controller: "/teamplanner_ce/planner", action: :show },
             caption: :"teamplanner_ce.menu",
             icon: "calendar",
             after: :work_packages,
             if: ->(project) { project.module_enabled?(:teamplanner_ce) }
      end
    end
  end
end
