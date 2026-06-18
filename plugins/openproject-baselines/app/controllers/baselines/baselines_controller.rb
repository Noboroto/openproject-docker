# frozen_string_literal: true

module Baselines
  class BaselinesController < ::ApplicationController
    before_action :find_project_by_project_id
    before_action :require_feature_enabled
    before_action :authorize
    before_action :find_baseline, only: %i[show destroy]

    menu_item :baselines

    def index
      @baselines = Baseline.for_project(@project)
    end

    def show
      @diff = DiffService.new(@baseline, User.current).call
    end

    def new
      @baseline = Baseline.new
    end

    def create
      @baseline = Baseline.new(baseline_params)
      @baseline.project = @project
      @baseline.author  = User.current

      if @baseline.save
        redirect_to baselines_path(@project),
                    notice: t("baselines.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @baseline.destroy
      redirect_to baselines_path(@project),
                  notice: t("baselines.flash.destroyed")
    end

    private

    def require_feature_enabled
      render_404 unless OpenProject::Baselines.feature_enabled?
    end

    def find_baseline
      @baseline = Baseline.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def baseline_params
      params.require(:baseline).permit(:name, :captured_at)
    end
  end
end
