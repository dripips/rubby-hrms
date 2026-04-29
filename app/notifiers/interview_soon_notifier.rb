# Уведомление за 30 минут до интервью.
class InterviewSoonNotifier < InterviewReminderNotifier
  notification_methods do
    def tone = "warning"

    private

    def translation_key = "notifications.interview_soon"
    def default_message = "Через 30 мин: %{kind}-интервью с %{name} в %{time}"
    def fallback_short  = "Скоро интервью"
  end
end
