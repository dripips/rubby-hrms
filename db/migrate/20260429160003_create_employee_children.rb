class CreateEmployeeChildren < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_children do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.references :gender_ref,           foreign_key: { to_table: :genders }, index: true
      t.string :first_name,   null: false
      t.string :last_name
      t.date   :birth_date,   null: false
      t.text   :notes # gift preferences, allergies, etc.
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :employee_children, :birth_date
  end
end
