# frozen_string_literal: true

module PdfStyler
  module Admin
    class TemplatesController < ::ApplicationController
      before_action :require_admin
      before_action :require_feature_enabled
      before_action :find_template, only: %i[edit update destroy]

      layout "admin"
      menu_item :pdf_styler_templates

      def index
        @templates = ExportTemplate.order(:name)
      end

      def new
        @template = ExportTemplate.new(
          font_family:  "Helvetica",
          accent_color: "#1A67A3",
          active:       true
        )
      end

      def create
        @template = ExportTemplate.new(template_params)
        if @template.save
          redirect_to pdf_styler_admin_templates_path,
                      notice: t("pdf_styler.flash.saved")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @template.update(template_params)
          redirect_to pdf_styler_admin_templates_path,
                      notice: t("pdf_styler.flash.saved")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @template.destroy
        redirect_to pdf_styler_admin_templates_path,
                    notice: t("pdf_styler.flash.deleted")
      end

      private

      def require_feature_enabled
        render_404 unless OpenProject::PdfStyler.feature_enabled?
      end

      def find_template
        @template = ExportTemplate.find(params[:id])
      end

      def template_params
        params.require(:export_template).permit(
          :name, :header_html, :footer_html, :cover_html,
          :font_family, :accent_color, :active
        )
      end
    end
  end
end
