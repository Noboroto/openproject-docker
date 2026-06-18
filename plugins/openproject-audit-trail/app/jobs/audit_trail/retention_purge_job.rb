# frozen_string_literal: true

module AuditTrail
  # Daily GoodJob cron entry (registered in the engine). Deletes audit events
  # older than the configured retention window. Safe to run repeatedly: a run
  # with nothing to purge is a no-op.
  #
  # VERIFY against running 17-slim image: `ApplicationJob` is the core base job
  # class and GoodJob is the Active Job backend in OP 17.
  class RetentionPurgeJob < ::ApplicationJob
    queue_as :default

    def perform
      deleted = AuditEvent.purge_expired!
      Rails.logger.info("[audit_trail] retention purge removed #{deleted} event(s)")
      deleted
    end
  end
end
