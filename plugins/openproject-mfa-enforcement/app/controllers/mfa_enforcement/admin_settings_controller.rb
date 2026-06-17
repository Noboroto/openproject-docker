# frozen_string_literal: true

module MfaEnforcement
  # Administration -> 2FA Enforcement.
  #
  # Admin-only (OpenProject's built-in `require_admin`). This page is allowlisted
  # in ControllerGate so an admin can ALWAYS reach it to disable enforcement,
  # even if their own account is non-compliant — a key lock-out safeguard.
  class AdminSettingsController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :mfa_enforcement

    def show
      @settings   = current_settings
      @policy     = Policy.new(@settings)
      @groups     = available_groups
      @compliance = compliance_counts
    end

    def update
      was_enforced = bool(current_settings["enforced"])
      new_settings = current_settings.merge(settings_params.to_h)
      now_enforced = bool(new_settings["enforced"])

      new_settings["policy_start_at"] = stamp_start_at(was_enforced, now_enforced, new_settings)

      Setting.plugin_openproject_mfa_enforcement = new_settings

      audit(was_enforced, now_enforced, new_settings)

      flash[:notice] = t(:"mfa_enforcement.saved")
      redirect_to action: :show
    end

    private

    def current_settings
      (Setting.plugin_openproject_mfa_enforcement || {}).to_h.with_indifferent_access
    end

    def settings_params
      params.require(:settings)
            .permit(:enforced, :grace_period_days, :enforced_group_id)
            .to_h
            .tap do |h|
              # Normalize: blank group => nil (= all users).
              h["enforced_group_id"] = nil if h["enforced_group_id"].blank?
            end
    end

    # Stamp policy_start_at when transitioning OFF->ON (starts the grace clock);
    # clear it when disabling so a future re-enable restarts grace cleanly.
    def stamp_start_at(was_enforced, now_enforced, new_settings)
      return nil unless now_enforced
      return Time.current.iso8601 if !was_enforced

      # Already enforced and staying on: keep the existing start (or stamp if missing).
      new_settings["policy_start_at"].presence || Time.current.iso8601
    end

    def audit(was_enforced, now_enforced, new_settings)
      action =
        if !was_enforced && now_enforced then "enabled"
        elsif was_enforced && !now_enforced then "disabled"
        else "updated"
        end

      AuditEvent.record!(
        action: action,
        user: current_user,
        details: new_settings.slice("enforced", "grace_period_days", "enforced_group_id", "policy_start_at")
      )
      # Also emit to the application log for external SIEM/audit shipping.
      Rails.logger.info("[mfa_enforcement] policy #{action} by user_id=#{current_user&.id}")
    end

    def available_groups
      # VERIFY against running 17-slim image: `Group` model + `.name`. Wrapped so a
      # naming difference degrades to "all users only" rather than 500-ing.
      Group.all.sort_by { |g| g.name.to_s }
    rescue StandardError
      []
    end

    # Best-effort compliance counts (users with vs without an active 2FA device).
    # Wrapped because the exact CE association is version-dependent.
    def compliance_counts
      total = User.where(type: "User").count
      with_2fa =
        if defined?(::TwoFactorAuthentication::Device)
          ::TwoFactorAuthentication::Device.where(active: true).distinct.count(:user_id)
        else
          User.all.count { |u| u.respond_to?(:otp_devices) && u.otp_devices.get_active.exists? }
        end
      { total: total, with_2fa: with_2fa, without_2fa: [total - with_2fa, 0].max }
    rescue StandardError
      nil
    end

    def bool(value)
      ActiveModel::Type::Boolean.new.cast(value) || false
    end
  end
end
