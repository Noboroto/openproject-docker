# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness / FactoryBot factories (`create(:project)`).
RSpec.describe ActionBoards::Board, type: :model do
  let(:project) { create(:project) }

  describe "validations" do
    it "is valid with a name and a known action_type" do
      board = described_class.new(project:, name: "Sprint", action_type: "status")
      expect(board).to be_valid
    end

    it "requires a name" do
      board = described_class.new(project:, name: nil, action_type: "status")
      expect(board).not_to be_valid
      expect(board.errors[:name]).to be_present
    end

    it "requires a known action_type" do
      board = described_class.new(project:, name: "Sprint", action_type: "bogus")
      expect(board).not_to be_valid
      expect(board.errors[:action_type]).to be_present
    end

    it "accepts each supported action_type" do
      ActionBoards::Board::ACTION_TYPES.each do |type|
        board = described_class.new(project:, name: "B-#{type}", action_type: type)
        expect(board).to be_valid, "expected #{type} to be valid"
      end
    end
  end

  describe "#grouping_attribute" do
    it "maps action_type to the work-package attribute" do
      expect(described_class.new(action_type: "status").grouping_attribute).to eq(:status_id)
      expect(described_class.new(action_type: "assignee").grouping_attribute).to eq(:assigned_to_id)
      expect(described_class.new(action_type: "version").grouping_attribute).to eq(:version_id)
    end
  end

  describe "columns" do
    it "returns columns ordered by position" do
      board = described_class.create!(project:, name: "Sprint", action_type: "status")
      board.columns.create!(title: "C", value_id: 3, position: 2)
      board.columns.create!(title: "A", value_id: 1, position: 0)
      board.columns.create!(title: "B", value_id: 2, position: 1)

      expect(board.columns.reload.map(&:title)).to eq(%w[A B C])
    end

    it "destroys columns with the board" do
      board = described_class.create!(project:, name: "Sprint", action_type: "status")
      board.columns.create!(title: "A", value_id: 1, position: 0)

      expect { board.destroy }.to change(ActionBoards::Column, :count).by(-1)
    end
  end
end
