# frozen_string_literal: true

OpenProject::Application.routes.draw do
  scope "projects/:project_id", as: "project" do
    resources :action_boards,
              controller: "action_boards/boards",
              only: %i[index show new create destroy]

    # Card drop endpoint. column_id + work_package_id are supplied in the body by
    # the drag-drop controller (Stimulus). Maps to action_boards/card_moves#update,
    # which the engine guards with :manage_action_boards.
    patch "action_boards/:board_id/move",
          to: "action_boards/card_moves#update",
          as: :action_board_move_card
  end
end
