# frozen_string_literal: true

module PdfStyler
  class ExportsController < ::ApplicationController
    before_action :require_login
    before_action :require_feature_enabled
    before_action :find_project_by_project_id
    before_action :authorize

    def create
      template = ExportTemplate.active.first
      return render_404 unless template

      cap   = Setting.plugin_openproject_pdf_styler.fetch("max_work_packages", 200).to_i
      wps   = @project.work_packages.visible(User.current).limit(cap)
      bytes = RenderService.new(template, wps, @project).call

      filename = "#{@project.identifier}_export_#{Time.current.strftime('%Y%m%d%H%M%S')}.pdf"

      send_data bytes,
                filename:     filename,
                type:         "application/pdf",
                disposition:  "attachment"
    end

    private

    def require_feature_enabled
      render_404 unless OpenProject::PdfStyler.feature_enabled?
    end
  end
end
