# frozen_string_literal: true

module Baselines
  # Returns WP attribute snapshot from core journals at-or-before a timestamp.
  # Read-only — never writes to journals.
  class SnapshotResolverService
    TRACKED_ATTRS = %w[subject status_id assigned_to_id due_date start_date done_ratio].freeze

    def attributes_at(work_package, at)
      journal = work_package.journals
                            .where("created_at <= ?", at)
                            .order(:created_at)
                            .last
      return nil if journal.nil?

      journal.data&.attributes&.slice(*TRACKED_ATTRS)
    end

    # Batch-resolves journal snapshots for an array of WPs.
    def batch_attributes_at(work_packages, at)
      # Eager-load journals to avoid N+1.
      wp_ids = work_packages.map(&:id)
      journals = Journal
                   .where(journable_type: "WorkPackage", journable_id: wp_ids)
                   .where("created_at <= ?", at)
                   .order(:created_at)

      # Keep only the last journal per WP.
      last_journals = journals.each_with_object({}) do |j, h|
        h[j.journable_id] = j
      end

      last_journals.transform_values { |j|
        j.data&.attributes&.slice(*TRACKED_ATTRS)
      }
    end
  end
end
