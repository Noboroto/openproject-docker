# frozen_string_literal: true

module EmailDigests
  # One row per user. Stores the user's digest frequency and delivery rules
  # (muted projects/types and quiet hours). When a user has no row, `.for`
  # returns a non-persisted default so digests work out of the box.
  class DigestPreference < ApplicationRecord
    self.table_name = "op_digest_preferences"

    FREQUENCIES = %w[off daily weekly].freeze

    belongs_to :user

    validates :user_id, uniqueness: true
    validates :frequency, inclusion: { in: FREQUENCIES }
    validates :quiet_from_hour, :quiet_to_hour,
              numericality: { only_integer: true,
                              greater_than_or_equal_to: 0,
                              less_than_or_equal_to: 23 },
              allow_nil: true

    # Normalise jsonb arrays to integer id arrays.
    def muted_project_ids
      Array(super).map(&:to_i)
    end

    def muted_type_ids
      Array(super).map(&:to_i)
    end

    # Returns the persisted preference for the user, or a default (unsaved)
    # preference when the user has none. `for(nil)` returns the bare default.
    def self.for(user)
      (user && find_by(user_id: user.id)) || default(user)
    end

    # Default preference object. Not persisted.
    def self.default(user = nil)
      new(
        user_id: user&.id,
        frequency: "daily",
        muted_project_ids: [],
        muted_type_ids: [],
        quiet_from_hour: nil,
        quiet_to_hour: nil
      )
    end
  end
end
