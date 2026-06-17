# frozen_string_literal: true

module ActionBoards
  # A project-scoped action board. The `action_type` decides which work-package
  # attribute each column maps to and which attribute a drop mutates:
  #
  #   "status"   -> work_package.status_id
  #   "assignee" -> work_package.assigned_to_id
  #   "version"  -> work_package.version_id
  class Board < ApplicationRecord
    self.table_name = "op_boards_boards"

    ACTION_TYPES = %w[status assignee version].freeze

    belongs_to :project

    has_many :columns,
             -> { order(:position) },
             class_name: "ActionBoards::Column",
             dependent: :destroy,
             inverse_of: :board

    validates :name, presence: true
    validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }

    # Work-package attribute (symbol) that this board groups cards by / mutates.
    def grouping_attribute
      case action_type
      when "status"   then :status_id
      when "assignee" then :assigned_to_id
      when "version"  then :version_id
      end
    end
  end
end
