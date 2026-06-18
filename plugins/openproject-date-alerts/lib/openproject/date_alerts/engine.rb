# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module DateAlerts
    # Convenience accessor for the merged plugin settings (instance defaults that
    # admins can override). Falls back to the registered defaults.
    def self.settings
      Setting.plugin_openproject_date_alerts.presence ||
        Engine.settings[:default]
    end

    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. The daily scan is wired
    # into the core GoodJob cron via `add_cron_jobs` (configuration, not a core
    # edit); the notification itself is created through core's
    # `Notifications::CreateService`.
    class Engine < ::Rails::Engine
      engine_name :openproject_date_alerts

      include OpenProject::Plugins::ActsAsOpEngine

      # The engine + version under lib/ are loaded manually via the gem entry
      # file. Tell zeitwerk to IGNORE this plugin's lib/ so it doesn't try to
      # autoload lib/openproject/* and camelize "openproject" -> "Openproject"
      # (which raises NameError; our module is OpenProject). Runtime code lives
      # under app/ and autoloads normally.
      initializer "openproject_date_alerts.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        # __dir__ = lib/openproject/date_alerts ; "../.." = the plugin's lib/
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-date_alerts",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Instance-wide default lead time (days before the date) used
                   # when a user has no explicit preference row.
                   "default_lead_days" => 1,
                   # Global opt-in for the optional reminder email.
                   "send_email" => false
                 }
               } do
        # Per-user preferences live under "My account" (no special permission —
        # authenticated users manage only their own row).
        menu :my_menu,
             :date_alert_preferences,
             { controller: "/date_alerts/preferences", action: :show },
             caption: :"date_alerts.menu_caption",
             after: :notifications

        # Instance defaults are admin-only.
        menu :admin_menu,
             :date_alerts_settings,
             { controller: "/date_alerts/admin_settings", action: :show },
             caption: :"date_alerts.admin_menu_caption",
             icon: "reminder",
             after: :settings

      end

      # Register the recurring daily scan with OpenProject's GoodJob cron by
      # merging into config.good_job.cron (the real GoodJob mechanism — there is
      # no `add_cron_jobs` plugin hook in OP 17). The cron only fires when
      # config.good_job.enable_cron is true (OPENPROJECT_GOOD__JOB__ENABLE__CRON),
      # which the OP `cron` service sets. Registered but dormant otherwise.
      initializer "openproject_date_alerts.cron" do |app|
        app.config.good_job ||= ActiveSupport::OrderedOptions.new
        app.config.good_job.cron ||= {}
        app.config.good_job.cron[:date_alerts_scan] = {
          cron: "0 6 * * *", # daily at 06:00 instance-local time
          class: "DateAlerts::ScanJob",
          description: "Daily date-alert scan (openproject-date_alerts)"
        }
      end
    end
  end
end
