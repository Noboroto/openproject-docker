# frozen_string_literal: true

module CustomFieldsPlus
  class AdvancedField < ApplicationRecord
    self.table_name = "op_cfp_advanced_fields"

    # field_type: multi_list, hierarchy, multi_user, multi_version
    enum :field_type, { multi_list: 0, hierarchy: 1, multi_user: 2, multi_version: 3 }

    has_many :field_options, -> { order(:position) }, dependent: :destroy
    has_many :field_values, dependent: :destroy

    serialize :scope_project_ids, type: Array
    serialize :scope_group_ids,   type: Array

    validates :name, :field_type, presence: true
    validates :name, uniqueness: { case_sensitive: false }
    validate  :scope_project_ids_is_array
    validate  :scope_group_ids_is_array

    private

    def scope_project_ids_is_array
      errors.add(:scope_project_ids, :invalid) unless scope_project_ids.is_a?(Array)
    end

    def scope_group_ids_is_array
      errors.add(:scope_group_ids, :invalid) unless scope_group_ids.is_a?(Array)
    end
  end
end
