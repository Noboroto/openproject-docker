# frozen_string_literal: true

module LdapGroupSync
  # Applies the membership diff for a single mapping: compares the desired set of
  # OP user ids (from LDAP) against the OP group's current members, then adds /
  # removes via CORE Groups services as User.system (no ACL bypass; journals are
  # attributed to the system user).
  class SynchronizeService
    def initialize(mapping, resolver: GroupMembershipResolver.new(mapping.ldap_auth_source))
      @mapping = mapping
      @resolver = resolver
    end

    # Returns { added: Integer, removed: Integer }.
    def call
      desired = @resolver.user_ids_in(@mapping.dn)
      current = @mapping.group.users.pluck(:id).to_set

      add    = desired - current
      remove = remove_orphans? ? (current - desired) : Set.new

      ApplicationRecord.transaction do
        add_members(add.to_a)    if add.any?
        remove_members(remove.to_a) if remove.any?
      end

      { added: add.size, removed: remove.size }
    end

    private

    def add_members(ids)
      # verify against running 17-slim image: core service is
      # `Groups::AddUsersService.new(group:, current_user:).call(ids:)`. Confirm
      # the keyword (`ids:` vs `user_ids:`) and that it returns a ServiceResult.
      result = Groups::AddUsersService
               .new(@mapping.group, current_user: User.system)
               .call(ids:)
      raise result.message if result.respond_to?(:success?) && !result.success?
    end

    def remove_members(ids)
      # verify against running 17-slim image: core service is
      # `Groups::RemoveUsersService.new(group, current_user:).call(ids:)`.
      result = Groups::RemoveUsersService
               .new(@mapping.group, current_user: User.system)
               .call(ids:)
      raise result.message if result.respond_to?(:success?) && !result.success?
    end

    def remove_orphans?
      OpenProject::LdapGroupSync.settings["remove_orphaned_memberships"]
    end
  end
end
