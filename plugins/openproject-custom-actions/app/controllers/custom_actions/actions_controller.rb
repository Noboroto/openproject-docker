# frozen_string_literal: true

module CustomActions
  # Admin-only management of the custom-action catalog (definitions: conditions +
  # changes). Guarded by `require_admin`, which satisfies OpenProject's zero-trust
  # "auth check required on every action" rule for this global, non-project screen.
  class ActionsController < ::ApplicationController
    before_action :require_admin
    before_action :find_action, only: %i[edit update destroy]

    layout "admin"
    menu_item :custom_actions

    def index
      @actions = CustomAction.ordered.to_a
    end

    def new
      @action = CustomAction.new(position: next_position)
    end

    def create
      @action = CustomAction.new(action_params)
      if @action.save
        flash[:notice] = t(:"custom_actions.flash.created")
        redirect_to custom_actions_actions_path
      else
        flash.now[:error] = @action.errors.full_messages.to_sentence
        render :new
      end
    end

    def edit; end

    def update
      if @action.update(action_params)
        flash[:notice] = t(:"custom_actions.flash.updated")
        redirect_to custom_actions_actions_path
      else
        flash.now[:error] = @action.errors.full_messages.to_sentence
        render :edit
      end
    end

    def destroy
      @action.destroy
      flash[:notice] = t(:"custom_actions.flash.deleted")
      redirect_to custom_actions_actions_path
    end

    private

    def find_action
      @action = CustomAction.find(params[:id])
    end

    def next_position
      (CustomAction.maximum(:position) || 0) + 1
    end

    # Builds the JSONB `conditions` / `change_set` hashes from flat form fields.
    # Blank values are dropped so a condition/change key only exists when set.
    def action_params
      raw = params.require(:custom_action)
                  .permit(:name, :position,
                          :condition_status_id, :condition_type_ids,
                          :change_status_id, :change_assigned_to_id, :change_priority_id)

      {
        name: raw[:name],
        position: raw[:position].presence || next_position,
        conditions: build_conditions(raw),
        change_set: build_changes(raw)
      }
    end

    def build_conditions(raw)
      conditions = {}
      conditions["status_id"] = raw[:condition_status_id].to_i if raw[:condition_status_id].present?
      if raw[:condition_type_ids].present?
        conditions["type_ids"] = raw[:condition_type_ids].to_s.split(",").map { |s| s.strip.to_i }.reject(&:zero?)
      end
      conditions
    end

    def build_changes(raw)
      changes = {}
      changes["status_id"] = raw[:change_status_id].to_i if raw[:change_status_id].present?
      changes["assigned_to_id"] = raw[:change_assigned_to_id].to_i if raw[:change_assigned_to_id].present?
      changes["priority_id"] = raw[:change_priority_id].to_i if raw[:change_priority_id].present?
      changes
    end
  end
end
