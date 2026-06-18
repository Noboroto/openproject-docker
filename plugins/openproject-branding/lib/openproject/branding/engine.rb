# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module Branding
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. Theme CSS is injected into
    # every layout <head> via OpenProject's view-hook API (see hooks.rb).
    class Engine < ::Rails::Engine
      engine_name :openproject_branding

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_branding.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-branding",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   "primary_color" => "#1A67A3",
                   "accent_color"  => "#35C53F",
                   "custom_css"    => "",
                   # The favicon / logo override is stored as a data URI so it can
                   # live in the Setting store; the original binary lives in the
                   # Theme model (op_branding_themes) for serving via a controller.
                   "logo_data_uri" => nil
                 }
               } do
        # Global, admin-only feature: no project_module registration.
        # Adds "Branding" under Administration. Guarded by require_admin in the
        # controller (the admin_menu is itself only visible to admins).
        menu :admin_menu,
             :branding_settings,
             { controller: "/branding/admin_settings", action: :show },
             caption: :"branding.menu_caption",
             icon:    "design",
             after:   :settings
      end

      # Register the view-hook listener that injects the compiled theme CSS and
      # favicon override into the layout <head>. Loaded in to_prepare (after the
      # framework + OpenProject::Hook + ApplicationHelper are available), NOT in an
      # initializer (too early — the hook base class include would fail).
      config.to_prepare do
        require "openproject/branding/hooks"
      end
    end
  end
end
