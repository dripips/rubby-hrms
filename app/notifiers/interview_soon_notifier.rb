class InterviewSoonNotifier < ApplicationNotifier
  required_param :interview_round_id

  deliver_by :database

  notification_methods do
    def message
      r = round
      return "Скоро интервью" unless r

      I18n.t("notifications.interview_soon",
             time: l(r.scheduled_at, format: :short),
             name: r.job_applicant&.full_name,
             kind: I18n.t("interview_rounds.kinds.#{r.kind}", locale: recipient_locale, default: r.kind),
             default: "Через 30 мин: %{kind}-интервью с %{name} в %{time}",
             locale: recipient_locale)
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

    def tone = "warning"

    private

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
