class CreateKpiEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :kpi_evaluations do |t|
      t.references :kpi_assignment, null: false, foreign_key: true, index: true
      t.references :evaluator, null: false, foreign_key: { to_table: :users }, index: true
      t.decimal :actual_value, precision: 12, scale: 2
      t.decimal :score,        precision: 5,  scale: 2  # 0..100
      t.text    :notes
      t.datetime :evaluated_at, null: false

      t.timestamps
    end

    add_index :kpi_evaluations, :evaluated_at
  end
end
