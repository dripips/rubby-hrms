class AddDashboardPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dashboard_preferences, :jsonb, default: {}
  end
end
