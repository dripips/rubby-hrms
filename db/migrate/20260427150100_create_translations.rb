class CreateTranslations < ActiveRecord::Migration[8.1]
  def change
    # The i18n-active_record gem expects a table named `translations` with
    # columns locale, key, value, interpolations (text), is_proc (boolean).
    create_table :translations do |t|
      t.string  :locale,         null: false, limit: 8
      t.string  :key,            null: false
      t.text    :value
      t.text    :interpolations
      t.boolean :is_proc,        null: false, default: false

      t.timestamps
    end

    add_index :translations, [:locale, :key], unique: true
    add_index :translations, :key
  end
end
