# frozen_string_literal: true

module TeamplannerCe
  # Per-user, per-project saved planner preferences (date range + assignee filter).
  # Stored in the namespaced op_teamplanner_ce_saved_views table. Destroy is guarded
  # in the controller by `user_id == User.current.id` so a user can only delete
  # their own views.
  class SavedView < ApplicationRecord
    self.table_name = "op_teamplanner_ce_saved_views"

    belongs_to :project
    belongs_to :user

    validates :name, presence: true

    # filters is a jsonb hash: { "from" => ..., "to" => ..., "assignee_ids" => [...] }
    def from_date
      Date.parse(filters["from"]) if filters["from"].present?
    rescue ArgumentError, TypeError
      nil
    end

    def to_date
      Date.parse(filters["to"]) if filters["to"].present?
    rescue ArgumentError, TypeError
      nil
    end

    def assignee_ids
      Array(filters["assignee_ids"]).map(&:to_i)
    end
  end
end
