class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string     :subject
      t.datetime   :last_message_at, index: true
      t.timestamps
    end
  end
end
