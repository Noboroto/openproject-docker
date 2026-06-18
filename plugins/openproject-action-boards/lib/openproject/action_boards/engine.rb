# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module ActionBoards
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. The feature is exposed as a
    # project module (`action_boards`) with view/manage permissions and a project
    # menu entry. Card moves are applied via the core `WorkPackages::UpdateService`
    # so workflow rules and ACL always apply (see ActionBoards::CardMover).
    #
    # NOTE (storage choice): the public plan suggested layering boards on top of
    # OpenProject's Grids API. We instead persist boards/columns in dedicated,
    # namespaced tables (op_boards_boards / op_boards_columns) for an explicit,
    # testable schema. Card moves still go exclusively through the core service
    # layer. If a future revision wants boards to appear as dashboard widgets,
    # register them via `Grids::Configuration.register_widget` — VERIFY that API
    # against the running 17-slim image before wiring it.
    class Engine < ::Rails::Engine
      engine_name :openproject_action_boards

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_action_boards.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-action_boards",
               author_url: "https://example.com",
               bundled: false do
        # NOTE: `permissible_on:` is required by the permission DSL in recent
        # OpenProject releases (13.1+). VERIFY the keyword/value against the
        # running 17-slim image; older releases omit it.
        project_module :action_boards do
          permission :view_action_boards,
                     { "action_boards/boards" => %i[index show] },
                     permissible_on: :project
          permission :manage_action_boards,
                     { "action_boards/boards" => %i[new create destroy],
                       "action_boards/card_moves" => %i[update] },
                     permissible_on: :project
        end

        menu :project_menu,
             :action_boards,
             { controller: "/action_boards/boards", action: :index },
             caption: :"action_boards.menu_caption",
             icon: "columns",
             after: :work_packages,
             if: ->(project) { project.module_enabled?(:action_boards) }
      end
    end
  end
end
