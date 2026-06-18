# frozen_string_literal: true

module CustomFieldsPlus
  class FieldValue < ApplicationRecord
    self.table_name = "op_cfp_field_values"

    belongs_to :advanced_field
    belongs_to :work_package

    # value_ids stores selected option IDs (multi_list/hierarchy),
    # or user/version IDs for multi_user/multi_version.
    serialize :value_ids, type: Array

    validates :advanced_field_id, :work_package_id, presence: true
    validates :advanced_field_id, uniqueness: { scope: :work_package_id }
  end
end
