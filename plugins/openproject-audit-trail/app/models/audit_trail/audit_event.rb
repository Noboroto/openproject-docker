# frozen_string_literal: true

module AuditTrail
  # Append-only, immutable audit record. Namespaced table: op_audit_events.
  #
  # Immutability is enforced at the model layer: `readonly?` returns true for any
  # persisted record, so ActiveRecord raises ActiveRecord::ReadOnlyRecord on
  # UPDATE. Rows are created ONLY by AuditTrail::Recorder (never via HTTP) and are
  # removed only in bulk by the retention purge (delete_all, which bypasses the
  # readonly? instance guard by design — purge is the single sanctioned deletion).
  class AuditEvent < ApplicationRecord
    self.table_name = "op_audit_events"

    # Actor is optional: system / unauthenticated events have a nil actor.
    belongs_to :actor, class_name: "User", optional: true

    validates :event, presence: true
    validates :occurred_at, presence: true

    # Block UPDATE on any persisted row (INSERT-only). New records remain
    # writable so the initial create! succeeds.
    def readonly?
      !new_record?
    end

    # Belt-and-braces: forbid single-record destruction through the model. Bulk
    # retention purge uses delete_all on the relation, not this instance method.
    def destroy
      raise ActiveRecord::ReadOnlyRecord, "AuditEvent is append-only"
    end

    # Deletes events older than the configured retention window. 0 (or negative)
    # disables purging (keep forever). Uses delete_all for efficiency — no
    # callbacks, no instantiation of millions of rows.
    def self.purge_expired!
      days = OpenProject::AuditTrail.settings["retention_days"].to_i
      return 0 unless days.positive?

      where("occurred_at < ?", days.days.ago).delete_all
    end
  end
end
