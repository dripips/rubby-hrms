class CreateKpiMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :kpi_metrics do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.string  :name, null: false
      t.string  :code, null: false, limit: 64
      t.string  :unit, limit: 16
      t.integer :target_direction, null: false, default: 0  # 0 maximize, 1 minimize, 2 target
      t.decimal :weight_default, precision: 5, scale: 2, default: 1.0
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :kpi_metrics, [:company_id, :code], unique: true
    add_index :kpi_metrics, :active
  end
end
