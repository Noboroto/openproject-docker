# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module PdfStyler
    def self.feature_enabled?
      Setting.plugin_openproject_pdf_styler.fetch("enabled", false).in?([true, "true"])
    end

    class Engine < ::Rails::Engine
      engine_name :openproject_pdf_styler

      include OpenProject::Plugins::ActsAsOpEngine

      initializer "openproject_pdf_styler.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-pdf_styler",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   "enabled"         => false,
                   "max_work_packages" => 200
                 },
                 partial: "pdf_styler/settings/plugin"
               } do

        project_module :pdf_styler do
          permission :export_styled_pdf,
                     { "pdf_styler/exports" => %i[create] },
                     permissible_on: :project
        end

        menu :admin_menu, :pdf_styler_templates,
             { controller: "/pdf_styler/admin/templates", action: :index },
             caption: :"pdf_styler.admin.title",
             icon: "gear",
             if: ->(*) { OpenProject::PdfStyler.feature_enabled? }
      end
    end
  end
end
