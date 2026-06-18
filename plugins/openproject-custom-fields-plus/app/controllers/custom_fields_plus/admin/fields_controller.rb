# frozen_string_literal: true

module CustomFieldsPlus
  module Admin
    class FieldsController < ::ApplicationController
      before_action :require_admin
      before_action :require_feature_enabled
      before_action :find_field, only: %i[edit update destroy]

      layout "admin"
      menu_item :custom_fields_plus

      def index
        @fields = AdvancedField.order(:name)
      end

      def new
        @field = AdvancedField.new
      end

      def create
        @field = AdvancedField.new(field_params)
        if @field.save
          redirect_to custom_fields_plus_admin_fields_path,
                      notice: t("custom_fields_plus.flash.saved")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @field.update(field_params)
          redirect_to custom_fields_plus_admin_fields_path,
                      notice: t("custom_fields_plus.flash.saved")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @field.destroy
        redirect_to custom_fields_plus_admin_fields_path,
                    notice: t("custom_fields_plus.flash.deleted")
      end

      private

      def require_feature_enabled
        render_404 unless OpenProject::CustomFieldsPlus.feature_enabled?
      end

      def find_field
        @field = AdvancedField.find(params[:id])
      end

      def field_params
        params.require(:advanced_field).permit(
          :name, :field_type,
          scope_project_ids: [], scope_group_ids: []
        )
      end
    end
  end
end
