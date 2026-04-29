class CreateLeaveTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_types do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.string  :name, null: false
      t.string  :code, null: false, limit: 32
      t.boolean :paid, null: false, default: true
      t.boolean :requires_doc, null: false, default: false
      t.integer :default_days_per_year, default: 0
      t.string  :color, limit: 8, default: "#007AFF"
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :leave_types, [:company_id, :code], unique: true
  end
end
