class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.string  :name, null: false
      t.string  :code, limit: 32
      t.string  :category, limit: 64
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :positions, [:company_id, :code], unique: true, where: "code IS NOT NULL"
    add_index :positions, :active
    add_index :positions, :discarded_at
  end
end
