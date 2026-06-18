# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module CustomFieldsPlus
    def self.feature_enabled?
      Setting.plugin_openproject_custom_fields_plus.fetch("enabled", false).in?([true, "true"])
    end

    class Engine < ::Rails::Engine
      engine_name :openproject_custom_fields_plus

      include OpenProject::Plugins::ActsAsOpEngine

      initializer "openproject_custom_fields_plus.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-custom_fields_plus",
               author_url: "https://example.com",
               bundled: false,
               settings: { default: { "enabled" => false },
                           partial: "custom_fields_plus/settings/plugin" } do

        project_module :custom_fields_plus do
          permission :view_advanced_cfs,
                     { "custom_fields_plus/values" => %i[show] },
                     permissible_on: :project
          permission :manage_advanced_cfs,
                     { "custom_fields_plus/values" => %i[update] },
                     permissible_on: :project
        end

        menu :admin_menu, :custom_fields_plus,
             { controller: "/custom_fields_plus/admin/fields", action: :index },
             caption: :"custom_fields_plus.admin.title",
             icon: "sliders",
             if: ->(*) { OpenProject::CustomFieldsPlus.feature_enabled? }
      end

      config.to_prepare do
        require_dependency "openproject/custom_fields_plus/hooks/form_hook"
      end
    end
  end
end
