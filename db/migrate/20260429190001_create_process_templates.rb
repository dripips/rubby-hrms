class CreateProcessTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :process_templates do |t|
      t.references :company, null: false, foreign_key: true
      t.string  :kind, null: false           # "onboarding" | "offboarding"
      t.string  :name, null: false
      t.text    :description
      t.jsonb   :items, null: false, default: []
      t.boolean :default_template, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :process_templates, %i[company_id kind active]
  end
end
