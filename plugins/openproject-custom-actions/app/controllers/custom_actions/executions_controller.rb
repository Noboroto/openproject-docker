# frozen_string_literal: true

module CustomActions
  # Applies a custom action to a single work package within a project.
  #
  # Requires :execute_custom_actions (mapped in the engine, permissible_on:
  # :project). `find_project` + `authorize` satisfy OpenProject's per-action auth
  # check and infer the permission from controller/action + @project. The actual
  # change ALWAYS goes through CustomActions::ExecuteActionService ->
  # WorkPackages::UpdateService, so an illegal status transition (or any change the
  # acting user is not allowed to make) returns HTTP 422 and leaves the work
  # package unchanged. Applicability is RE-CHECKED server-side — the client is
  # never trusted.
  class ExecutionsController < ::ApplicationController
    before_action :find_project
    before_action :authorize
    before_action :find_work_package
    before_action :find_action

    def create
      result = ExecuteActionService.new(action: @action,
                                        work_package: @work_package,
                                        user: current_user).call

      if result.success?
        respond_to do |format|
          format.html do
            flash[:notice] = t(:"custom_actions.flash.applied")
            redirect_back fallback_location: work_package_path(@work_package)
          end
          format.json { render json: { id: @work_package.id }, status: :ok }
        end
      else
        render_failure(result.errors.full_messages)
      end
    rescue ExecuteActionService::NotApplicableError
      render_failure([t(:"custom_actions.errors.not_applicable")])
    end

    private

    def render_failure(messages)
      respond_to do |format|
        format.html do
          flash[:error] = messages.to_sentence.presence || t(:"custom_actions.errors.apply_failed")
          redirect_back fallback_location: work_package_path(@work_package)
        end
        format.json { render json: { errors: messages }, status: :unprocessable_entity }
      end
    end

    # IDOR-safe: a user can only act on a work package they may see, scoped to the
    # routed project.
    # VERIFY: the `.visible(user)` scope name against the running 17-slim image.
    def find_work_package
      @work_package = @project.work_packages
                              .visible(current_user)
                              .find(params[:work_package_id])
    end

    # Catalog actions are global; load by id (no project scoping on the definition).
    def find_action
      @action = CustomAction.find(params[:action_id])
    end

    # @project is required by OpenProject's `authorize`.
    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
