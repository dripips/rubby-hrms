class CreateLeaveBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_balances do |t|
      t.references :employee,   null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true
      t.integer :year, null: false
      t.decimal :accrued_days,     precision: 6, scale: 2, default: 0
      t.decimal :used_days,        precision: 6, scale: 2, default: 0
      t.decimal :carried_over_days, precision: 6, scale: 2, default: 0

      t.timestamps
    end

    add_index :leave_balances, [:employee_id, :leave_type_id, :year], unique: true, name: "leave_balances_uniq_idx"
  end
end
