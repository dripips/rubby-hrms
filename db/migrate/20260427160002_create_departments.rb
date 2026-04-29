class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.references :parent,  foreign_key: { to_table: :departments }, index: true
      t.string  :name, null: false
      t.string  :code, limit: 32
      t.bigint  :head_employee_id  # FK добавим позже после employees
      t.integer :sort_order, null: false, default: 0
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :departments, [:company_id, :code], unique: true, where: "code IS NOT NULL"
    add_index :departments, :head_employee_id
    add_index :departments, :discarded_at

    # Closure tree: каждое отношение предок-потомок (включая самого себя на 0).
    create_table :department_hierarchies, id: false do |t|
      t.integer :ancestor_id,   null: false
      t.integer :descendant_id, null: false
      t.integer :generations,   null: false
    end

    add_index :department_hierarchies, [:ancestor_id, :descendant_id, :generations],
              unique: true, name: "department_anc_desc_idx"
    add_index :department_hierarchies, [:descendant_id], name: "department_desc_idx"
  end
end
