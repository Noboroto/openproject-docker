# frozen_string_literal: true

module ActionBoards
  # A single column of an action board. `value_id` holds the target attribute
  # value the column represents (a status_id, user_id, or version_id depending on
  # the parent board's action_type). Dropping a card into this column updates the
  # work package to that value via ActionBoards::CardMover.
  class Column < ApplicationRecord
    self.table_name = "op_boards_columns"

    belongs_to :board, class_name: "ActionBoards::Board", inverse_of: :columns

    validates :title, presence: true
    validates :value_id, presence: true
    validates :position, numericality: { only_integer: true }

    scope :ordered, -> { order(:position) }
  end
end
