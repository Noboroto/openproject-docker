# frozen_string_literal: true

module DateAlerts
  # Idempotency ledger row. Presence of (user, alert_key, sent_on=today) means
  # "already alerted this user about this work package + kind today".
  class SentAlert < ApplicationRecord
    self.table_name = "op_dates_sent_alerts"

    belongs_to :user

    validates :alert_key, presence: true
    validates :sent_on, presence: true

    # Stable key for a work package + alert kind (date-independent; the day is
    # tracked separately in `sent_on`).
    def self.key_for(work_package, kind)
      "date_alert:#{kind}:#{work_package.id}"
    end

    def self.sent_today?(user, alert_key, on: Date.current)
      exists?(user_id: user.id, alert_key:, sent_on: on)
    end

    # Records that the alert was sent. Returns true if newly recorded, false if
    # it was already there (relies on the DB unique index to stay race-safe).
    def self.mark_sent!(user, alert_key, on: Date.current)
      create!(user_id: user.id, alert_key:, sent_on: on)
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
