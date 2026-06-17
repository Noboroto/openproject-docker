# frozen_string_literal: true

module TimeReports
  # Computes monetary cost for a collection of TimeEntry records as
  # `sum(hours * effective_rate)`.
  #
  # Effective-rate selection rule (kept deliberately simple, see plan §5):
  #   1. restrict to rates for the entry's project with valid_from <= spent_on;
  #   2. prefer a user-specific rate (user_id == entry.user_id);
  #   3. otherwise fall back to a project-wide rate (user_id IS NULL);
  #   4. within each group, pick the latest valid_from;
  #   5. when both exist for the same valid_from, the user-specific rate wins.
  #   6. an activity-specific rate (activity_id == entry.activity_id) is
  #      preferred over an activity-agnostic one at the same precedence level.
  #
  # Rates are cached per (project_id, user_id, activity_id, spent_on) within a
  # single calculator instance to avoid an N+1 across many entries.
  class CostCalculator
    def initialize(entries, currency: nil)
      @entries  = entries
      @currency = currency
      @cache    = {}
    end

    # Total cost across all entries.
    def total
      @entries.sum { |entry| line_cost(entry) }
    end

    # Cost of a single entry (hours * effective rate).
    def line_cost(entry)
      entry.hours.to_f * rate_for(entry)
    end

    # Effective hourly rate for a single entry (0.0 when no rate is configured).
    def rate_for(entry)
      key = [entry.project_id, entry.user_id, entry.activity_id, entry.spent_on]
      @cache[key] ||= compute_rate_for(entry)
    end

    private

    def compute_rate_for(entry)
      candidates = CostRate
                   .where(project_id: entry.project_id)
                   .effective_on(entry.spent_on)
                   .where("user_id = ? OR user_id IS NULL", entry.user_id)
                   .where("activity_id = ? OR activity_id IS NULL", entry.activity_id)
                   .to_a

      best = candidates.max_by { |r| sort_key(r, entry) }
      best&.rate.to_f
    end

    # Higher sort key = preferred. Ordered by:
    #   user-specific (1/0), then activity-specific (1/0), then valid_from.
    def sort_key(rate, entry)
      [
        rate.user_id == entry.user_id ? 1 : 0,
        rate.activity_id.present? ? 1 : 0,
        rate.valid_from
      ]
    end
  end
end
