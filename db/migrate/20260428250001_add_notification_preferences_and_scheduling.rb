class AddNotificationPreferencesAndScheduling < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_preferences, :jsonb, null: false, default: {}

    # Помечаем что для раунда уже отправлено "за 30 мин" уведомление,
    # чтобы recurring-job не дублировал.
    add_column :interview_rounds, :soon_notified_at, :datetime
    add_column :interview_rounds, :digest_notified_on, :date  # для "сегодня встреча"
  end
end
