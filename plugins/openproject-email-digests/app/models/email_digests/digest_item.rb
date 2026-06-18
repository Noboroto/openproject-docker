# frozen_string_literal: true

module EmailDigests
  # A single queued piece of work-package activity awaiting a user's next digest.
  # Stored in op_digest_queue; marked `sent` within the send window rather than
  # deleted, so a crash mid-send cannot silently drop items.
  class DigestItem < ApplicationRecord
    self.table_name = "op_digest_queue"

    belongs_to :user
    belongs_to :work_package

    validates :summary, presence: true
    validates :occurred_at, presence: true

    scope :pending, -> { where(sent: false) }
    scope :for_user, ->(user) { where(user_id: user.id) }

    # Insert an item idempotently. Returns true if newly recorded, false if a
    # matching (user, work_package, occurred_at) row already exists (the DB
    # unique index makes this race-safe across overlapping cron runs).
    def self.enqueue(user:, work_package:, summary:, occurred_at:)
      create!(user_id: user.id,
              work_package_id: work_package.id,
              summary:,
              occurred_at:)
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
