# frozen_string_literal: true

module TimeReports
  # Cost report = time-report pivot/listing with a cost column + grand total.
  #
  # Gated by `view_cost_reports` (distinct from view_time_reports): monetary data
  # is confidential and must NOT be visible to the broader time-report audience.
  class CostReportsController < ::ApplicationController
    before_action :find_project
    before_action :authorize # checks view_cost_reports for index/export

    menu_item :time_reports_cost

    def index
      @query      = build_query
      @entries    = @query.entries.order(spent_on: :desc)
      @calculator = CostCalculator.new(@entries.to_a, currency: currency)
      @total_cost = @calculator.total
      @total_hours = @query.total_hours
      @currency   = currency
    end

    # SECURITY: `authorize` (above, view_cost_reports) runs before this action
    # streams data — never remove the before_action.
    def export
      @query      = build_query
      entries     = @query.entries.to_a
      calculator  = CostCalculator.new(entries, currency: currency)
      csv = CsvExportService.new(entries, cost_calculator: calculator).call
      send_data csv,
                filename: "cost-report-#{@project.identifier}-#{Date.current.iso8601}.csv",
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    end

    def currency
      Setting.plugin_openproject_time_reports&.dig("default_currency") || "USD"
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
