# frozen_string_literal: true

module TimeReports
  # Builds a pivot table (rows = users, columns = work packages, cells = hours)
  # from a collection of TimeEntry records.
  class PivotBuilder
    def initialize(entries)
      @entries = entries
    end

    # Returns { user_name => { wp_label => hours } }
    def build
      pivot = Hash.new { |h, k| h[k] = Hash.new(0.0) }
      @entries.each do |entry|
        user_name = entry.user&.name || "(unknown)"
        wp_label  = entry.work_package ? "##{entry.work_package.id}" : "(no WP)"
        pivot[user_name][wp_label] += entry.hours.to_f
      end
      pivot
    end

    def all_work_packages
      @entries.filter_map { |e| e.work_package ? "##{e.work_package.id}" : nil }
              .uniq
              .sort
    end
  end
end
