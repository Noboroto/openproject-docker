# frozen_string_literal: true

# Rails 7.1 migration (OpenProject 17 runs on Rails 7.1+). VERIFY the exact Rails
# version against the running image:
#   docker run --rm openproject/openproject:17-slim \
#     cat /app/Gemfile.lock | grep -E '^    rails '
class CreateOpBoardsBoards < ActiveRecord::Migration[7.1]
  def change
    create_table :op_boards_boards do |t|
      t.references :project, null: false, foreign_key: true
      t.string  :name,        null: false
      t.string  :action_type, null: false # "status" | "assignee" | "version"
      t.timestamps
    end

    add_index :op_boards_boards, %i[project_id name]
  end
end
