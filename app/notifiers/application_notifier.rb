class ApplicationNotifier < Noticed::Event
  # Базовый класс — здесь общие настройки + i18n хелперы.
  # Каждый нотификатор-наследник определяет свои deliver_by :database / :email +
  # url + message. Slack и Telegram подмешиваются ЗДЕСЬ — общие для всех типов,
  # gated через recipient.notify_for?(event_kind, :slack/:telegram).

  # Slack — per-user webhook URL (users.slack_webhook_url). Юзер сам подключает
  # incoming-webhook в Slack и пастит URL в /profile/integrations.
  deliver_by :slack, class: "DeliveryMethods::Slack", if: :should_slack?

  # Telegram — per-user chat_id (users.telegram_chat_id) + company-wide bot_token
  # из AppSetting communication.
  deliver_by :telegram, class: "DeliveryMethods::Telegram", if: :should_telegram?

  def should_slack?(notification)
    rec = notification.recipient
    return false unless rec.respond_to?(:slack_webhook_url) && rec.respond_to?(:notify_for?)
    rec.slack_webhook_url.present? && rec.notify_for?(event_kind, :slack)
  end

  def should_telegram?(notification)
    rec = notification.recipient
    return false unless rec.respond_to?(:telegram_chat_id) && rec.respond_to?(:notify_for?)
    rec.telegram_chat_id.present? && rec.notify_for?(event_kind, :telegram)
  end

  # event_kind — короткий ключ нотификатора без суффикса Notifier и в snake_case.
  # Используется в notify_for?(kind, channel).
  def event_kind
    self.class.name.to_s.sub(/Notifier\z/, "").underscore
  end

  # Возвращает кратко-форматированный URL по polymorphic record (AiRun, InterviewRound, ...).
  def default_url
    record_url || "/"
  end
end
