# frozen_string_literal: true

module CustomActions
  # Decides whether a custom action's `conditions` are met by a given work package.
  #
  # Conditions are AND-combined; an absent/blank condition key is ignored (matches
  # anything). This is a pure read-side check used both to decide which buttons to
  # render and — crucially — to RE-CHECK server-side before applying, so the client
  # is never trusted to assert applicability.
  class Applicability
    def initialize(action, work_package)
      @action = action
      @work_package = work_package
    end

    def met?
      status_matches? && type_matches?
    end

    private

    def conditions
      @action.conditions_config
    end

    def status_matches?
      expected = conditions["status_id"]
      return true if expected.blank?

      @work_package.status_id == expected.to_i
    end

    def type_matches?
      expected = Array(conditions["type_ids"]).compact_blank.map(&:to_i)
      return true if expected.empty?

      expected.include?(@work_package.type_id)
    end
  end
end
