# frozen_string_literal: true

require "spec_helper"

# Verifies that CardMover applies the correct attribute per action_type and that
# it routes through WorkPackages::UpdateService (so workflow rules apply). Uses
# OpenProject's core factories.
RSpec.describe ActionBoards::CardMover, type: :model do
  let(:project) { create(:project) }
  let(:user) { create(:admin) }

  describe "#call attribute mapping" do
    it "sets status_id for a status board" do
      board = ActionBoards::Board.create!(project:, name: "S", action_type: "status")
      target_status = create(:status)
      column = board.columns.create!(title: target_status.name, value_id: target_status.id, position: 0)
      work_package = create(:work_package, project:)

      service = instance_double(WorkPackages::UpdateService)
      allow(WorkPackages::UpdateService).to receive(:new).with(user:, model: work_package).and_return(service)
      expect(service).to receive(:call).with(status_id: target_status.id)

      described_class.new(board:, work_package:, target_column: column, user:).call
    end

    it "sets assigned_to_id for an assignee board" do
      board = ActionBoards::Board.create!(project:, name: "A", action_type: "assignee")
      assignee = create(:user)
      column = board.columns.create!(title: assignee.name, value_id: assignee.id, position: 0)
      work_package = create(:work_package, project:)

      service = instance_double(WorkPackages::UpdateService)
      allow(WorkPackages::UpdateService).to receive(:new).and_return(service)
      expect(service).to receive(:call).with(assigned_to_id: assignee.id)

      described_class.new(board:, work_package:, target_column: column, user:).call
    end

    it "sets version_id for a version board" do
      board = ActionBoards::Board.create!(project:, name: "V", action_type: "version")
      version = create(:version, project:)
      column = board.columns.create!(title: version.name, value_id: version.id, position: 0)
      work_package = create(:work_package, project:)

      service = instance_double(WorkPackages::UpdateService)
      allow(WorkPackages::UpdateService).to receive(:new).and_return(service)
      expect(service).to receive(:call).with(version_id: version.id)

      described_class.new(board:, work_package:, target_column: column, user:).call
    end
  end

  describe "#call against the real UpdateService" do
    it "rejects an illegal status transition (no workflow) -> failure result" do
      # No workflow rows are created, so a transition to a different status is
      # illegal and the core contract rejects it.
      role = create(:project_role, permissions: %i[edit_work_packages view_work_packages])
      member = create(:user, member_with_roles: { project => role })
      type = create(:type)
      project.types << type unless project.types.include?(type)

      from_status = create(:status)
      to_status = create(:status)
      work_package = create(:work_package, project:, type:, status: from_status, author: member)

      board = ActionBoards::Board.create!(project:, name: "S", action_type: "status")
      column = board.columns.create!(title: to_status.name, value_id: to_status.id, position: 0)

      result = described_class.new(board:, work_package:, target_column: column, user: member).call

      expect(result).to be_failure
      expect(work_package.reload.status_id).to eq(from_status.id)
    end
  end
end
