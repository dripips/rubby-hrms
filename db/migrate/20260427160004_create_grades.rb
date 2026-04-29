class CreateGrades < ActiveRecord::Migration[8.1]
  def change
    create_table :grades do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.string  :name, null: false
      t.integer :level, null: false, default: 0
      t.decimal :min_salary, precision: 12, scale: 2
      t.decimal :max_salary, precision: 12, scale: 2
      t.string  :currency, limit: 3, default: "RUB"
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :grades, [:company_id, :level], unique: true
    add_index :grades, :active
  end
end
