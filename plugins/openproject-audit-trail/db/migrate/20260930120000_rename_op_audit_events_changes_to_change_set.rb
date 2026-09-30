# frozen_string_literal: true

# `changes` collides with ActiveModel::Dirty#changes, so ActiveRecord refuses the
# attribute (DangerousAttributeError) and every AuditEvent insert failed. The
# recorder swallowed the error, which left the table empty. Renaming the column
# is the only fix; the table held no rows when this shipped.
class RenameOpAuditEventsChangesToChangeSet < ActiveRecord::Migration[7.1]
  def change
    rename_column :op_audit_events, :changes, :change_set
  end
end
