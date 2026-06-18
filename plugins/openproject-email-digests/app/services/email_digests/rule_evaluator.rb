# frozen_string_literal: true

module EmailDigests
  # Decides whether a given work-package change should be suppressed (i.e. NOT
  # queued for) a user, based on their digest preference. Pure logic, no I/O.
  class RuleEvaluator
    def initialize(preference)
      @preference = preference
    end

    # True when the change must NOT be added to the user's digest queue.
    def suppress?(work_package, at: Time.current)
      return true if @preference.frequency == "off"
      return true if @preference.muted_project_ids.include?(work_package.project_id)
      return true if @preference.muted_type_ids.include?(work_package.type_id)

      in_quiet_hours?(at)
    end

    # True when `at` falls inside the configured quiet-hours window. Handles
    # wrap-around windows (e.g. 22:00 -> 06:00). No window configured => never
    # quiet.
    def in_quiet_hours?(at = Time.current)
      from = @preference.quiet_from_hour
      to   = @preference.quiet_to_hour
      return false if from.nil? || to.nil?
      return false if from == to # zero-length window

      hour = at.hour
      if from < to
        hour >= from && hour < to
      else
        # Wraps past midnight.
        hour >= from || hour < to
      end
    end
  end
end
