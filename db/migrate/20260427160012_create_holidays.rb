class CreateHolidays < ActiveRecord::Migration[8.1]
  def change
    create_table :holidays do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.date   :date, null: false
      t.string :name, null: false
      t.string :region, limit: 8
      t.boolean :is_workday, null: false, default: false  # перенос рабочего дня (для РФ)

      t.timestamps
    end

    add_index :holidays, [:company_id, :date, :region], unique: true, name: "holidays_unique_idx"
  end
end
