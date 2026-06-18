# frozen_string_literal: true

# Rails 7.1 migration (OpenProject 17 runs on Rails 7.1+). VERIFY the exact Rails
# version against the running image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
#
# Namespaced table (op_teamplanner_ce_*) per plugin conventions. No work-package
# tables are created — the planner reads existing work_packages; only per-user
# saved-view preferences are persisted here.
class CreateTeamplannerCeSavedViews < ActiveRecord::Migration[7.1]
  def change
    create_table :op_teamplanner_ce_saved_views do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string :name,    null: false
      t.jsonb  :filters, null: false, default: {} # { from, to, assignee_ids: [...] }
      t.timestamps
    end

    add_index :op_teamplanner_ce_saved_views, %i[user_id project_id]
  end
end
