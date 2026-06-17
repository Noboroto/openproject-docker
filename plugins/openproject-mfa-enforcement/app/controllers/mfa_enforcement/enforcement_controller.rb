# frozen_string_literal: true

module MfaEnforcement
  # The "set up 2FA now" gate page that non-compliant users are redirected to
  # after their grace period expires.
  #
  # This controller is allowlisted in ControllerGate, so visiting it never
  # re-triggers the gate (no redirect loop). It only requires a logged-in user;
  # the link it renders points at CE's own 2FA device setup flow.
  class EnforcementController < ::ApplicationController
    def blocked
      @setup_path = two_factor_setup_path
      render :blocked
    end

    private

    # VERIFY against running 17-slim image: CE's 2FA device setup route is
    # `my_two_factor_devices_new_path` (controller
    # TwoFactorAuthentication::My::TwoFactorDevicesController). The forced-setup
    # flow uses `new_forced_2fa_device_path`. We prefer the standard My route and
    # fall back to a literal path if the helper is absent on this image.
    def two_factor_setup_path
      if respond_to?(:my_two_factor_devices_new_path)
        my_two_factor_devices_new_path
      else
        "/my/two_factor_devices/new"
      end
    rescue StandardError
      "/my/two_factor_devices/new"
    end
  end
end
