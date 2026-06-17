# frozen_string_literal: true

module ActionBoards
  # Applies the action of dropping a card into a target column.
  #
  # The mutation is delegated to the core `WorkPackages::UpdateService` — never a
  # raw `update_column`/`update!` — so OpenProject's workflow rules, contracts and
  # permission checks all run. An illegal status transition therefore fails the
  # service contract and the returned ServiceResult is `failure?` (the caller maps
  # this to HTTP 422); the work package is NOT changed.
  #
  # VERIFY against the running 17-slim image:
  #   - `WorkPackages::UpdateService.new(user:, model:).call(**attributes)` is the
  #     OP 17 signature; the returned ServiceResult exposes `success?`, `errors`
  #     and `result`. Confirm before relying on it.
  class CardMover
    def initialize(board:, work_package:, target_column:, user:)
      @board = board
      @work_package = work_package
      @target_column = target_column
      @user = user
    end

    # Returns a WorkPackages::UpdateService ServiceResult.
    def call
      WorkPackages::UpdateService
        .new(user: @user, model: @work_package)
        .call(**target_attributes)
    end

    private

    # Maps the board's action_type to the work-package attribute to set, using the
    # target column's value_id. assigned_to_id / version_id may legitimately be
    # nil (an "unassigned" / "no version" column would store that).
    def target_attributes
      case @board.action_type
      when "status"   then { status_id: @target_column.value_id }
      when "assignee" then { assigned_to_id: @target_column.value_id }
      when "version"  then { version_id: @target_column.value_id }
      else
        raise ArgumentError, "Unknown board action_type: #{@board.action_type.inspect}"
      end
    end
  end
end
