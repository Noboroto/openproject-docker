# frozen_string_literal: true

# Rails 7.1 migration (OP 17 runs on Rails 7.1+).
# VERIFY against running 17-slim image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
#
# Append-only audit table: rows are INSERT-only and immutable (enforced at the
# model layer via readonly?). Deliberately NO updated_at column — events never
# change. created_at doubles as the insert timestamp; occurred_at is the logical
# event time (may differ slightly when recorded asynchronously).
class CreateOpAuditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :op_audit_events, if_not_exists: true do |t|
      # The acting user (nil for system/unauthenticated events). Nullable + no
      # cascade so an event survives the actor's later deletion.
      t.references :actor, foreign_key: { to_table: :users }, null: true

      t.string  :event,       null: false           # e.g. "member.created"
      t.string  :target_type                        # e.g. "Project"
      t.bigint  :target_id

      # Scrubbed change set (secrets removed before persistence). Default {} so a
      # missing payload never NULLs the column.
      t.jsonb   :changes,     null: false, default: {}

      # PII — only populated when the capture_ip setting is enabled.
      t.string  :ip_address

      # Logical event time + insert time. No updated_at (immutable).
      t.datetime :occurred_at, null: false
      t.datetime :created_at,  null: false
    end

    add_index :op_audit_events, %i[event occurred_at], if_not_exists: true
    add_index :op_audit_events, %i[target_type target_id], if_not_exists: true
    add_index :op_audit_events, :occurred_at, if_not_exists: true
  end
end
