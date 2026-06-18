# frozen_string_literal: true

module DashboardsPlus
  # Plain presenter for the project-health KPI card + work-package status summary.
  class KpiWidget
    def initialize(project)
      @project = project
    end

    def health
      # NB: there is no `.open`/`.closed` scope on WorkPackage (`open` would
      # resolve to private Kernel#open). Derive from the status is_closed flag.
      open_scope   = @project.work_packages.joins(:status).where(statuses: { is_closed: false })
      closed_scope = @project.work_packages.joins(:status).where(statuses: { is_closed: true })
      {
        open: open_scope.count,
        closed: closed_scope.count,
        overdue: open_scope.where("due_date < ?", Date.current).count
      }
    end

    # [[status_name, count], ...]
    def status_summary
      @project.work_packages
              .reorder(nil) # drop default ORDER BY created_at (breaks GROUP BY)
              .joins(:status)
              .group("statuses.name")
              .count
              .sort_by { |_name, count| -count }
    end
  end
end
