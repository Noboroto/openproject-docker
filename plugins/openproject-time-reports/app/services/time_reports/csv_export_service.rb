# frozen_string_literal: true

require "csv"

module TimeReports
  # Generates CSV output for time entries. When `cost_calculator` is supplied,
  # two extra columns (Rate, Cost) are appended — used by the cost report export.
  #
  # NOTE: callers MUST authorize before invoking/streaming this output. The
  # controllers run `before_action :authorize` against `view_time_reports` /
  # `view_cost_reports` before calling `send_data`.
  class CsvExportService
    def initialize(entries, cost_calculator: nil)
      @entries         = entries
      @cost_calculator = cost_calculator
    end

    def call
      CSV.generate(headers: true) do |csv|
        csv << headers
        @entries.each { |e| csv << row(e) }
      end
    end

    private

    def headers
      base = %w[Date User WorkPackage Activity Hours Comment]
      base + (with_cost? ? %w[Rate Cost] : [])
    end

    def row(entry)
      base = [
        entry.spent_on&.iso8601,
        entry.user&.name,
        (PivotBuilder.work_package_for(entry)&.subject || ""),
        entry.activity&.name,
        entry.hours,
        entry.comments.to_s.truncate(200)
      ]
      return base unless with_cost?

      base + [
        format("%.2f", @cost_calculator.rate_for(entry)),
        format("%.2f", @cost_calculator.line_cost(entry))
      ]
    end

    def with_cost?
      @cost_calculator.present?
    end
  end
end
