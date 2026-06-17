# frozen_string_literal: true

module ActionBoards
  module BoardsHelper
    # True when the current user may create/delete boards and move cards in the
    # given project. VERIFY the permission-check method name against the running
    # 17-slim image: recent OpenProject uses `User#allowed_in_project?`, older
    # releases use `User#allowed_to?`.
    def can_manage_action_boards?(project)
      if User.current.respond_to?(:allowed_in_project?)
        User.current.allowed_in_project?(:manage_action_boards, project)
      else
        User.current.allowed_to?(:manage_action_boards, project)
      end
    end

    # Human label for a card, e.g. "#123 Fix login".
    def card_label(work_package)
      "##{work_package.id} #{work_package.subject}"
    end
  end
end
