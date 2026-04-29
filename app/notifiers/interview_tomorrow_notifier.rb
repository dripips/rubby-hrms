# Уведомление за день до интервью (утром в день встречи).
class InterviewTomorrowNotifier < InterviewReminderNotifier
  notification_methods do
    def tone = "info"

    private

    def translation_key = "notifications.interview_tomorrow"
    def default_message = "Завтра: %{kind}-интервью с %{name} в %{time}"
    def fallback_short  = "Завтра интервью"
  end
end
