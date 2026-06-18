# frozen_string_literal: true

module TeamplannerCe
  # Project-scoped, read-only resource calendar.
  #
  # `show` requires :view_teamplanner_ce; `save`/`destroy` require
  # :manage_teamplanner_ce_views. The mapping lives in the engine's permission block
  # and is enforced by OpenProject's `authorize` before_action (which infers the
  # permission from controller_name/action_name and the current @project).
  class PlannerController < ::ApplicationController
    before_action :find_project
    before_action :authorize

    menu_item :teamplanner_ce

    DEFAULT_WINDOW_DAYS = 27 # ~4 weeks inclusive

    def show
      @from, @to = date_range
      @assignee_ids = Array(params[:assignee_ids]).reject(&:blank?)

      query = AssignmentQuery.new(project: @project,
                                  user: current_user,
                                  from: @from,
                                  to: @to,
                                  assignee_ids: @assignee_ids)
      @grid = AssignmentGrid.new(from: @from, to: @to, rows: query.rows)
      @saved_views = saved_views_scope.order(:name)
    end

    # Persist the current date range + assignee filter as a per-user saved view.
    def save
      from, to = date_range
      view = saved_views_scope.new(
        name: params[:name].presence || default_view_name(from, to),
        filters: {
          "from" => from.iso8601,
          "to" => to.iso8601,
          "assignee_ids" => Array(params[:assignee_ids]).reject(&:blank?)
        }
      )
      if view.save
        flash[:notice] = t(:"teamplanner_ce.flash.view_saved")
      else
        flash[:error] = view.errors.full_messages.to_sentence
      end
      redirect_to project_teamplanner_ce_path(@project)
    end

    def destroy
      # IDOR + ownership: only the current user's own views are in scope.
      view = saved_views_scope.find(params[:id])
      view.destroy
      flash[:notice] = t(:"teamplanner_ce.flash.view_deleted")
      redirect_to project_teamplanner_ce_path(@project)
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    private

    # Saved views are scoped to BOTH the project AND the current user, so a user
    # can only ever read or destroy their own views (satisfies the
    # "view.user_id == User.current.id" rule by construction).
    def saved_views_scope
      SavedView.where(project: @project, user: current_user)
    end

    def date_range
      from = parse_date(params[:from]) || Date.current
      to   = parse_date(params[:to])   || (from + DEFAULT_WINDOW_DAYS)
      to = from if to < from
      [from, to]
    end

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError
      nil
    end

    def default_view_name(from, to)
      "#{from.iso8601} – #{to.iso8601}"
    end

    # @project is required by OpenProject's `authorize`. Resolved explicitly from
    # the routed :project_id to avoid depending on a version-specific helper.
    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
