# frozen_string_literal: true

module CustomFieldsPlus
  # Persists an advanced field value for a work package.
  # Returns { ok: true } or { ok: false, errors: [...] }.
  class ValueWriterService
    def initialize(work_package, field, value_ids, user)
      @work_package = work_package
      @field        = field
      @value_ids    = Array(value_ids).map(&:to_i)
      @user         = user
    end

    def call
      record = FieldValue.find_or_initialize_by(
        advanced_field: @field,
        work_package:   @work_package
      )
      record.value_ids = @value_ids

      if record.save
        { ok: true }
      else
        { ok: false, errors: record.errors.full_messages }
      end
    end
  end
end
