# frozen_string_literal: true

module DateAlerts
  # Turns one [user, work_package, kind] alert into a notification, exactly once
  # per day, and only if the user may actually see the work package.
  class Notifier
    # Maps our alert kind onto core's Notification#reason enum.
    #
    # verify against running 17-slim image: the `date_alert_start_date` and
    # `date_alert_due_date` reason values exist on the core Notification model in
    # OP 17. If a future version renames/removes them, fall back to `:reminder`.
    REASON = {
      start: :date_alert_start_date,
      due:   :date_alert_due_date
    }.freeze

    def initialize(user, work_package, kind)
      @user = user
      @work_package = work_package
      @kind = kind.to_sym
    end

    def deliver
      return false if @user.nil?
      # SECURITY: never alert about a work package the user cannot see.
      return false unless @work_package.visible?(@user)

      alert_key = SentAlert.key_for(@work_package, @kind)
      return false if SentAlert.sent_today?(@user, alert_key)

      create_notification
      send_email if preference.email
      # Recorded last so a failed notification creation does not mark the day as
      # done. The DB unique index makes this race-safe across concurrent scans.
      SentAlert.mark_sent!(@user, alert_key)
      true
    end

    private

    def create_notification
      # verify against running 17-slim image: `Notifications::CreateService` is
      # instantiated with `user:` and called with these attributes. `read_ian:
      # false` marks the in-app notification unread. The service returns a
      # ServiceResult (it does not raise on validation failure).
      ::Notifications::CreateService
        .new(user: @user)
        .call(
          recipient: @user,
          resource: @work_package,
          reason: REASON.fetch(@kind),
          read_ian: false
        )
    end

    def send_email
      # Optional reminder email, opt-in per user. deliver_later puts it on the
      # same GoodJob queue.
      DateAlerts::Mailer.alert(@user, @work_package, @kind).deliver_later
    end

    def preference
      @preference ||= AlertPreference.for(@user)
    end
  end
end
