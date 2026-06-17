# frozen_string_literal: true

module MfaEnforcement
  # Append-only audit trail of enforcement policy changes (enable / disable /
  # update). Satisfies the "audit-log enable/disable of enforcement" security
  # requirement. Namespaced table: op_mfa_audit_events.
  class AuditEvent < ApplicationRecord
    self.table_name = "op_mfa_audit_events"

    ACTIONS = %w[enabled disabled updated].freeze

    # The admin who made the change. Optional so an event is never lost if the
    # acting user record is later removed.
    belongs_to :user, optional: true

    validates :action, presence: true, inclusion: { in: ACTIONS }

    # Records an audit event; swallows persistence errors so auditing can never
    # block the actual settings save.
    def self.record!(action:, user:, details: {})
      create!(action: action, user: user, details: details)
    rescue StandardError => e
      Rails.logger.error("[mfa_enforcement] failed to write audit event: #{e.message}")
      nil
    end
  end
end
