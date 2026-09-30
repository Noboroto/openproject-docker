# frozen_string_literal: true

# Loaded from the engine's `config.to_prepare`, once core has loaded
# OpenProject::Hook. Core announces a successful login only through the
# `:user_logged_in` hook (Users::LoginService, context: user, request, session);
# there is no login event on OpenProject::Notifications.

module OpenProject
  module AuditTrail
    class Hooks < ::OpenProject::Hook::Listener
      def user_logged_in(context)
        user = context[:user]
        request = context[:request]

        ::AuditTrail::Recorder.new.record(
          event: ::AuditTrail::Recorder::LOGIN_EVENT,
          payload: { user: },
          actor: user,
          ip: request&.remote_ip
        )
      rescue StandardError => e
        # Auditing must never break the login itself.
        Rails.logger.error("[audit_trail] failed to record login: #{e.class}: #{e.message}")
      end
    end
  end
end
