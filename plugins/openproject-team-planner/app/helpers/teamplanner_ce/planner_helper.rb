# frozen_string_literal: true

module TeamplannerCe
  module PlannerHelper
    # True when the current user may save/delete planner views in the project.
    # VERIFY the permission-check method name against the running 17-slim image:
    # recent OpenProject uses `User#allowed_in_project?`, older `User#allowed_to?`.
    def can_manage_teamplanner_ce_views?(project)
      if User.current.respond_to?(:allowed_in_project?)
        User.current.allowed_in_project?(:manage_teamplanner_ce_views, project)
      else
        User.current.allowed_to?(:manage_teamplanner_ce_views, project)
      end
    end

    # Human label for a work-package bar, e.g. "#123 Fix login".
    def planner_card_label(work_package)
      "##{work_package.id} #{work_package.subject}"
    end

    def planner_assignee_name(assignee)
      assignee&.name || t(:"teamplanner_ce.label_unassigned")
    end
  end
end
