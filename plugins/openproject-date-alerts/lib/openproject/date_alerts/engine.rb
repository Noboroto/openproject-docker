# frozen_string_literal: true

require "openproject/plugins"

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

        # Register the recurring scan with OpenProject's GoodJob cron.
        #
        # verify against running 17-slim image: `add_cron_jobs` is the official
        # ActsAsOpEngine hook in OP 17 (used by e.g. the GitHub/GitLab/LDAP
        # engines) and merges into `config.good_job.cron`. Confirm the method
        # name and the { cron:, class: } entry shape, and that
        # `config.good_job.enable_cron` (OPENPROJECT_GOOD__JOB__ENABLE__CRON) is
        # true on the target instance, otherwise the entry is registered but
        # never fires.
        add_cron_jobs do
          {
            "DateAlerts::ScanJob" => {
              cron: "0 6 * * *", # daily at 06:00 instance-local time
              class: "DateAlerts::ScanJob"
            }
          }
        end
      end
    end
  end
end
