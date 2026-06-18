# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module PlaceholderUsers
    # Rails engine + OpenProject plugin registration.
    #
    # CE-native placeholder users. OpenProject core ALSO ships a `PlaceholderUser`
    # model, but its creation is hard-gated behind
    # `EnterpriseToken.allows_to?(:placeholder_users)` and is therefore unusable on
    # a Community Edition instance. To stay usable on CE *without* colliding with
    # core's Enterprise-gated STI type ("PlaceholderUser"), this plugin defines its
    # own Principal STI subtype with a distinct, namespaced STI `type` value
    # ("OpenProject::PlaceholderUsers::PlaceholderUser") and its own admin path.
    class Engine < ::Rails::Engine
      engine_name :openproject_placeholder_users

      include OpenProject::Plugins::ActsAsOpEngine

      # Ignore this plugin's lib/ in zeitwerk (loaded manually via the gem entry);
      # otherwise eager-load camelizes "openproject" -> "Openproject" and raises.
      initializer "openproject_placeholder_users.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-placeholder_users",
               author_url: "https://example.com",
               bundled: false do
        # Global, admin-only management screen under Administration.
        # Guarded by `require_admin` in the controller; the menu entry is itself
        # only relevant to admins (admin_menu).
        menu :admin_menu,
             :op_placeholder_users,
             { controller: "/placeholder_users/placeholder_users", action: :index },
             caption: :"placeholder_users.menu",
             icon: "project",
             after: :settings
      end
    end
  end
end
