# frozen_string_literal: true

# Rails 7.1 migration (OP 17 runs on Rails 7.1+).
# VERIFY against running 17-slim image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpMfaAuditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :op_mfa_audit_events do |t|
      # Admin who changed the policy. Nullable + no FK cascade requirement so an
      # event survives the acting user's deletion.
      t.references :user, foreign_key: true, null: true

      t.string :action, null: false           # enabled | disabled | updated
      t.jsonb  :details, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :op_mfa_audit_events, :created_at
  end
end
