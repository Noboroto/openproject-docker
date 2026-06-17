# frozen_string_literal: true

module DashboardsPlus
  # Plain presenter for the project-health KPI card + work-package status summary.
  class KpiWidget
    def initialize(project)
      @project = project
    end

    def health
      open_wps   = @project.work_packages.open.count
      closed_wps = @project.work_packages.closed.count
      overdue    = @project.work_packages.open.where("due_date < ?", Date.current).count
      { open: open_wps, closed: closed_wps, overdue: overdue }
    end

    # [[status_name, count], ...]
    def status_summary
      @project.work_packages
              .joins(:status)
              .group("statuses.name")
              .count
              .sort_by { |_name, count| -count }
    end
  end
end
