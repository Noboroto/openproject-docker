# frozen_string_literal: true

module ActionBoards
  # Handles a card drop: PATCH a work package into a target column.
  #
  # Requires :manage_action_boards (mapped in the engine). The move ALWAYS goes
  # through ActionBoards::CardMover -> WorkPackages::UpdateService, so an illegal
  # status transition (or any contract/permission failure) returns HTTP 422 and
  # leaves the work package unchanged. Authorization is server-side only; the
  # client is never trusted to assert a move is allowed.
  class CardMovesController < ::ApplicationController
    before_action :find_project
    before_action :authorize
    before_action :find_board
    before_action :find_work_package
    before_action :find_target_column

    def update
      result = CardMover.new(board: @board,
                             work_package: @work_package,
                             target_column: @target_column,
                             user: current_user).call

      if result.success?
        render json: { id: @work_package.id, column_id: @target_column.id }, status: :ok
      else
        render json: { errors: result.errors.full_messages },
               status: :unprocessable_entity
      end
    end

    private

    def find_board
      @board = ActionBoards::Board.where(project: @project).find(params[:board_id])
    end

    # Visible scope: a user can only move a work package they are allowed to see.
    def find_work_package
      @work_package = @project.work_packages
                              .visible(current_user)
                              .find(params[:work_package_id])
    end

    # Validate the drop target belongs to this board (never trust the client).
    def find_target_column
      @target_column = @board.columns.find(params[:column_id])
    end

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
