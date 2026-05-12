class AddSlackTelegramToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_webhook_url, :string
    add_column :users, :telegram_chat_id, :string
  end
end
