# frozen_string_literal: true

require "open_project/plugins" # NOT "openproject/plugins"

module OpenProject
  module AttributeHelpTexts
    # Rails engine + OpenProject plugin registration.
    #
    # IMPORTANT — this plugin is a THIN EXTENSION, not a re-implementation.
    # OpenProject Community Edition ALREADY ships the full "Attribute help texts"
    # feature:
    #   * Admin area:  /admin/attribute_help_texts (core AttributeHelpTextsController)
    #   * Core models: AttributeHelpText{,::WorkPackage,::Project}
    #   * Permission:  global :edit_attribute_help_texts (authorize_global)
    #   * Rendering:   a "?" tooltip next to attribute labels, server-rendered.
    # See README.md for the redundancy analysis.
    #
    # Therefore this plugin adds NO storage (no migration / model), NO admin
    # controller, and NO routes. It only injects a small, sanitized CSS + a11y
    # enhancement for the EXISTING core tooltips via the layout <head> view hook.
    class Engine < ::Rails::Engine
      engine_name :openproject_attribute_help_texts

      include OpenProject::Plugins::ActsAsOpEngine

      # REQUIRED: zeitwerk camelizes the "openproject" dir to "Openproject" and
      # crashes on eager-load. Ignore this plugin's lib/ (required manually above).
      initializer "openproject_attribute_help_texts.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-attribute-help-texts",
               author_url: "https://example.com",
               bundled: false do
        # NO admin_menu entry: core already adds "Attribute help texts" under
        # Administration (guarded by :edit_attribute_help_texts). Adding our own
        # would duplicate the menu. The `checklist` octicon below is registered
        # only as a stable, valid-octicon reference for any future menu use.
        #
        # If you ever DO want a companion admin link, the conventions require a
        # valid octicon — use "checklist" (verified valid). Example (disabled):
        #
        #   menu :admin_menu, :attribute_help_texts_extras,
        #        { controller: "/...", action: :index },
        #        caption: :"attribute_help_texts_ext.menu",
        #        icon: "checklist",
        #        if: ->(*) { User.current.allowed_globally?(:edit_attribute_help_texts) }
      end

      # Register the view-hook listener that enhances the core help-text tooltips.
      # Loaded in to_prepare (after the framework + OpenProject::Hook +
      # ApplicationHelper are available), NOT in an initializer (too early — the
      # hook base class include would fail on an uninitialized ApplicationHelper).
      config.to_prepare do
        require "openproject/attribute_help_texts/hooks"
      end
    end
  end
end
