class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :documentable, polymorphic: true, null: false, index: true
      t.references :document_type, null: false, foreign_key: true, index: true
      t.string  :number
      t.date    :issued_at
      t.date    :expires_at
      t.string  :issuer
      t.text    :notes
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :documents, :expires_at
    add_index :documents, :discarded_at
  end
end
