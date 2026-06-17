# frozen_string_literal: true

require "openproject/plugins"

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

      # Autoload + register the view-hook listener that injects the compiled
      # theme CSS and favicon override into the layout <head>.
      initializer "branding.register_hooks" do
        require "openproject/branding/hooks"
      end
    end
  end
end
