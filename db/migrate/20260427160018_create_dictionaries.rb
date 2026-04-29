class CreateDictionaries < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionaries do |t|
      t.references :company, foreign_key: true, index: true
      t.string :code, null: false, limit: 64
      t.string :name, null: false
      t.text   :description
      t.boolean :system, null: false, default: false  # системные нельзя удалить
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dictionaries, [:company_id, :code], unique: true
  end
end
