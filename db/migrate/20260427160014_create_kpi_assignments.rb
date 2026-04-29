class CreateKpiAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :kpi_assignments do |t|
      t.references :employee,   null: false, foreign_key: true, index: true
      t.references :kpi_metric, null: false, foreign_key: true, index: true
      t.date    :period_start, null: false
      t.date    :period_end,   null: false
      t.decimal :target, precision: 12, scale: 2
      t.decimal :weight, precision: 5,  scale: 2, default: 1.0
      t.text    :description

      t.timestamps
    end

    add_index :kpi_assignments, [:employee_id, :kpi_metric_id, :period_start], unique: true, name: "kpi_assignment_uniq"
    add_index :kpi_assignments, :period_start
  end
end
