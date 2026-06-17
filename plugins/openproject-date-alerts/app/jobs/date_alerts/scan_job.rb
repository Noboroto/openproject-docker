# frozen_string_literal: true

module DateAlerts
  # Daily GoodJob cron entry (registered in the engine). Walks every in-window
  # alert and hands it to the Notifier, which enforces visibility + same-day
  # idempotency. Safe to run repeatedly: re-runs on the same day are no-ops.
  #
  # verify against running 17-slim image: `ApplicationJob` is the core base job
  # class; GoodJob is the Active Job backend in OP 17.
  class ScanJob < ::ApplicationJob
    queue_as :default

    def perform
      Scanner.new.each_alert do |user, work_package, kind|
        Notifier.new(user, work_package, kind).deliver
      end
    end
  end
end
