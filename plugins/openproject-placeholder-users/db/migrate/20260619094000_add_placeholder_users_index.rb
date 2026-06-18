# frozen_string_literal: true

# OpenProject 17 runs on Rails 7.1+ (zeitwerk, bundler). The placeholder user is
# a Principal STI subtype on the existing `users` table, so NO new table is
# created — hence no `op_phusers_*` table here (that namespace rule applies only
# to brand-new plugin tables, of which this plugin has none).
#
# We only add a partial index so listing/looking up placeholders is fast and
# never scans the full `users` table.
class AddPlaceholderUsersIndex < ActiveRecord::Migration[7.1]
  # verify: STI type column is `type` and the principals/users table is `users`
  # on the running image (confirmed: ::User and ::Group are STI on `users`).
  def up
    add_index :users, :id,
              where: "type = 'PlaceholderUsers::PlaceholderUser'",
              name: "idx_op_phusers_placeholder_users",
              if_not_exists: true
  end

  def down
    remove_index :users,
                 name: "idx_op_phusers_placeholder_users",
                 if_exists: true
  end
end
