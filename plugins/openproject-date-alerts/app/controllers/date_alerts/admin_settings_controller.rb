# frozen_string_literal: true

module DateAlerts
  # Administration -> Date alerts. Instance-wide defaults (default lead days +
  # global email opt-in) persisted to the core `Setting` store.
  #
  # Admin-only via the core `require_admin` filter (the admin_menu entry is also
  # only visible to admins).
  class AdminSettingsController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :date_alerts_settings

    def show
      @settings = current_settings
    end

    def update
      Setting.plugin_openproject_date_alerts =
        current_settings.merge(settings_params.to_h)

      flash[:notice] = t(:"date_alerts.saved")
      redirect_to action: :show
    end

    private

    def current_settings
      Setting.plugin_openproject_date_alerts.presence ||
        OpenProject::DateAlerts::Engine.settings[:default].dup
    end

    def settings_params
      params.require(:settings).permit(:default_lead_days, :send_email)
    end
  end
end
