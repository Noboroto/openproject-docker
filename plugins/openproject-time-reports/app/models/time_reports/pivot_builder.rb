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
        wp = self.class.work_package_for(entry)
        wp_label  = wp ? "##{wp.id}" : "(no WP)"
        pivot[user_name][wp_label] += entry.hours.to_f
      end
      pivot
    end

    def all_work_packages
      @entries.filter_map { |e| (wp = self.class.work_package_for(e)) ? "##{wp.id}" : nil }
              .uniq
              .sort
    end

    # OP 17 time entries are polymorphic via `entity`; the work package is the
    # entity when entity_type == "WorkPackage".
    def self.work_package_for(entry)
      entry.entity if entry.respond_to?(:entity) && entry.entity_type == "WorkPackage"
    end
  end
end
