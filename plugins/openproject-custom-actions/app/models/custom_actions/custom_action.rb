# frozen_string_literal: true

module CustomActions
  # A reusable, config-driven custom work-package action.
  #
  #   conditions -> when this action is applicable (matched against a work package)
  #     { "status_id" => 1, "type_ids" => [3, 4] }   # any key optional
  #
  #   changes -> the attributes a single click applies (passed verbatim to the
  #     core WorkPackages::UpdateService)
  #     { "status_id" => 7, "assigned_to_id" => 12, "priority_id" => 5 }
  #
  # Both are plain JSONB hashes so the action set is data-driven (no scripting).
  # Applicability and application are handled by CustomActions::Applicability and
  # CustomActions::ExecuteActionService respectively.
  class CustomAction < ApplicationRecord
    self.table_name = "op_cact_custom_actions"

    # Work-package attributes a custom action is allowed to change. Restricting the
    # whitelist here (in addition to the UpdateService contract) keeps actions from
    # ever targeting an unexpected attribute.
    CHANGEABLE_ATTRIBUTES = %w[status_id assigned_to_id priority_id].freeze

    # Condition keys understood by Applicability.
    CONDITION_KEYS = %w[status_id type_ids].freeze

    validates :name, presence: true
    validates :position, numericality: { only_integer: true }

    validate :changes_must_be_present
    validate :changes_keys_must_be_allowed

    scope :ordered, -> { order(:position, :id) }

    # Symbolized attribute hash, filtered to the whitelist, ready for the core
    # update service.
    def change_attributes
      changes_config
        .slice(*CHANGEABLE_ATTRIBUTES)
        .transform_keys(&:to_sym)
        .transform_values { |v| v.blank? ? nil : v.to_i }
    end

    # The raw conditions hash (string keys), guarding against a nil column.
    def conditions_config
      conditions.is_a?(Hash) ? conditions : {}
    end

    # The raw changes hash (string keys), guarding against a nil column.
    # `changes` is reserved by ActiveModel::Dirty, so the column is named
    # `change_set` and exposed here.
    def changes_config
      change_set.is_a?(Hash) ? change_set : {}
    end

    private

    def changes_must_be_present
      return if change_attributes.any?

      errors.add(:base, I18n.t(:"custom_actions.errors.no_changes"))
    end

    def changes_keys_must_be_allowed
      extra = changes_config.keys.map(&:to_s) - CHANGEABLE_ATTRIBUTES
      return if extra.empty?

      errors.add(:base, I18n.t(:"custom_actions.errors.illegal_change_keys", keys: extra.join(", ")))
    end
  end
end
