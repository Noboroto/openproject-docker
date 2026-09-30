# frozen_string_literal: true

module LdapGroupSync
  # Runs LDAP group synchronization in the background.
  #
  # - No args (cron / "Sync now" full run): syncs every mapping.
  # - `synchronized_group_id:`: syncs a single mapping.
  # - `user_id:`: enqueued by the login hook. Accepted but not used to narrow the
  #   run: it is a full sync of every mapping, so the concurrency key below
  #   treats it the same as a cron run.
  #
  # Each mapping run is wrapped in a SyncRun audit record. Safe to re-run: the
  # service diffs current vs desired, so repeated runs converge with no spam.
  #
  # verify against running 17-slim image: `ApplicationJob` is the core base job
  # class; GoodJob is the Active Job backend in OP 17.
  class SynchronizationJob < ::ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :default

    # At most one queued-or-running job per scope. Without this, a burst of LDAP
    # logins enqueues one full sync each; they race on the same groups and put
    # load on the directory. Extra enqueues are dropped: the job already in the
    # queue syncs everything they would have.
    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> do
        options = arguments.first.is_a?(Hash) ? arguments.first : {}
        "#{self.class.name}-#{options[:synchronized_group_id] || 'all'}"
      end
    )

    def perform(synchronized_group_id: nil, user_id: nil)
      mappings =
        if synchronized_group_id
          SynchronizedGroup.where(id: synchronized_group_id)
        else
          SynchronizedGroup.where(sync_users: true)
        end

      mappings.find_each do |mapping|
        sync_one(mapping)
      end
    end

    private

    def sync_one(mapping)
      SyncRun.track(synchronized_group: mapping) do |_run|
        SynchronizeService.new(mapping).call
      end
    rescue StandardError => e
      # The failed SyncRun already captured the message; log a non-PII summary
      # and continue with the next mapping rather than aborting the whole run.
      Rails.logger.error(
        "[ldap_group_sync] sync failed for mapping ##{mapping.id} (dn redacted): #{e.class}"
      )
    end
  end
end
