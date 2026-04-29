class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :company,    null: false, foreign_key: true, index: true
      t.references :user,       null: true,  foreign_key: true, index: { unique: true }  # nullable: внешние подрядчики без логина
      t.references :department, null: true,  foreign_key: true, index: true
      t.references :position,   null: true,  foreign_key: true, index: true
      t.references :grade,      null: true,  foreign_key: true, index: true
      t.bigint     :manager_id  # self-FK, добавим constraint позже

      t.string :personnel_number, null: false, limit: 32
      t.string :last_name,        null: false
      t.string :first_name,       null: false
      t.string :middle_name
      t.date   :birth_date
      t.integer :gender,        null: false, default: 0  # 0 unspecified, 1 male, 2 female
      t.string :phone
      t.string :personal_email
      t.string :address

      t.date   :hired_at,       null: false
      t.date   :terminated_at
      t.integer :employment_type, null: false, default: 0  # 0 full_time, 1 part_time, 2 contract, 3 intern
      t.integer :state,           null: false, default: 1  # 0 probation, 1 active, 2 leave, 3 terminated

      t.datetime :discarded_at

      t.timestamps
    end

    add_index :employees, [:company_id, :personnel_number], unique: true
    add_index :employees, :manager_id
    add_index :employees, :state
    add_index :employees, :discarded_at
    add_index :employees, [:last_name, :first_name]

    add_foreign_key :employees, :employees, column: :manager_id

    # Теперь, когда employees есть, можно повесить FK на head_employee_id в departments.
    add_foreign_key :departments, :employees, column: :head_employee_id
  end
end
