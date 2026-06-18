# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module Baselines
    def self.feature_enabled?
      Setting.plugin_openproject_baselines.fetch("enabled", false).in?([true, "true"])
    end

    # Maximum work packages to diff in one request (DoS cap).
    MAX_WORK_PACKAGES = 2_000

    class Engine < ::Rails::Engine
      engine_name :openproject_baselines

      include OpenProject::Plugins::ActsAsOpEngine

      initializer "openproject_baselines.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-baselines",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   "enabled"           => false,
                   "max_work_packages" => 2000
                 },
                 partial: "baselines/settings/plugin"
               } do

        project_module :baselines do
          permission :view_baselines,
                     { "baselines/baselines" => %i[index show] },
                     permissible_on: :project
          permission :manage_baselines,
                     { "baselines/baselines" => %i[new create destroy] },
                     permissible_on: :project
        end

        menu :project_menu,
             :baselines,
             { controller: "/baselines/baselines", action: :index },
             caption: :"baselines.title",
             icon: "diff",
             after: :work_packages,
             if: ->(p) {
               OpenProject::Baselines.feature_enabled? &&
                 p.module_enabled?(:baselines)
             }
      end
    end
  end
end
