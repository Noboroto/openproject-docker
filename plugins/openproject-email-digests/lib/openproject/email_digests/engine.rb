# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module EmailDigests
    # Convenience accessor for the merged plugin settings (instance defaults that
    # admins can override). Falls back to the registered defaults.
    def self.settings
      Setting.plugin_openproject_email_digests.presence ||
        Engine.settings[:default]
    end

    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL — no core files are monkey-patched. The two periodic jobs are
    # wired into the core GoodJob cron via `config.good_job.cron` (configuration,
    # not a core edit).
    class Engine < ::Rails::Engine
      engine_name :openproject_email_digests

      include OpenProject::Plugins::ActsAsOpEngine

      # The engine + version under lib/ are loaded manually via the gem entry
      # file. Tell zeitwerk to IGNORE this plugin's lib/ so it doesn't try to
      # autoload lib/openproject/* and camelize "openproject" -> "Openproject"
      # (which raises NameError; our module is OpenProject). Runtime code lives
      # under app/ and autoloads normally.
      initializer "openproject_email_digests.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        # __dir__ = lib/openproject/email_digests ; "../.." = the plugin's lib/
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-email_digests",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Hour-of-day (instance local) the daily/weekly digests are
                   # composed and sent. Cron fires hourly; the send job only acts
                   # when the current hour matches.
                   "digest_send_hour" => 7
                 }
               } do
        # Per-user preferences live under "My account" — authenticated users
        # manage only their own row (keyed by current_user.id). No special
        # permission required.
        menu :my_menu,
             :email_digest_preferences,
             { controller: "/email_digests/preferences", action: :show },
             caption: :"email_digests.menu_caption",
             icon: "bell",
             after: :notifications

        # Instance defaults are admin-only.
        menu :admin_menu,
             :email_digests_settings,
             { controller: "/email_digests/admin_settings", action: :show },
             caption: :"email_digests.admin_menu_caption",
             icon: "clock",
             after: :settings
      end

      # Register the two recurring jobs with OpenProject's GoodJob cron by merging
      # into config.good_job.cron (the real GoodJob mechanism — there is no
      # `add_cron_jobs` plugin hook in OP 17). The cron only fires when
      # config.good_job.enable_cron is true (OPENPROJECT_GOOD__JOB__ENABLE__CRON),
      # which the OP `cron` service sets. Registered but dormant otherwise.
      initializer "openproject_email_digests.cron" do |app|
        app.config.good_job ||= ActiveSupport::OrderedOptions.new
        app.config.good_job.cron ||= {}

        # Hourly: capture recently-changed work packages into per-user queues.
        app.config.good_job.cron[:email_digests_enqueue] = {
          cron: "0 * * * *", # top of every hour
          class: "EmailDigests::EnqueueDigestItemsJob",
          description: "Hourly digest item capture (openproject-email_digests)"
        }

        # Daily at the top of every hour the send job checks whether the current
        # hour matches digest_send_hour, then flushes daily queues (and weekly on
        # Mondays). Cron fires hourly; the job gates on the configured hour.
        app.config.good_job.cron[:email_digests_send] = {
          cron: "0 * * * *", # top of every hour; job self-gates on send hour
          class: "EmailDigests::SendDigestsJob",
          description: "Digest composition + send (openproject-email_digests)"
        }
      end
    end
  end
end
