class CreateLanguages < ActiveRecord::Migration[8.1]
  def change
    create_table :languages do |t|
      t.string  :code,         null: false, limit: 8
      t.string  :native_name,  null: false
      t.string  :english_name, null: false
      t.string  :flag,         limit: 8
      t.integer :direction,    null: false, default: 0
      t.boolean :is_default,   null: false, default: false
      t.boolean :enabled,      null: false, default: true
      t.integer :position,     null: false, default: 0
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :languages, :code, unique: true
    add_index :languages, :enabled
    add_index :languages, :discarded_at
    # Только один язык может быть default — гарантируем на уровне БД.
    add_index :languages, :is_default, unique: true, where: "is_default = true"
  end
end
