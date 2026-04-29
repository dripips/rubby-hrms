class ApplicationNotifier < Noticed::Event
  # Базовый класс — здесь общие настройки + i18n хелперы.
  # Каждый нотификатор-наследник определяет свои deliver_by + url + message.

  # Возвращает кратко-форматированный URL по polymorphic record (AiRun, InterviewRound, ...).
  def default_url
    record_url || "/"
  end
end
