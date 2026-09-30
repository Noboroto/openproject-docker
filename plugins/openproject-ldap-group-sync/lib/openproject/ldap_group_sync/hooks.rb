# frozen_string_literal: true

# Loaded from the engine's `config.to_prepare`, once core has loaded
# OpenProject::Hook. Users::LoginService calls the `:user_logged_in` hook with
# { user:, request:, session: } after every successful login.

module OpenProject
  module LdapGroupSync
    class Hooks < ::OpenProject::Hook::Listener
      def user_logged_in(context)
        return unless OpenProject::LdapGroupSync.settings["sync_on_login"]

        user = context[:user]
        # SynchronizationJob syncs every mapping regardless of user, so only an
        # LDAP login should pay for it; local and SSO logins are skipped.
        return if user&.ldap_auth_source_id.blank?

        ::LdapGroupSync::SynchronizationJob.perform_later(user_id: user.id)
      rescue StandardError => e
        # A sync problem must never break the login itself.
        Rails.logger.error("[ldap_group_sync] login sync not enqueued: #{e.class}")
      end
    end
  end
end
