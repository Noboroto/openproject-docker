# frozen_string_literal: true

module ProjectTemplates
  # Marks an existing project as a reusable template. One row per source project
  # (unique project_id). The actual cloning is delegated to the core
  # Projects::CopyService — this model is just the template registry.
  class Template < ApplicationRecord
    self.table_name = "op_projtpl_templates"

    # The source project being cloned. `Project` is the core model.
    belongs_to :project

    validates :project_id, presence: true, uniqueness: true
    validates :name, presence: true, uniqueness: true

    # Convenience scope for the self-service gallery.
    scope :public_templates, -> { where(is_public: true) }

    # Number of work packages in the source project. Used by the size guard and
    # for display in the admin list / gallery card.
    #
    # VERIFY: `project.work_packages` association name on the running 17-slim
    # image (core Project has had this association for a long time).
    def work_package_count
      project.work_packages.count
    end
  end
end
