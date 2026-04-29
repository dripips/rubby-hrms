# Базовый класс для interview-reminder уведомлений (за 30 мин и за день).
# Подклассы переопределяют translation_key, default_message и tone.
class InterviewReminderNotifier < ApplicationNotifier
  required_param :interview_round_id

  deliver_by :database

  notification_methods do
    def message
      r = round
      return fallback_short unless r

      I18n.t(translation_key,
             time:    l(r.scheduled_at, format: :short),
             name:    r.job_applicant&.full_name,
             kind:    I18n.t("interview_rounds.kinds.#{r.kind}", locale: recipient_locale, default: r.kind),
             default: default_message,
             locale:  recipient_locale)
    end

    def url
      r = round
      return "/" unless r

      Rails.application.routes.url_helpers.job_applicant_path(
        r.job_applicant_id, anchor: "interviews", locale: recipient_locale
      )
    rescue StandardError
      "/"
    end

    private

    # Override these in subclasses.
    def translation_key  = raise NotImplementedError
    def default_message  = raise NotImplementedError
    def fallback_short   = raise NotImplementedError

    def round
      @round ||= InterviewRound.kept.find_by(id: params[:interview_round_id])
    end

    def recipient_locale
      recipient&.locale.presence || I18n.default_locale
    end

    def l(*args)
      I18n.l(*args, locale: recipient_locale)
    end
  end
end
