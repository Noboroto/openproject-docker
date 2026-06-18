# frozen_string_literal: true

module Baselines
  class Baseline < ApplicationRecord
    self.table_name = "op_baselines"

    belongs_to :project
    belongs_to :author, class_name: "User"

    validates :name, :captured_at, :project, :author, presence: true
    validates :name, length: { maximum: 255 }

    scope :for_project, ->(project) { where(project: project).order(captured_at: :desc) }
  end
end
