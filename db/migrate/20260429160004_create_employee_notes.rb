class CreateEmployeeNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_notes do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.references :author,   null: false, foreign_key: { to_table: :users }, index: true
      t.text    :body, null: false
      t.boolean :hr_only, null: false, default: false
      t.boolean :pinned,  null: false, default: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :employee_notes, %i[employee_id pinned created_at], name: "idx_employee_notes_listing"
  end
end
