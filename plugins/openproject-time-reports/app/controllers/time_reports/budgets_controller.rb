# frozen_string_literal: true

module TimeReports
  # Per-project budget CRUD. Gated by `manage_budgets`.
  class BudgetsController < ::ApplicationController
    before_action :find_project
    before_action :authorize # checks manage_budgets
    before_action :find_budget, only: %i[edit update destroy]

    menu_item :time_reports_budgets

    def index
      @budgets    = Budget.where(project: @project).order(:name)
      @summaries  = @budgets.index_with { |b| BudgetSummary.new(b) }
    end

    def new
      @budget = Budget.new(project: @project, currency: default_currency)
    end

    def create
      @budget = Budget.new(budget_params.merge(project: @project))
      if @budget.save
        flash[:notice] = t(:"budget.saved")
        redirect_to action: :index
      else
        render :new
      end
    end

    def edit; end

    def update
      if @budget.update(budget_params)
        flash[:notice] = t(:"budget.saved")
        redirect_to action: :index
      else
        render :edit
      end
    end

    def destroy
      @budget.destroy
      flash[:notice] = t(:"budget.deleted")
      redirect_to action: :index
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    end

    def find_budget
      @budget = Budget.where(project: @project).find(params[:id])
    end

    def default_currency
      Setting.plugin_openproject_time_reports&.dig("default_currency") || "USD"
    end

    def budget_params
      params.require(:budget).permit(:name, :amount, :currency, :period_start, :period_end)
    end
  end
end
