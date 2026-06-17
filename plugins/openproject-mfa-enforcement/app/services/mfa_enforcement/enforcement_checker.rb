# frozen_string_literal: true

module MfaEnforcement
  # Decides whether a given user must be redirected to the 2FA setup page.
  #
  # Gates ONLY on CE's existing 2FA result — it never reimplements TOTP.
  class EnforcementChecker
    def initialize(user, policy = Policy.current)
      @user   = user
      @policy = policy
    end

    # True => the user has run out of grace and must set up 2FA before continuing.
    def must_set_up?
      return false unless candidate?
      return false if user_has_2fa?

      grace_expired?
    end

    # True => the user is non-compliant but still inside the grace window (show a
    # banner, do not block).
    def in_grace?
      return false unless candidate?
      return false if user_has_2fa?

      !grace_expired?
    end

    # Whether the policy is active AND applies to this (logged-in) user.
    def candidate?
      return false if @user.nil?
      return false if @user.respond_to?(:logged?) && !@user.logged?
      return false unless @policy.enforced?

      @policy.applies_to?(@user)
    end

    # CE 2FA check.
    #
    # VERIFY against running 17-slim image: OpenProject CE's bundled
    # `two_factor_authentication` module exposes `User#otp_devices` with a
    # `get_active` scope (devices that are both active and default). If the
    # association/scope names differ on the running image, adjust here only — the
    # rest of the plugin is agnostic.
    #
    # FAIL SAFE: if the CE API differs and raises, treat the user as already
    # having 2FA (return true) so a naming mismatch can NEVER lock anyone out.
    def user_has_2fa?
      return true unless @user.respond_to?(:otp_devices)

      @user.otp_devices.get_active.exists?
    rescue StandardError => e
      Rails.logger.error("[mfa_enforcement] otp_devices check failed, failing open: #{e.message}")
      true
    end

    def grace_expired?
      start = @policy.policy_start_at || @user.try(:created_at)
      return false if start.nil?

      Time.current > (start + @policy.grace_period_days.days)
    end
  end
end
