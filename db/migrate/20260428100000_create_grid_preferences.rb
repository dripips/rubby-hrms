class CreateGridPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :grid_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :key,  null: false, limit: 64    # e.g. "employees-grid-v1"
      t.string :kind, null: false, limit: 32    # "columns" | "sort" | "filter" | "headerFilter" | "page"
      t.jsonb  :data, null: false, default: {}

      t.timestamps
    end

    add_index :grid_preferences, %i[user_id key kind], unique: true, name: "grid_prefs_uniq"
    add_index :grid_preferences, :data, using: :gin
  end
end
