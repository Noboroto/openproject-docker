# frozen_string_literal: true

module TeamplannerCe
  # Read-only query: returns the project's visible, assigned work packages that
  # overlap the [from, to] window, grouped by assignee.
  #
  # SECURITY: scoped through `WorkPackage.visible(user)` (mandatory) so a user
  # never sees a card they cannot read. The project filter is applied on top.
  # VERIFY the `.visible(user)` scope name against the running 17-slim image.
  class AssignmentQuery
    def initialize(project:, user:, from:, to:, assignee_ids: nil)
      @project = project
      @user = user
      @from = from
      @to = to
      @assignee_ids = Array(assignee_ids).reject(&:blank?).map(&:to_i)
    end

    # @return [Hash{User => Array<WorkPackage>}] ordered by assignee name.
    def rows
      scoped.group_by(&:assigned_to)
            .sort_by { |assignee, _| assignee&.name.to_s }
            .to_h
    end

    # Distinct assignees who have any work package in the window (for the row axis
    # / filter UI). `.reorder(nil)` clears the default ORDER BY before DISTINCT to
    # avoid PG ordering/grouping conflicts.
    def assignees
      rows.keys.compact
    end

    private

    def scoped
      scope = WorkPackage.visible(@user)
                         .where(project: @project)
                         .where.not(assigned_to_id: nil)
                         # Overlap test: the WP's [start, due] interval intersects
                         # the requested [from, to] window. COALESCE handles WPs
                         # with only one of the two dates set.
                         .where("COALESCE(due_date, start_date) >= ?", @from)
                         .where("COALESCE(start_date, due_date) <= ?", @to)
                         .includes(:assigned_to, :type, :status)
                         # Clear core's default created_at ORDER BY so any later
                         # grouping/count never trips PG::GroupingError.
                         .reorder(nil)
      scope = scope.where(assigned_to_id: @assignee_ids) if @assignee_ids.present?
      scope
    end
  end
end
