# frozen_string_literal: true

module LdapGroupSync
  # One mapping of an LDAP group (by distinguished name) to an OpenProject group,
  # scoped to a specific LDAP auth source.
  class SynchronizedGroup < ApplicationRecord
    self.table_name = "op_ldap_gs_synchronized_groups"

    # verify against running 17-slim image: CE's LDAP auth source class is
    # `LdapAuthSource` (table `ldap_auth_sources`). If the running image uses the
    # older `AuthSource`/STI layout, change class_name accordingly. We avoid a DB
    # FK so either layout loads; presence is validated below.
    belongs_to :ldap_auth_source, class_name: "LdapAuthSource", optional: true
    belongs_to :group, class_name: "Group"

    has_many :sync_runs,
             class_name: "LdapGroupSync::SyncRun",
             dependent: :destroy

    validates :dn, presence: true
    validates :ldap_auth_source_id, presence: true
    validates :dn, uniqueness: { scope: :ldap_auth_source_id }

    validate :reject_admin_group_unless_confirmed

    # Set transiently by the controller when the admin explicitly ticks
    # "I understand this maps a privileged group".
    attr_accessor :confirm_privileged

    private

    # Guardrail: refuse to map the built-in admin group unless explicitly
    # confirmed, since a wide LDAP group could otherwise mass-grant admin.
    #
    # verify against running 17-slim image: Group has no single canonical "admin
    # group" flag; admin is a per-user attribute. We treat any group whose name
    # matches a configurable admin-ish pattern as privileged. Adjust as needed.
    def reject_admin_group_unless_confirmed
      return if confirm_privileged
      return unless group

      if group.name.to_s.match?(/\Aadmin/i)
        errors.add(:group, :privileged_requires_confirmation)
      end
    end
  end
end
