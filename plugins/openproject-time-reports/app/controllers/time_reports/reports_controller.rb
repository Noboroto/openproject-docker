# frozen_string_literal: true

module TimeReports
  # Project-scoped time reports (hours only — no monetary data here; cost lives
  # in CostReportsController behind a separate permission).
  class ReportsController < ::ApplicationController
    before_action :find_project
    before_action :authorize # checks view_time_reports for index/pivot/export

    menu_item :time_reports

    def index
      @query   = build_query
      @entries = @query.entries.order(spent_on: :desc)
      @total_hours = @query.total_hours
    end

    def pivot
      @query   = build_query
      @builder = PivotBuilder.new(@query.entries.to_a)
      @pivot   = @builder.build
      @columns = @builder.all_work_packages
    end

    # SECURITY: `authorize` (above) runs before this action streams data — never
    # remove the before_action.
    def export
      @query = build_query
      csv = CsvExportService.new(@query.entries).call
      send_data csv,
                filename: "time-report-#{@project.identifier}-#{Date.current.iso8601}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    end

    def build_query
      ReportQuery.new(
        project:   @project,
        from_date: parse_date(params[:from_date], 30.days.ago.to_date),
        to_date:   parse_date(params[:to_date], Date.current),
        user_ids:  Array(params[:user_ids])
      )
    end

    def parse_date(value, fallback)
      value.present? ? Date.parse(value.to_s) : fallback
    rescue ArgumentError
      fallback
    end
  end
end
