class CreateGenders < ActiveRecord::Migration[8.1]
  def change
    create_table :genders do |t|
      t.references :company,  null: false, foreign_key: true, index: true
      t.string  :code,        null: false, limit: 32
      t.string  :name,        null: false
      t.string  :pronouns,    limit: 64
      t.string  :avatar_seed, limit: 32 # hint for default avatar generator
      t.integer :sort_order,  null: false, default: 0
      t.boolean :active,      null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :genders, [:company_id, :code], unique: true
  end
end
