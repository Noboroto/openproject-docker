# frozen_string_literal: true

module EmailDigests
  # My account -> Email digests.
  #
  # A user manages ONLY their own preference. The record is always keyed by
  # `current_user.id`; no id ever comes from params, so one user can never read
  # or write another user's preference (IDOR-safe).
  class PreferencesController < ::ApplicationController
    # `require_login` is the core filter that enforces an authenticated session
    # (the My-account area requires it).
    before_action :require_login

    # OP enforces zero-trust: every action MUST declare an authorization check.
    # This is a personal "My account" page — no project/global permission
    # applies; access is scoped to current_user.
    no_authorization_required! :show, :update

    # Renders inside the "My account" area.
    layout "my"

    menu_item :email_digest_preferences

    def show
      @preference = preference
    end

    def update
      @preference = preference
      @preference.assign_attributes(preference_params)

      if @preference.save
        flash[:notice] = t(:"email_digests.saved")
        redirect_to action: :show
      else
        flash.now[:error] = @preference.errors.full_messages.to_sentence
        render :show
      end
    end

    private

    def preference
      DigestPreference.find_or_initialize_by(user_id: current_user.id)
    end

    def preference_params
      permitted = params
                  .require(:digest_preference)
                  .permit(:frequency, :quiet_from_hour, :quiet_to_hour,
                          muted_project_ids: [], muted_type_ids: [])

      # Normalise: blank quiet hours -> nil; multi-selects -> integer arrays.
      permitted[:quiet_from_hour] = permitted[:quiet_from_hour].presence
      permitted[:quiet_to_hour]   = permitted[:quiet_to_hour].presence
      permitted[:muted_project_ids] = Array(permitted[:muted_project_ids]).reject(&:blank?).map(&:to_i)
      permitted[:muted_type_ids]    = Array(permitted[:muted_type_ids]).reject(&:blank?).map(&:to_i)
      permitted
    end
  end
end
