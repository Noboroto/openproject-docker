# frozen_string_literal: true

module LdapGroupSync
  # Audit record of a single sync execution (per mapping or a full run when
  # synchronized_group is nil). Captures counts, status, and any error text.
  # Never stores LDAP entries or bind credentials (PII / secrets) — counts only.
  class SyncRun < ApplicationRecord
    self.table_name = "op_ldap_gs_sync_runs"

    belongs_to :synchronized_group,
               class_name: "LdapGroupSync::SynchronizedGroup",
               optional: true

    enum :status, { running: 0, success: 1, failed: 2 }, default: :running

    validates :started_at, presence: true

    # Open a run, yield, and finalize success/failure with timing + counts.
    # Returns the run record.
    def self.track(synchronized_group: nil)
      run = create!(synchronized_group:, started_at: Time.current, status: :running)
      result = yield(run)
      run.update!(
        status: :success,
        finished_at: Time.current,
        added_count: result[:added].to_i,
        removed_count: result[:removed].to_i
      )
      run
    rescue StandardError => e
      run&.update!(status: :failed, finished_at: Time.current, error_text: e.message)
      raise
    end
  end
end
