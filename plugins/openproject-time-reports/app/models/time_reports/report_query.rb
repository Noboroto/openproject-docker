# frozen_string_literal: true

module TimeReports
  # Plain query object (not an AR model) wrapping the core `TimeEntry` scope used
  # by both the time report and the cost report.
  class ReportQuery
    attr_reader :project, :from_date, :to_date, :user_ids

    def initialize(project:, from_date:, to_date:, user_ids: [])
      @project   = project
      @from_date = from_date
      @to_date   = to_date
      @user_ids  = Array(user_ids).reject(&:blank?)
    end

    def entries
      scope = ::TimeEntry
              .where(project: @project)
              .where(spent_on: @from_date..@to_date)
              .includes(:user, :work_package, :activity)

      scope = scope.where(user_id: @user_ids) if @user_ids.present?
      scope
    end

    def total_hours
      entries.sum(:hours)
    end
  end
end
