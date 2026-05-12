class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string   :name,           null: false
      t.string   :token_digest,   null: false, limit: 60   # bcrypt hash = 60 chars
      t.string   :token_prefix,   null: false, limit: 8    # видимый префикс для UI ("hrms_xxx…")
      t.datetime :last_used_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, :token_prefix
  end
end
