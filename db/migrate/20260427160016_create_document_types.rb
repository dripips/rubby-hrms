class CreateDocumentTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :document_types do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.string  :name, null: false
      t.string  :code, null: false, limit: 32
      t.boolean :required, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :document_types, [:company_id, :code], unique: true
  end
end
