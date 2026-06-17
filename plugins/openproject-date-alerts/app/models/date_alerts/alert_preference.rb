# frozen_string_literal: true

module DateAlerts
  # One row per user. Stores the user's date-alert opt-ins and lead time.
  # When a user has no row, `.for` returns a non-persisted default seeded from
  # the plugin's instance settings, so alerts work out of the box.
  class AlertPreference < ApplicationRecord
    self.table_name = "op_dates_alert_preferences"

    belongs_to :user

    validates :user_id, uniqueness: true
    validates :lead_days,
              numericality: { only_integer: true,
                              greater_than_or_equal_to: 0,
                              less_than_or_equal_to: 365 }

    # Returns the persisted preference for the user, or a default (unsaved)
    # preference when the user has none. `for(nil)` returns the bare default.
    def self.for(user)
      (user && find_by(user_id: user.id)) || default(user)
    end

    # Default preference object seeded from the instance settings. Not persisted.
    def self.default(user = nil)
      settings = OpenProject::DateAlerts.settings
      new(
        user_id: user&.id,
        start_date_enabled: true,
        due_date_enabled: true,
        lead_days: (settings["default_lead_days"] || 1).to_i,
        email: ActiveModel::Type::Boolean.new.cast(settings["send_email"]) || false
      )
    end
  end
end
