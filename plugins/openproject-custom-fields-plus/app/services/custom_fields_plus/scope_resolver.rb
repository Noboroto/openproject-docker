# frozen_string_literal: true

module CustomFieldsPlus
  # Determines whether a given user can see an advanced field in a project.
  # Scope is controlled by scope_project_ids (empty = all projects) and
  # scope_group_ids (empty = all groups).
  class ScopeResolver
    def initialize(field, user, project)
      @field   = field
      @user    = user
      @project = project
    end

    def visible?
      project_allowed? && group_allowed?
    end

    private

    def project_allowed?
      @field.scope_project_ids.blank? ||
        @field.scope_project_ids.map(&:to_i).include?(@project.id)
    end

    def group_allowed?
      return true if @field.scope_group_ids.blank?

      user_group_ids = @user.groups.pluck(:id)
      (@field.scope_group_ids.map(&:to_i) & user_group_ids).any?
    end
  end
end
