# Error reporting subscriber: пишет ВСЕ unhandled exceptions в специальный
# error.log + (опционально) шлёт в Sentry если SENTRY_DSN установлен.
#
# Без жёсткой зависимости от sentry-ruby gem'а — если он установлен, юзаем,
# если нет — только локальный лог.
#
# Поведение:
#   • exception в controller / job / mailer → запись в log/errors.log
#   • metadata: класс, message, request_id, user_id, env, контекст
#   • если ENV["SENTRY_DSN"] задан и gem доступен → отправка в Sentry
#
# Чтобы включить Sentry в проде:
#   1. Добавь gem 'sentry-rails' в Gemfile
#   2. SENTRY_DSN=https://... в .env

class HrmsErrorSubscriber
  ERROR_LOGGER = ActiveSupport::TaggedLogging.new(
    Logger.new(Rails.root.join("log/errors.log"), 5, 10.megabytes)
  )

  def report(error, handled:, severity:, context:, source: nil)
    return if handled  # rescue'нутые ошибки не репортим
    return if severity == :info

    payload = {
      ts: Time.current.iso8601,
      class: error.class.name,
      message: error.message.to_s.first(500),
      severity: severity,
      source: source,
      context: context.to_h.except(:_aj_globalid).slice(:request_id, :user_id, :params, :job, :url),
      backtrace: Array(error.backtrace).first(15)
    }

    ERROR_LOGGER.tagged(error.class.name) { |l| l.error(payload.to_json) }

    # Опциональная отправка в Sentry — только если gem загружен
    if defined?(Sentry) && Sentry.respond_to?(:capture_exception)
      Sentry.capture_exception(error, extra: payload[:context])
    end
  end
end

# Регистрируем подписчика на стандартный Rails error reporter
Rails.application.config.after_initialize do
  Rails.error.subscribe(HrmsErrorSubscriber.new)
end
