# frozen_string_literal: true

module LdapGroupSync
  # Runs LDAP group synchronization in the background.
  #
  # - No args (cron / "Sync now" full run): syncs every mapping.
  # - `synchronized_group_id:`: syncs a single mapping.
  # - `user_id:`: per-login sync — syncs only mappings whose LDAP group could
  #   affect that user (currently all mappings; the diff is naturally a no-op for
  #   unaffected groups). Cheap relative to the value of keeping login fresh.
  #
  # Each mapping run is wrapped in a SyncRun audit record. Safe to re-run: the
  # service diffs current vs desired, so repeated runs converge with no spam.
  #
  # verify against running 17-slim image: `ApplicationJob` is the core base job
  # class; GoodJob is the Active Job backend in OP 17.
  class SynchronizationJob < ::ApplicationJob
    queue_as :default

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
