# Принимает POST'ы от Telegram Bot API на /telegram/webhook.
#
# Регистрируется через Settings::CommunicationsController#setup_webhook —
# вместе с URL генерируется случайный `webhook_secret`, который Telegram
# отправляет в заголовке `X-Telegram-Bot-Api-Secret-Token` на каждом запросе.
# Здесь проверяем заголовок — это защита от спама в endpoint.
#
# Поддерживаемые команды:
#   /start          — приветствие (бот молчит если payload не понятен)
#   /start <TOKEN>  — привязка к юзеру: ищет User с tg_link_token=TOKEN
#                      (созданным через ProfileController#start_telegram_link
#                      и не старше 10 минут), сохраняет telegram_chat_id,
#                      пишет юзеру подтверждение.
#
# Endpoint безсессионный (skip CSRF / auth). Любые сбои — 200 OK + warn-лог
# (Telegram retry'ит при 5xx, нам это не нужно).
class TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, raise: false
  protect_from_forgery with: :null_session

  LINK_TOKEN_TTL = 10.minutes

  def receive
    unless valid_secret?
      Rails.logger.warn("[Telegram webhook] bad secret")
      head :unauthorized
      return
    end

    update = request.request_parameters.presence || params.to_unsafe_h
    msg    = update["message"] || update[:message] || {}
    chat   = msg["chat"]    || {}
    text   = msg["text"].to_s

    chat_id = chat["id"]&.to_s
    head :ok and return if chat_id.blank?

    case text
    when %r{\A/start\s+(\S+)\z}
      handle_link(chat_id, $1)
    when %r{\A/start\b}
      send_message(chat_id, t_msg(:start_no_token))
    end

    head :ok
  rescue StandardError => e
    Rails.logger.warn("[Telegram webhook] #{e.class}: #{e.message}")
    head :ok
  end

  private

  def valid_secret?
    expected = communication_data["telegram_webhook_secret"].to_s
    return false if expected.blank?
    received = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s
    return false if received.blank?
    ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  def handle_link(chat_id, token)
    user = User.where("tg_link_token_at >= ?", LINK_TOKEN_TTL.ago).find_by(tg_link_token: token)
    if user.nil?
      send_message(chat_id, t_msg(:link_invalid))
      return
    end

    user.update!(
      telegram_chat_id: chat_id,
      tg_link_token:    nil,
      tg_link_token_at: nil
    )
    send_message(chat_id, format(t_msg(:link_ok), email: user.email))
  end

  def send_message(chat_id, text)
    bot_token = communication_data["telegram_bot_token"].to_s
    return if bot_token.blank?

    require "net/http"
    Net::HTTP.post(
      URI("https://api.telegram.org/bot#{bot_token}/sendMessage"),
      { chat_id: chat_id, text: text, parse_mode: "Markdown" }.to_json,
      "Content-Type" => "application/json"
    )
  rescue StandardError => e
    Rails.logger.warn("[Telegram webhook send] #{e.class}: #{e.message}")
  end

  def communication_data
    @communication_data ||= begin
      company = Company.kept.first
      (company && AppSetting.find_by(company: company, category: "communication")&.data) || {}
    end
  end

  # Бот молча? нет, отвечаем по-человечески — но коротко, без i18n инициации,
  # потому что Telegram пишет от лица бота независимо от языка юзера HRMS.
  def t_msg(key)
    {
      start_no_token: "Привет! Этот бот шлёт уведомления HRMS. Чтобы привязать аккаунт — открой /profile/integrations в HRMS и нажми «Подключить через Telegram».",
      link_invalid:   "Ссылка устарела или неверна. Сгенерируй новую в HRMS → /profile/integrations.",
      link_ok:        "✓ Готово! Этот аккаунт привязан к HRMS как *%{email}*. Теперь сюда будут приходить уведомления."
    }[key]
  end
end
