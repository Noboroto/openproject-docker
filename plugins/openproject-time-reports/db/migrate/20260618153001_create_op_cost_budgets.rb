# frozen_string_literal: true

# Rails 7.1 — OpenProject 17 runs on Rails 7.1+.
class CreateOpCostBudgets < ActiveRecord::Migration[7.1]
  def change
    create_table :op_cost_budgets, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: true
      t.string  :name, null: false

      # Money: decimal, never float.
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string  :currency, null: false, default: "USD"

      # Optional period; when set, "spent" is computed from time entries whose
      # spent_on falls inside [period_start, period_end].
      t.date    :period_start
      t.date    :period_end

      t.timestamps
    end

    add_index :op_cost_budgets, %i[project_id name], if_not_exists: true
  end
end
