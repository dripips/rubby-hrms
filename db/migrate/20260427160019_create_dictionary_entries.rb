class CreateDictionaryEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :dictionary_entries do |t|
      t.references :dictionary, null: false, foreign_key: true, index: true
      t.string  :key,   null: false, limit: 64
      t.string  :value, null: false
      t.jsonb   :meta, default: {}
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :dictionary_entries, [:dictionary_id, :key], unique: true
    add_index :dictionary_entries, :meta, using: :gin
  end
end
