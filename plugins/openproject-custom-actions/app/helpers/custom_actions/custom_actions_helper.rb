# frozen_string_literal: true

module CustomActions
  module CustomActionsHelper
    # Custom actions applicable to the given work package, in display order. Used to
    # render the one-click buttons; the server re-checks applicability + permissions
    # on apply.
    def applicable_custom_actions(work_package)
      CustomAction.ordered.select do |action|
        Applicability.new(action, work_package).met?
      end
    end

    # True when the current user may apply custom actions in the given project.
    # VERIFY the permission-check method name against the running 17-slim image:
    # recent OpenProject uses `User#allowed_in_project?`, older uses `allowed_to?`.
    def can_execute_custom_actions?(project)
      if User.current.respond_to?(:allowed_in_project?)
        User.current.allowed_in_project?(:execute_custom_actions, project)
      else
        User.current.allowed_to?(:execute_custom_actions, project)
      end
    end
  end
end
