# frozen_string_literal: true

require "openproject/plugins"

module OpenProject
  module MfaEnforcement
    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — NO core files are monkey-patched. The login-time gate is
    # installed by including a concern into ApplicationController via the official
    # `ActiveSupport::Reloader.to_prepare` hook.
    #
    # This plugin builds ENFORCEMENT on top of OpenProject Community Edition's
    # existing TOTP/2FA (the bundled `two_factor_authentication` module). It never
    # reimplements TOTP — it only gates on CE's result.
    class Engine < ::Rails::Engine
      engine_name :openproject_mfa_enforcement

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-mfa_enforcement",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   "enforced"          => false,
                   "grace_period_days" => 7,
                   # nil = applies to ALL users; otherwise restrict to a group id.
                   "enforced_group_id" => nil,
                   # Stamped with Time.current.iso8601 when an admin enables the
                   # policy; the grace window is measured from here.
                   "policy_start_at"   => nil
                 }
               } do
        # Global, admin-only settings page under Administration. The admin_menu is
        # only visible to admins; the controller additionally calls require_admin.
        menu :admin_menu,
             :mfa_enforcement,
             { controller: "/mfa_enforcement/admin_settings", action: :show },
             caption: :"mfa_enforcement.menu_caption",
             # VERIFY against running 17-slim image: icon name
             # "two-factor-authentication" must exist in OP's icon set; fall back
             # to "locked" if the build complains.
             icon:    "two-factor-authentication",
             after:   :authentication
      end

      # Install the login-time gate. The concern adds a `before_action` to every
      # controller that calls EnforcementChecker and redirects non-compliant users
      # to the "set up 2FA" blocked page (after grace) without ever blocking the
      # 2FA-setup path, the admin settings page, or login/logout — so admins are
      # never locked out.
      #
      # VERIFY against running 17-slim image: that `::ApplicationController` is the
      # correct shared base controller and that the to_prepare include pattern is
      # still the supported way to extend it (it is the same mechanism CE plugins
      # use). A console escape hatch always exists regardless (see README).
      initializer "mfa_enforcement.gate" do
        require "openproject/mfa_enforcement/controller_gate"

        ActiveSupport::Reloader.to_prepare do
          ::ApplicationController.include(OpenProject::MfaEnforcement::ControllerGate)
        end
      end
    end
  end
end
