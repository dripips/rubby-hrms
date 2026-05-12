# Custom Noticed delivery method для Telegram Bot API.
#
# Использование внутри notifier'а:
#   deliver_by DeliveryMethods::Telegram, if: :should_telegram?
#
# Конфиг:
#   • Глобальный bot_token хранится в AppSetting(category: "communication").data["telegram_bot_token"]
#   • Per-user chat_id — в users.telegram_chat_id (юзер настраивает в /profile/integrations)
#
# Telegram Bot API: POST https://api.telegram.org/bot<TOKEN>/sendMessage
#   { chat_id: ..., text: ..., parse_mode: "Markdown" }
#
# Сообщение собирается из notifier.message + ссылки на нужный URL (если есть).
require "net/http"
require "uri"
require "json"

module DeliveryMethods
  class Telegram < Noticed::DeliveryMethods::Base
    ENDPOINT = "https://api.telegram.org".freeze

    def deliver
      chat_id   = recipient.respond_to?(:telegram_chat_id) ? recipient.telegram_chat_id : nil
      bot_token = telegram_bot_token

      if chat_id.blank? || bot_token.blank?
        Rails.logger.warn("[Telegram delivery] skip — missing chat_id or bot_token")
        return
      end

      text = build_text
      uri  = URI("#{ENDPOINT}/bot#{bot_token}/sendMessage")

      response = Net::HTTP.post(
        uri,
        { chat_id: chat_id, text: text, parse_mode: "Markdown", disable_web_page_preview: true }.to_json,
        "Content-Type" => "application/json"
      )

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[Telegram delivery] #{response.code}: #{response.body.to_s.first(200)}")
      end
    end

    private

    def build_text
      msg = notification.message.to_s
      url = notification.respond_to?(:url) ? notification.url : nil
      url.present? ? "#{msg}\n\n[Открыть](#{absolute_url(url)})" : msg
    end

    def absolute_url(path)
      return path if path.to_s.start_with?("http")
      base = Rails.application.config.action_mailer&.default_url_options&.dig(:host) || "http://localhost:3000"
      base = "https://#{base}" unless base.start_with?("http")
      "#{base}#{path}"
    end

    def telegram_bot_token
      ENV["TELEGRAM_BOT_TOKEN"].presence || communication_setting&.data&.dig("telegram_bot_token")
    end

    def communication_setting
      company = Current.company || Company.kept.first
      return nil unless company
      AppSetting.find_by(company: company, category: "communication")
    end
  end
end
