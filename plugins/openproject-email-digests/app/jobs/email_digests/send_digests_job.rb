# frozen_string_literal: true

module EmailDigests
  # GoodJob cron entry registered to fire hourly. It self-gates on the configured
  # `digest_send_hour`: it only composes/sends when the current instance-local
  # hour matches. Daily digests go out every day at that hour; weekly digests on
  # Mondays only.
  #
  # When invoked explicitly with a `frequency:` (e.g. from a test or rake task),
  # the hour gate is bypassed.
  class SendDigestsJob < ::ApplicationJob
    queue_as :default

    def perform(frequency: nil, now: Time.current)
      if frequency
        run_for(frequency, now:)
        return
      end

      return unless now.hour == send_hour

      run_for(:daily, now:)
      run_for(:weekly, now:) if now.monday?
    end

    private

    def send_hour
      (OpenProject::EmailDigests.settings["digest_send_hour"] || 7).to_i
    end

    def run_for(frequency, now:)
      users_with_pending(frequency).each do |user|
        DigestBuilder.new(user, frequency:).call
      end
    end

    # Users who have at least one pending item AND whose preference matches the
    # requested frequency. Users with no preference row default to "daily".
    def users_with_pending(frequency)
      user_ids = DigestItem.pending.distinct.pluck(:user_id)
      User.where(id: user_ids).select do |user|
        DigestPreference.for(user).frequency == frequency.to_s
      end
    end
  end
end
