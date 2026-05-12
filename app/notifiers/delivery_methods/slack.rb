# Custom Noticed delivery method для Slack Incoming Webhook.
#
# Использование:
#   deliver_by DeliveryMethods::Slack, if: :should_slack?
#
# Конфиг — per-user webhook URL хранится в users.slack_webhook_url.
# Юзер создаёт свой incoming webhook на api.slack.com → пастит URL в
# /profile/integrations.
#
# Slack принимает POST JSON: { text, attachments: [...] }
# https://api.slack.com/messaging/webhooks
#
# (Встроенный Noticed::DeliveryMethods::Slack требует config.url на уровне
# notifier'а — но у нас URL зависит от recipient'а, поэтому свой класс.)
require "net/http"
require "uri"
require "json"

module DeliveryMethods
  class Slack < Noticed::DeliveryMethods::Base
    def deliver
      webhook = recipient.respond_to?(:slack_webhook_url) ? recipient.slack_webhook_url : nil
      if webhook.blank?
        Rails.logger.warn("[Slack delivery] skip — recipient has no slack_webhook_url")
        return
      end

      uri = URI(webhook)
      response = Net::HTTP.post(
        uri,
        build_payload.to_json,
        "Content-Type" => "application/json"
      )

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[Slack delivery] #{response.code}: #{response.body.to_s.first(200)}")
      end
    end

    private

    def build_payload
      text = notification.message.to_s
      url  = notification.respond_to?(:url) ? notification.url : nil

      payload = { text: text }
      payload[:attachments] = [ {
        title: "HRMS",
        title_link: absolute_url(url),
        color: "#0A84FF"
      } ] if url.present?
      payload
    end

    def absolute_url(path)
      return path if path.to_s.start_with?("http")
      base = Rails.application.config.action_mailer&.default_url_options&.dig(:host) || "http://localhost:3000"
      base = "https://#{base}" unless base.start_with?("http")
      "#{base}#{path}"
    end
  end
end
