# frozen_string_literal: true

module CustomFieldsPlus
  # XHR endpoint: save advanced field values for a work package.
  class ValuesController < ::ApplicationController
    before_action :require_login
    before_action :require_feature_enabled
    before_action :find_work_package
    before_action :find_field
    before_action :authorize_manage

    def show
      value = FieldValue.find_by(advanced_field: @field, work_package: @work_package)
      render json: { value_ids: value&.value_ids || [] }
    end

    def update
      result = ValueWriterService.new(@work_package, @field, params[:value_ids], User.current).call
      if result[:ok]
        render json: { ok: true }
      else
        render json: { ok: false, errors: result[:errors] }, status: :unprocessable_entity
      end
    end

    private

    def require_feature_enabled
      render_404 unless OpenProject::CustomFieldsPlus.feature_enabled?
    end

    def find_work_package
      @work_package = WorkPackage.visible.find(params[:work_package_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def find_field
      @field = AdvancedField.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def authorize_manage
      return if User.current.allowed_in_project?(:manage_advanced_cfs, @work_package.project)

      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
