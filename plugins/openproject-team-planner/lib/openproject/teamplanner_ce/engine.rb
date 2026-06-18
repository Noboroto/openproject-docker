# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module TeamplannerCe
    # Rails engine + OpenProject plugin registration.
    #
    # Exposes a read-only resource/assignee calendar as a project module
    # (`teamplanner_ce`). The planner reads work packages exclusively through
    # `WorkPackage.visible(current_user)` so it never leaks cards across permission
    # boundaries. Only saved-view preferences are persisted (op_teamplanner_ce_*).
    #
    # WHERE ANGULAR WOULD GO: OpenProject's own Team planner is an Angular calendar
    # component. A production-grade integration would register an Angular component
    # via the OP frontend module system. This styled server-rendered grid is the
    # deliberate first iteration.
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
                     { "teamplanner_ce/planner" => %i[show] },
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
