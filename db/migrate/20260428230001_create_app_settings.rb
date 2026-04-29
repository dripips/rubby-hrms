class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.references :company, null: false, foreign_key: true

      t.string :category, null: false
      t.jsonb  :data,     null: false, default: {}
      # secret хранит чувствительный токен (smtp password / openai api key).
      # На MVP — без encryption-at-rest; позже включим Rails encrypts.
      t.text   :secret

      t.timestamps
    end

    add_index :app_settings, %i[company_id category], unique: true
  end
end
