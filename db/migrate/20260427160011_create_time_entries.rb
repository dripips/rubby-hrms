class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.date    :date,  null: false
      t.decimal :hours, precision: 5, scale: 2, null: false, default: 0
      t.integer :kind,  null: false, default: 0  # 0 work, 1 overtime, 2 sick, 3 leave, 4 holiday
      t.text    :comment

      t.timestamps
    end

    add_index :time_entries, [:employee_id, :date], unique: true
  end
end
