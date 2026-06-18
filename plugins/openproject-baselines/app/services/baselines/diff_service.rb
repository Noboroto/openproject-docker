# frozen_string_literal: true

module Baselines
  # Computes added/removed/changed WPs between a baseline and current state.
  # Read-only. Scoped to WPs visible to User.current.
  class DiffService
    def initialize(baseline, user)
      @baseline = baseline
      @user     = user
    end

    def call
      cap       = setting_cap
      resolver  = SnapshotResolverService.new

      current_wps = @baseline.project
                              .work_packages
                              .visible(@user)
                              .limit(cap)
                              .to_a
      current_ids = current_wps.map(&:id)

      past_ids = ids_existing_at(@baseline.project, @baseline.captured_at)

      snapshots = resolver.batch_attributes_at(current_wps, @baseline.captured_at)

      {
        added: current_ids - past_ids,
        removed: past_ids - current_ids,
        changed: current_wps.filter_map { |wp|
          old = snapshots[wp.id]
          next if old.nil?

          delta = old.reject { |k, v| wp.read_attribute(k).to_s == v.to_s }
          { id: wp.id, changes: delta } if delta.any?
        }
      }
    end

    private

    def setting_cap
      val = Setting.plugin_openproject_baselines.fetch("max_work_packages", 2000).to_i
      val.positive? ? [val, OpenProject::Baselines::MAX_WORK_PACKAGES].min : OpenProject::Baselines::MAX_WORK_PACKAGES
    end

    # IDs of WPs that existed (had at least one journal) before `at`.
    def ids_existing_at(project, at)
      Journal
        .where(journable_type: "WorkPackage")
        .where("journals.created_at <= ?", at)
        .joins("INNER JOIN work_packages ON work_packages.id = journals.journable_id")
        .where(work_packages: { project_id: project.id })
        .distinct
        .pluck("journals.journable_id")
    end
  end
end
