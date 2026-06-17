# frozen_string_literal: true

require "spec_helper"

# Request specs for the board + card-move endpoints. Relies on OpenProject's core
# spec harness (`login_as`, FactoryBot factories, `member_with_permissions`).
#
# NOTE: factory names and permission-helper keywords (`member_with_permissions`,
# `:project_role`) follow current OpenProject conventions — VERIFY against the
# running 17-slim image's spec factories.
RSpec.describe "Action boards card moves", type: :request do
  let(:project) do
    create(:project, enabled_module_names: %w[work_package_tracking action_boards])
  end
  let(:board) { ActionBoards::Board.create!(project:, name: "Status", action_type: "status") }

  let(:viewer) do
    create(:user, member_with_permissions: { project => %i[view_action_boards view_work_packages] })
  end
  let(:mover) do
    create(:user, member_with_permissions: {
             project => %i[view_action_boards manage_action_boards
                           view_work_packages edit_work_packages]
           })
  end

  describe "GET index/show (view permission)" do
    it "lists boards for a user with view_action_boards" do
      board
      login_as viewer
      get project_action_boards_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Status")
    end

    it "shows a board" do
      column = board.columns.create!(title: "Open", value_id: create(:status).id, position: 0)
      login_as viewer
      get project_action_board_path(project, board)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(column.title)
    end
  end

  describe "PATCH move" do
    it "denies a user lacking manage_action_boards (403)" do
      to_status = create(:status)
      column = board.columns.create!(title: to_status.name, value_id: to_status.id, position: 0)
      wp = create(:work_package, project:)

      login_as viewer
      patch action_board_move_card_path(project, board_id: board.id),
            params: { column_id: column.id, work_package_id: wp.id }

      expect(response).to have_http_status(:forbidden)
    end

    it "applies a legal move via UpdateService (200)" do
      type = create(:type)
      project.types << type unless project.types.include?(type)
      from_status = create(:status)
      to_status = create(:status)
      # Workflow row makes the transition legal for the mover's role.
      role = mover.members.first.roles.first
      create(:workflow, role:, type:, old_status: from_status, new_status: to_status)

      wp = create(:work_package, project:, type:, status: from_status)
      column = board.columns.create!(title: to_status.name, value_id: to_status.id, position: 0)

      login_as mover
      patch action_board_move_card_path(project, board_id: board.id),
            params: { column_id: column.id, work_package_id: wp.id }

      expect(response).to have_http_status(:ok)
      expect(wp.reload.status_id).to eq(to_status.id)
    end

    it "returns 422 and leaves the card on an illegal status transition" do
      type = create(:type)
      project.types << type unless project.types.include?(type)
      from_status = create(:status)
      to_status = create(:status) # no workflow row -> illegal transition

      wp = create(:work_package, project:, type:, status: from_status)
      column = board.columns.create!(title: to_status.name, value_id: to_status.id, position: 0)

      login_as mover
      patch action_board_move_card_path(project, board_id: board.id),
            params: { column_id: column.id, work_package_id: wp.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(wp.reload.status_id).to eq(from_status.id)
    end
  end
end
