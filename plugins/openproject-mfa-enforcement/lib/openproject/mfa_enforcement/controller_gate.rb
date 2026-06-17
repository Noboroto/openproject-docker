# frozen_string_literal: true

module OpenProject
  module MfaEnforcement
    # Concern included into ApplicationController (via the engine's to_prepare
    # hook). Adds a single `before_action` that redirects non-compliant users to
    # the "set up 2FA now" blocked page once their grace period has expired.
    #
    # ADMIN LOCK-OUT SAFETY (critical):
    #   * Only browser GET/HTML, non-XHR requests are gated. API/JSON/token
    #     requests pass through (see security note in README).
    #   * An exhaustive allowlist of controller paths is NEVER gated:
    #       - this plugin's own blocked + admin settings pages (so an admin can
    #         always reach the toggle to disable enforcement);
    #       - CE's entire `two_factor_authentication` controller namespace (the
    #         2FA setup / forced-registration flow itself);
    #       - login / logout / lost-password (`account` controller, sessions).
    #     This prevents redirect loops and guarantees the setup path is reachable.
    #   * A console / ENV kill switch disables enforcement entirely
    #     (see Policy#enforced? and README).
    module ControllerGate
      extend ActiveSupport::Concern

      # Controller paths (Rails `controller_path`) that must NEVER be gated.
      # Matched by prefix so nested controllers are covered.
      ALLOWLISTED_CONTROLLER_PREFIXES = %w[
        mfa_enforcement/enforcement
        mfa_enforcement/admin_settings
        two_factor_authentication
        account
        sessions
        my/sessions
        oauth
        omniauth_callbacks
      ].freeze

      included do
        before_action :op_mfa_enforce_2fa
      end

      private

      def op_mfa_enforce_2fa
        user = op_mfa_current_user
        return if user.nil? || !op_mfa_logged_in?(user)
        return unless op_mfa_gateable_request?
        return if op_mfa_allowlisted_path?

        checker = ::MfaEnforcement::EnforcementChecker.new(user)

        if checker.must_set_up?
          redirect_to mfa_enforcement_blocked_path
        elsif checker.in_grace?
          # Non-blocking nudge while still inside the grace window.
          flash.now[:warning] = I18n.t(
            :"mfa_enforcement.banner",
            default: "Two-factor authentication will soon be required on your account."
          )
        end
      rescue StandardError => e
        # FAIL OPEN: a bug in the gate must never lock anyone out. Log and proceed.
        Rails.logger.error("[mfa_enforcement] gate skipped due to error: #{e.class}: #{e.message}")
        nil
      end

      def op_mfa_current_user
        return User.current if defined?(User) && User.respond_to?(:current)

        respond_to?(:current_user) ? current_user : nil
      end

      def op_mfa_logged_in?(user)
        # OP's User responds to `logged?`; guard for anonymous/system users.
        return user.logged? if user.respond_to?(:logged?)

        !user.try(:anonymous?)
      end

      # Only gate ordinary browser navigation. API token / JSON / XHR requests are
      # intentionally exempt so the policy targets interactive browser sessions and
      # does not break automation. (See README "Security".)
      def op_mfa_gateable_request?
        request.get? &&
          !request.xhr? &&
          (request.format.nil? || request.format.html?)
      end

      def op_mfa_allowlisted_path?
        path = controller_path.to_s
        ALLOWLISTED_CONTROLLER_PREFIXES.any? { |prefix| path.start_with?(prefix) }
      end
    end
  end
end
