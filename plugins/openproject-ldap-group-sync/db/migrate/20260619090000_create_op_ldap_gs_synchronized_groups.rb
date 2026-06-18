# frozen_string_literal: true

# OpenProject 17 runs on Rails 7.1+. Confirm with:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpLdapGsSynchronizedGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :op_ldap_gs_synchronized_groups, if_not_exists: true do |t|
      # verify against running 17-slim image: CE stores LDAP auth sources in the
      # `ldap_auth_sources` table (LdapAuthSource STI on auth_sources in some
      # older versions). No DB foreign_key constraint is declared here so the
      # plugin remains tolerant of either layout; the model belongs_to it and
      # validates presence at the app layer.
      t.bigint  :ldap_auth_source_id, null: false
      # OpenProject stores groups as STI in the `users` table (Group < Principal);
      # there is no `groups` table. Keep this a plain bigint (no DB FK) and let the
      # model belongs_to :group, class_name: "Group" + validate presence app-side —
      # same tolerant pattern as ldap_auth_source_id above.
      t.bigint  :group_id, null: false
      t.string  :dn,         null: false            # LDAP group distinguished name
      t.boolean :sync_users, null: false, default: true

      t.timestamps
    end

    add_index :op_ldap_gs_synchronized_groups, :ldap_auth_source_id, if_not_exists: true
    add_index :op_ldap_gs_synchronized_groups,
              %i[ldap_auth_source_id dn],
              unique: true,
              name: "idx_ldap_gs_unique_dn_per_source",
              if_not_exists: true
  end
end
