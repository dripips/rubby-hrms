# Уведомление: документ скоро истекает (или уже истёк). Отправляется
# DocumentExpiryCheckJob раз в день HR-юзерам компании.
class DocumentExpiringNotifier < ApplicationNotifier
  required_param :document_id
  required_param :days_left  # отрицательное → уже просрочен

  deliver_by :database

  # Email-канал — отправляется только если получатель не отключил
  # NOTIFICATION_KINDS["document_expiring"][:email]. SMTP-настройки
  # подмешиваются автоматически в ApplicationMailer#apply_runtime_smtp.
  deliver_by :email,
             mailer: "DocumentMailer",
             method: :expiring,
             if:     :should_email?

  # Helper для условия отправки email. Noticed v3 при `if: :symbol` вызывает
  # этот метод на Notifier и передаёт notification аргументом.
  def should_email?(notification)
    rec = notification.recipient
    return false unless rec.respond_to?(:notify_for?)
    rec.notify_for?("document_expiring", :email)
  end

  notification_methods do
    def message
      d = document
      return fallback_short unless d

      days = params[:days_left].to_i
      key  = if days < 0       then "notifications.document_expiring.expired"
      elsif days == 0   then "notifications.document_expiring.today"
      elsif days <= 7   then "notifications.document_expiring.week"
      else                   "notifications.document_expiring.month"
      end

      I18n.t(key,
             title:  d.display_title,
             owner:  d.documentable.try(:full_name) || "—",
             days:   days.abs,
             locale: recipient_locale,
             default: fallback_short)
    end

    def url
      Rails.application.routes.url_helpers.document_path(params[:document_id], locale: recipient_locale)
    rescue StandardError
      "/"
    end

    def icon
      params[:days_left].to_i < 0 ? "⚠" : "⏰"
    end

    def tone
      d = params[:days_left].to_i
      return "danger"  if d <= 0
      return "warning" if d <= 7
      "info"
    end

    private

    def document
      @document ||= Document.kept.find_by(id: params[:document_id])
    end

    def fallback_short
      "Документ скоро истекает"
    end

    def recipient_locale
      recipient&.locale.presence || I18n.default_locale
    end
  end
end
