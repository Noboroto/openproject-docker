# frozen_string_literal: true

module EmailDigests
  # Administration -> Email digests. Instance-wide default send hour, persisted
  # to the core `Setting` store.
  #
  # Admin-only via the core `require_admin` filter (the admin_menu entry is also
  # only visible to admins).
  class AdminSettingsController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :email_digests_settings

    def show
      @settings = current_settings
    end

    def update
      Setting.plugin_openproject_email_digests =
        current_settings.merge(settings_params.to_h)

      flash[:notice] = t(:"email_digests.saved")
      redirect_to action: :show
    end

    private

    def current_settings
      Setting.plugin_openproject_email_digests.presence ||
        OpenProject::EmailDigests::Engine.settings[:default].dup
    end

    def settings_params
      params.require(:settings).permit(:digest_send_hour)
    end
  end
end
