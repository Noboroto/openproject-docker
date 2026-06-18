# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module AuditTrail
    # Convenience accessor for the merged plugin settings (instance defaults that
    # admins can override). Falls back to the registered defaults.
    def self.settings
      Setting.plugin_openproject_audit_trail.presence ||
        Engine.settings[:default]
    end

    # Rails engine + OpenProject plugin registration.
    #
    # Hooks exclusively through the official `OpenProject::Plugins::ActsAsOpEngine`
    # `register` DSL, `ActiveSupport::Notifications.subscribe`, and
    # `config.good_job.cron` — NO core files are monkey-patched. Audit events are
    # written ONLY by the Recorder (in response to notifications); there is no
    # HTTP write path. The admin viewer is read-only + CSV export.
    class Engine < ::Rails::Engine
      engine_name :openproject_audit_trail

      include OpenProject::Plugins::ActsAsOpEngine

      # The engine + version under lib/ are loaded manually via the gem entry
      # file. Tell zeitwerk to IGNORE this plugin's lib/ so it doesn't try to
      # autoload lib/openproject/* and camelize "openproject" -> "Openproject"
      # (which raises NameError; our module is OpenProject). Runtime code lives
      # under app/ and autoloads normally.
      initializer "openproject_audit_trail.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        # __dir__ = lib/openproject/audit_trail ; "../.." = the plugin's lib/
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-audit_trail",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   # Days to retain audit events; 0 = keep forever (no purge).
                   "retention_days" => 365,
                   # Capturing the client IP is PII — gate it behind a setting.
                   "capture_ip" => true
                 }
               } do
        # Global, admin-only viewer under Administration. The admin_menu entry is
        # only visible to admins AND the controller additionally calls
        # require_admin on every action.
        menu :admin_menu,
             :audit_trail,
             { controller: "/audit_trail/audit_events", action: :index },
             caption: :"audit_trail.menu_caption",
             # Valid octicon per OP17-PLUGIN-CONVENTIONS (shield / pulse allowed).
             icon: "shield",
             after: :settings
      end

      # Subscribe to OpenProject's published ActiveSupport::Notifications and
      # record an immutable audit event for each. We do NOT monkey-patch core
      # models. Wrapped per-subscription so a recorder failure can never break
      # the originating request.
      #
      # VERIFY against running 17-slim image: the exact event names below. OP
      # publishes events via `OpenProject::Notifications` (which forwards to
      # ActiveSupport::Notifications). Names are centralized in
      # ::AuditTrail::Recorder::SUBSCRIBED_EVENTS so an unmatched/renamed event is
      # easy to adjust; an event that never fires is simply never recorded
      # (no crash). Re-confirm with, e.g.:
      #   docker run --rm openproject/openproject:17-slim \
      #     grep -rn "OpenProject::Notifications.send" /app/app /app/lib | grep -iE "member|project|user"
      config.to_prepare do
        ::AuditTrail::Recorder::SUBSCRIBED_EVENTS.each do |event|
          # Idempotent across reloads: unsubscribe stale listeners first so a
          # dev reload doesn't double-record.
          ActiveSupport::Notifications.notifier
                                      .all_listeners_for(event)
                                      .select { |l| l.instance_variable_get(:@delegate).is_a?(::AuditTrail::Recorder::Listener) }
                                      .each { |l| ActiveSupport::Notifications.unsubscribe(l) }

          listener = ::AuditTrail::Recorder::Listener.new
          ActiveSupport::Notifications.subscribe(event, listener)
        end
      end

      # Register the retention purge with OpenProject's GoodJob cron by merging
      # into config.good_job.cron (the real GoodJob mechanism — there is no
      # `add_cron_jobs` plugin hook in OP 17). Only fires when
      # config.good_job.enable_cron is true (OPENPROJECT_GOOD__JOB__ENABLE__CRON),
      # which the OP `cron` service sets. Registered but dormant otherwise.
      initializer "openproject_audit_trail.cron" do |app|
        app.config.good_job ||= ActiveSupport::OrderedOptions.new
        app.config.good_job.cron ||= {}
        app.config.good_job.cron[:audit_trail_purge] = {
          cron: "30 3 * * *", # daily at 03:30 instance-local time
          class: "AuditTrail::RetentionPurgeJob",
          description: "Daily audit-trail retention purge (openproject-audit_trail)"
        }
      end
    end
  end
end
