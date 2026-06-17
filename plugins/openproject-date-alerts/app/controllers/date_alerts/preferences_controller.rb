# frozen_string_literal: true

module DateAlerts
  # My account -> Date alerts.
  #
  # A user manages ONLY their own preference. The record is always keyed by
  # `current_user.id`; no id ever comes from params, so one user can never read
  # or write another user's preference.
  class PreferencesController < ::ApplicationController
    # verify against running 17-slim image: `require_login` is the core filter
    # that enforces an authenticated session (the My-account area requires it).
    before_action :require_login

    # Renders inside the "My account" area.
    # verify against running 17-slim image: the My-account layout name ("my").
    layout "my"

    menu_item :date_alert_preferences

    def show
      @preference = preference
    end

    def update
      @preference = preference
      @preference.assign_attributes(preference_params)

      if @preference.save
        flash[:notice] = t(:"date_alerts.saved")
        redirect_to action: :show
      else
        flash.now[:error] = @preference.errors.full_messages.to_sentence
        render :show
      end
    end

    private

    def preference
      AlertPreference.find_or_initialize_by(user_id: current_user.id)
    end

    def preference_params
      params
        .require(:alert_preference)
        .permit(:start_date_enabled, :due_date_enabled, :lead_days, :email)
    end
  end
end
