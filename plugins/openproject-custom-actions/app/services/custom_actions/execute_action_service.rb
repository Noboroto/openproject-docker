# frozen_string_literal: true

module CustomActions
  # Applies a custom action's predefined attribute changes to a work package.
  #
  # The mutation is delegated to the core `WorkPackages::UpdateService` — never a
  # raw `update_column`/`update!` — so OpenProject's workflow rules, contracts and
  # permission checks all run. An illegal status transition (or any change the
  # acting user is not allowed to make) therefore fails the service contract and
  # the returned ServiceResult is `failure?` (the caller maps this to HTTP 422);
  # the work package is NOT changed. Applying can never escalate privileges.
  #
  # VERIFY against the running 17-slim image:
  #   - `WorkPackages::UpdateService.new(user:, model:).call(**attributes)` is the
  #     OP 17 signature; the returned ServiceResult exposes `success?`, `errors`
  #     and `result`. Confirm before relying on it.
  class ExecuteActionService
    # Raised when applicability is not met server-side (defends against a stale or
    # tampered client request). The controller maps this to HTTP 422.
    class NotApplicableError < StandardError; end

    def initialize(action:, work_package:, user:)
      @action = action
      @work_package = work_package
      @user = user
    end

    # Returns a WorkPackages::UpdateService ServiceResult.
    def call
      unless Applicability.new(@action, @work_package).met?
        raise NotApplicableError, "Custom action ##{@action.id} not applicable to WP ##{@work_package.id}"
      end

      WorkPackages::UpdateService
        .new(user: @user, model: @work_package)
        .call(**@action.change_attributes)
    end
  end
end
