# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module LdapGroupSync
    # Convenience accessor for the merged plugin settings (instance defaults that
    # admins can override). Falls back to the registered defaults.
    def self.settings
      Setting.plugin_openproject_ldap_group_sync.presence ||
        Engine.settings[:default]
    end

    # Rails engine + OpenProject plugin registration.
    #
    # Adds LDAP *group membership* synchronization on top of CE's LDAP
    # *authentication* (LdapAuthSource). Admins map an LDAP group DN to an
    # OpenProject group; a scheduled (or per-login) sync mirrors LDAP membership
    # into OP group membership.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL and `config.good_job.cron` — no core files are
    # monkey-patched. All membership writes go through core
    # `Groups::AddUsersService` / `Groups::RemoveUsersService` as `User.system`,
    # so ACLs and journals are respected (no ACL bypass).
    class Engine < ::Rails::Engine
      engine_name :openproject_ldap_group_sync

      include OpenProject::Plugins::ActsAsOpEngine

      # The engine + version under lib/ are loaded manually via the gem entry
      # file. Tell zeitwerk to IGNORE this plugin's lib/ so it doesn't try to
      # autoload lib/openproject/* and camelize "openproject" -> "Openproject"
      # (which raises NameError; our module is OpenProject). Runtime code lives
      # under app/ and autoloads normally.
      initializer "openproject_ldap_group_sync.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        # __dir__ = lib/openproject/ldap_group_sync ; "../.." = the plugin's lib/
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-ldap_group_sync",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Trigger a per-user sync after a successful LDAP login.
                   "sync_on_login" => true,
                   # When true, users no longer in the LDAP group are removed
                   # from the mapped OP group on each run. When false, sync only
                   # ever adds memberships (safer default for privileged groups).
                   "remove_orphaned_memberships" => true,
                   # Hard cap on LDAP entries processed per group per run, to
                   # bound query/processing cost on large directories.
                   "max_members_per_run" => 5000
                 }
               } do
        # Admin-only management of LDAP-group -> OP-group mappings. Lives under
        # the Authentication admin section (where LDAP auth sources also live).
        # `key` and `gear` are valid octicons (see OP17-PLUGIN-CONVENTIONS.md).
        menu :admin_menu,
             :ldap_group_sync,
             { controller: "/ldap_group_sync/synchronized_groups", action: :index },
             caption: :"ldap_group_sync.menu",
             icon: "key",
             parent: :authentication,
             if: ->(*) { User.current.admin? }
      end

      # Per-login sync hook.
      #
      # verify against running 17-slim image: confirm the exact event name CE
      # publishes on a successful LDAP authentication before relying on it. As of
      # OP 17 the documented pattern is OpenProject::Notifications /
      # ActiveSupport::Notifications. If the precise event differs across 17
      # minors, this subscription is simply inert (no per-login sync) and the
      # scheduled cron below still keeps groups in sync. We deliberately do NOT
      # reopen / monkey-patch the core authentication classes.
      config.to_prepare do
        next unless defined?(OpenProject::Notifications)

        # Use a stable subscriber id so reloads in development don't stack
        # duplicate subscribers.
        OpenProject::Notifications.subscribe(
          OpenProject::Events::USER_LOGGED_IN
        ) do |payload|
          next unless OpenProject::LdapGroupSync.settings["sync_on_login"]

          user = payload[:current_user] || payload[:user]
          next unless user&.id

          ::LdapGroupSync::SynchronizationJob.perform_later(user_id: user.id)
        end
      rescue NameError
        # OpenProject::Events::USER_LOGGED_IN not defined in this image — skip
        # per-login wiring; the scheduled cron is the source of truth.
        nil
      end

      # Register the recurring full sync with OpenProject's GoodJob cron by
      # merging into config.good_job.cron (the real GoodJob mechanism — there is
      # no `add_cron_jobs` plugin hook in OP 17). Only fires when
      # config.good_job.enable_cron is true (OPENPROJECT_GOOD__JOB__ENABLE__CRON),
      # which the OP `cron` service sets. Registered but dormant otherwise.
      initializer "openproject_ldap_group_sync.cron" do |app|
        app.config.good_job ||= ActiveSupport::OrderedOptions.new
        app.config.good_job.cron ||= {}
        app.config.good_job.cron[:ldap_group_sync_full] = {
          cron: "0 2 * * *", # daily at 02:00 instance-local time
          class: "LdapGroupSync::SynchronizationJob",
          description: "Daily full LDAP group sync (openproject-ldap_group_sync)"
        }
      end
    end
  end
end
