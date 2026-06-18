# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module CustomActions
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. Two surfaces:
    #
    #   * Admin: a global, admin-only screen (`require_admin`) to manage the catalog
    #     of custom-action definitions (conditions + attribute changes).
    #   * Project: a project-scoped endpoint to APPLY an action to a work package,
    #     guarded by `:execute_custom_actions` (permissible_on: :project) and routed
    #     through the core `WorkPackages::UpdateService` (see ExecuteActionService),
    #     so workflow/contract/permission failures yield HTTP 422 and never bypass
    #     the ACL.
    class Engine < ::Rails::Engine
      engine_name :openproject_custom_actions

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_custom_actions.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-custom_actions",
               author_url: "https://example.com",
               bundled: false do
        # Applying an action is a project-scoped capability (members with this
        # permission may apply); the underlying WorkPackages::UpdateService still
        # enforces the user's own edit/transition rights, so applying can never
        # escalate privileges.
        #
        # NOTE: `permissible_on:` is required by the permission DSL in recent
        # OpenProject releases (13.1+). VERIFY the keyword/value against the
        # running 17-slim image; older releases omit it.
        project_module :custom_actions do
          permission :execute_custom_actions,
                     { "custom_actions/executions" => %i[create] },
                     permissible_on: :project
        end

        # Admin catalog management. The screen itself is guarded by `require_admin`
        # in the controller; the menu entry is only shown to admins.
        menu :admin_menu,
             :custom_actions,
             { controller: "/custom_actions/actions", action: :index },
             caption: :"custom_actions.menu_caption",
             icon: "workflow",
             if: ->(*) { User.current.admin? }
      end
    end
  end
end
