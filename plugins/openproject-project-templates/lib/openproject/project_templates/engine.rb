# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module ProjectTemplates
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. The feature has two global
    # (non-project) permissions because project creation itself is a global action:
    #
    #   manage_project_templates       -> mark/unmark templates (admin-style CRUD)
    #   create_project_from_template   -> browse the gallery + instantiate a project
    #
    # Cloning is performed by the core `Projects::CopyService` (the same engine the
    # built-in "Copy project" uses). We never hand-roll the clone — the plugin's
    # value is the template registry + gallery + governance, not re-implementing
    # copy. See ProjectTemplates::CreateFromTemplateService.
    class Engine < ::Rails::Engine
      engine_name :openproject_project_templates

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_project_templates.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-project_templates",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Guard against cloning an enormous project in a single request:
                   # templates above this work-package count are refused.
                   "max_work_packages" => 2000,
                   # Attachment copying multiplies storage; off by default.
                   "copy_attachments" => false
                 }
               } do
        # GLOBAL permissions (gate project creation, not scoped to a project).
        # They MUST be declared inside a `project_module` block — that defers
        # registration until OpenProject::AccessControl is loaded. Declaring them
        # at the top level of `register` runs too early during `rake db:migrate`
        # (seeder) and raises "uninitialized constant OpenProject::AccessControl".
        # (Pattern copied from core modules/github_integration.)
        project_module :project_templates do
          permission :manage_project_templates,
                     { "project_templates/templates" => %i[index create destroy] },
                     permissible_on: :global
          permission :create_project_from_template,
                     { "project_templates/templates" => %i[gallery new instantiate] },
                     permissible_on: :global
        end

        # Admin-style management screen (mark existing projects as templates).
        # Listed under Administration; the controller still enforces the global
        # permission via `authorize_global`.
        menu :admin_menu,
             :project_templates,
             { controller: "/project_templates/templates", action: :index },
             caption: :"project_templates.menu_caption",
             icon: "project",
             if: ->(*) { User.current.allowed_globally?(:manage_project_templates) }

        # Self-service gallery: any user allowed to create projects from templates
        # gets a top-menu entry.
        menu :top_menu,
             :project_templates_gallery,
             { controller: "/project_templates/templates", action: :gallery },
             caption: :"project_templates.gallery",
             if: ->(*) { User.current.allowed_globally?(:create_project_from_template) }
      end
    end
  end
end
