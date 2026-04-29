# Универсальный диспетчер исходящих сообщений по конфигурируемым каналам.
#
# Архитектура:
#   • EVENTS — каталог событий, которые система может отправлять.
#   • CHANNELS — поддерживаемые каналы (email/telegram/whatsapp/...).
#   • Конфиг хранится в AppSetting(category: "communication") с матрицей
#     event_kind → { recipient_type → [channels] }.
#
# Использование:
#   MessageDispatcher.deliver!(
#     event:          :test_assignment_sent,
#     recipient_type: :candidate,
#     payload:        { applicant: applicant, assignment: assignment }
#   )
class MessageDispatcher
  EVENTS = %w[
    test_assignment_sent
    candidate_rejected
    candidate_next_stage
    application_received
    new_application
  ].freeze

  RECIPIENT_TYPES = %w[candidate staff].freeze

  CHANNELS = {
    "email" => MessageDispatcher::EmailChannel  = Module.new,
    # будущие — через адаптеры:
    # "telegram" => MessageDispatcher::TelegramChannel,
    # "whatsapp" => MessageDispatcher::WhatsappChannel,
  }.freeze

  # Дефолтная матрица — на случай если AppSetting communication не настроен.
  DEFAULT_MATRIX = {
    "test_assignment_sent" => { "candidate" => ["email"], "staff" => [] },
    "candidate_rejected"   => { "candidate" => ["email"], "staff" => [] },
    "candidate_next_stage" => { "candidate" => ["email"], "staff" => [] },
    "application_received" => { "candidate" => ["email"], "staff" => [] },
    "new_application"      => { "candidate" => [],        "staff" => ["email"] }
  }.freeze

  class << self
    def deliver!(event:, recipient_type:, payload:)
      event_str = event.to_s
      type_str  = recipient_type.to_s
      return unless EVENTS.include?(event_str)
      return unless RECIPIENT_TYPES.include?(type_str)

      channels = active_channels_for(event_str, type_str)
      channels.each do |channel|
        deliver_via(channel, event_str, payload)
      end
    rescue StandardError => e
      Rails.logger.warn("[MessageDispatcher] #{event}/#{recipient_type}: #{e.class}: #{e.message}")
    end

    def active_channels_for(event, recipient_type)
      cfg = communication_setting&.data || {}
      cfg.dig(event, recipient_type) ||
        DEFAULT_MATRIX.dig(event, recipient_type) ||
        []
    end

    def communication_setting
      company = Company.kept.first
      return nil unless company

      AppSetting.find_by(company: company, category: "communication")
    end

    private

    def deliver_via(channel, event, payload)
      case channel
      when "email"    then deliver_email(event, payload)
      when "telegram" then Rails.logger.info("[MessageDispatcher] telegram-канал ещё не реализован")
      when "whatsapp" then Rails.logger.info("[MessageDispatcher] whatsapp-канал ещё не реализован")
      end
    end

    def deliver_email(event, payload)
      case event
      when "test_assignment_sent"
        CandidateMailer.with(payload).test_assignment_sent.deliver_later
      when "candidate_rejected"
        CandidateMailer.with(payload).rejected.deliver_later
      when "candidate_next_stage"
        CandidateMailer.with(payload).next_stage.deliver_later
      when "application_received"
        CandidateMailer.with(payload).application_received.deliver_later
      when "new_application"
        recruiter = payload[:opening]&.owner
        return unless recruiter&.email.present?
        StaffMailer.with(payload.merge(to: recruiter.email)).new_application.deliver_later
      end
    end
  end
end
