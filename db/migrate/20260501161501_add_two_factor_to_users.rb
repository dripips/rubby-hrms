class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret,             :string
    add_column :users, :otp_required_for_login, :boolean, default: false, null: false
    add_column :users, :otp_backup_codes,       :text
    add_column :users, :otp_enabled_at,         :datetime
    add_column :users, :otp_last_used_at,       :datetime
  end
end
