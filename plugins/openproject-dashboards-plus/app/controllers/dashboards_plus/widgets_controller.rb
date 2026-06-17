# frozen_string_literal: true

module DashboardsPlus
  # Server-rendered dashboard widgets for a project.
  class WidgetsController < ::ApplicationController
    before_action :find_project
    before_action :authorize # view_dashboards_plus_widgets

    menu_item :dashboards_plus

    def show
      @kpi    = KpiWidget.new(@project)
      @budget = BudgetWidget.new(@project)
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    end
  end
end
