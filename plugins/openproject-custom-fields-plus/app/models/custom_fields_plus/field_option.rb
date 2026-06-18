# frozen_string_literal: true

module CustomFieldsPlus
  class FieldOption < ApplicationRecord
    self.table_name = "op_cfp_field_options"

    belongs_to :advanced_field
    belongs_to :parent, class_name: "CustomFieldsPlus::FieldOption", optional: true
    has_many   :children, class_name: "CustomFieldsPlus::FieldOption",
               foreign_key: :parent_id, dependent: :nullify

    validates :label, presence: true
    validate  :no_cycle

    def descendants
      result = []
      queue = children.to_a
      while queue.any?
        node = queue.shift
        result << node
        queue.concat(node.children.to_a)
      end
      result
    end

    private

    def no_cycle
      return unless parent_id.present? && persisted?

      if parent_id == id || ancestor_ids.include?(id)
        errors.add(:parent_id, :cycle)
      end
    end

    def ancestor_ids
      ids = []
      current = parent
      while current
        ids << current.id
        current = current.parent
      end
      ids
    end
  end
end
