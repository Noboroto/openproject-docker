# frozen_string_literal: true

module CustomFieldsPlus
  class FieldContract < Dry::Validation::Contract
    params do
      required(:name).filled(:string)
      required(:field_type).filled(:string)
      optional(:scope_project_ids).maybe(:array?)
      optional(:scope_group_ids).maybe(:array?)
    end

    rule(:field_type) do
      unless %w[multi_list hierarchy multi_user multi_version].include?(value)
        key.failure(:invalid)
      end
    end
  end
end
