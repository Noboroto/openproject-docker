# frozen_string_literal: true

module EmailDigests
  # Hourly GoodJob cron entry. Captures recently-changed work packages into each
  # interested user's digest queue, honouring per-user rules (mutes + quiet
  # hours) and work-package visibility.
  #
  # "Interested users" = the work package's assignee, responsible and watchers
  # who have a non-"off" digest frequency. The RuleEvaluator decides per user
  # whether the change is suppressed.
  #
  # verify against running 17-slim image: `ApplicationJob` is the core base job
  # class; GoodJob is the Active Job backend in OP 17.
  class EnqueueDigestItemsJob < ::ApplicationJob
    queue_as :default

    # `since` lets the cron capture the last window; defaults to the prior hour.
    def perform(since: 1.hour.ago)
      changed_work_packages(since).find_each do |work_package|
        recipients_for(work_package).each do |user|
          capture(user, work_package)
        end
      end
    end

    private

    def changed_work_packages(since)
      WorkPackage.where(updated_at: since..Time.current)
    end

    # Candidate recipients: assignee, responsible, watchers. Compacted + unique.
    def recipients_for(work_package)
      users = [work_package.assigned_to, work_package.responsible]
      users += watcher_users(work_package)
      users.compact.uniq
    end

    def watcher_users(work_package)
      return [] unless work_package.respond_to?(:watcher_users)

      work_package.watcher_users.to_a
    end

    def capture(user, work_package)
      preference = DigestPreference.for(user)
      return if preference.frequency == "off"

      # SECURITY: never queue an item about a work package the user cannot see.
      return unless work_package.visible?(user)

      occurred_at = work_package.updated_at || Time.current
      return if RuleEvaluator.new(preference).suppress?(work_package, at: occurred_at)

      DigestItem.enqueue(
        user:,
        work_package:,
        summary: summary_for(work_package),
        occurred_at:
      )
    end

    def summary_for(work_package)
      "##{work_package.id} #{work_package.subject}"
    end
  end
end
