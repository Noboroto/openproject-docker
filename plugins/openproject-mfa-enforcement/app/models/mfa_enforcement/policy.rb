# frozen_string_literal: true

module MfaEnforcement
  # Thin value object that wraps the plugin's `Setting` store and exposes the
  # enforcement policy (on/off, grace period, target group, start timestamp).
  #
  # Not an ActiveRecord model — there is no policy table; the policy lives in
  # `Setting.plugin_openproject_mfa_enforcement`. (The only AR model in this
  # plugin is `MfaEnforcement::AuditEvent`.)
  class Policy
    # ENV kill switch: set OPENPROJECT_2FA_ENFORCEMENT_DISABLED=true to disable
    # enforcement instance-wide without touching the database (break-glass escape
    # complementary to the rails-console escape documented in the README).
    KILL_SWITCH_ENV = "OPENPROJECT_2FA_ENFORCEMENT_DISABLED"

    DEFAULT_GRACE_DAYS = 7

    def self.current
      new(Setting.plugin_openproject_mfa_enforcement || {})
    end

    def initialize(settings)
      @s = if settings.respond_to?(:with_indifferent_access)
             settings.with_indifferent_access
           else
             (settings || {})
           end
    end

    def enforced?
      return false if kill_switch_active?

      cast_boolean(@s["enforced"])
    end

    def grace_period_days
      value = @s["grace_period_days"]
      value.present? ? value.to_i : DEFAULT_GRACE_DAYS
    end

    # nil => applies to all users.
    def enforced_group_id
      value = @s["enforced_group_id"]
      value.blank? ? nil : value.to_i
    end

    def policy_start_at
      raw = @s["policy_start_at"]
      return nil if raw.blank?

      raw.is_a?(Time) ? raw : Time.zone.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # Whether the policy targets the given user (all users, or a specific group).
    def applies_to?(user)
      return false if user.nil?

      gid = enforced_group_id
      return true if gid.nil?

      user.respond_to?(:groups) && user.groups.exists?(id: gid)
    end

    def kill_switch_active?
      cast_boolean(ENV[KILL_SWITCH_ENV])
    end

    private

    def cast_boolean(value)
      ActiveModel::Type::Boolean.new.cast(value) || false
    end
  end
end
