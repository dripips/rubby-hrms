class AddTgLinkTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tg_link_token,    :string
    add_column :users, :tg_link_token_at, :datetime
    add_index  :users, :tg_link_token, unique: true, where: "tg_link_token IS NOT NULL"
  end
end
