class AiRunCompletedNotifier < ApplicationNotifier
  required_param :ai_run_id

  deliver_by :database

  HR_KINDS          = %w[burnout_brief suggest_leave_window kpi_brief meeting_agenda compensation_review exit_risk_brief].freeze
  ONBOARDING_KINDS  = %w[onboarding_plan welcome_letter mentor_match probation_review].freeze
  OFFBOARDING_KINDS = %w[knowledge_transfer_plan exit_interview_brief replacement_brief].freeze

  notification_methods do
    def message
      ar = ai_run
      kind_label  = kind_label_for(ar)
      target_name = subject_name_for(ar)

      base = ar.success ? "notifications.ai_run.success" : "notifications.ai_run.failed"
      # Use employee phrasing for HR/onboarding/offboarding runs (по сотруднику ...).
      employee_kind = AiRunCompletedNotifier::HR_KINDS.include?(ar.kind) ||
                      AiRunCompletedNotifier::ONBOARDING_KINDS.include?(ar.kind) ||
                      AiRunCompletedNotifier::OFFBOARDING_KINDS.include?(ar.kind)
      key  = employee_kind ? "#{base}_employee" : base
      I18n.t(key, kind: kind_label, name: target_name, locale: recipient_locale)
    end

    def url
      return "/" unless ai_run

      helpers = Rails.application.routes.url_helpers
      case ai_run.kind
      when "compare_candidates"
        helpers.job_opening_path(ai_run.job_opening_id, locale: recipient_locale)
      when "questions_for", "summarize_interview"
        helpers.job_applicant_path(ai_run.job_applicant_id, anchor: "interviews", locale: recipient_locale)
      when *AiRunCompletedNotifier::HR_KINDS
        helpers.employee_path(ai_run.employee_id, anchor: "ai", locale: recipient_locale)
      when *AiRunCompletedNotifier::ONBOARDING_KINDS
        helpers.onboarding_process_path(ai_run.onboarding_process_id, locale: recipient_locale)
      when *AiRunCompletedNotifier::OFFBOARDING_KINDS
        helpers.offboarding_process_path(ai_run.offboarding_process_id, locale: recipient_locale)
      else
        helpers.job_applicant_path(ai_run.job_applicant_id, anchor: "ai", locale: recipient_locale)
      end
    rescue StandardError
      "/"
    end

    def icon
      ai_run&.success ? "✓" : "!"
    end

    def tone
      ai_run&.success ? "success" : "danger"
    end

    private

    def kind_label_for(ar)
      if AiRunCompletedNotifier::HR_KINDS.include?(ar.kind)
        I18n.t("ai.leaves.kinds.#{ar.kind}",
               default: I18n.t("ai.actions.#{ar.kind}", default: ar.kind.humanize, locale: recipient_locale),
               locale: recipient_locale)
      else
        I18n.t("ai.actions.#{ar.kind}", default: ar.kind.humanize, locale: recipient_locale)
      end
    end

    def subject_name_for(ar)
      if ar.kind == "compare_candidates"
        ar.job_opening&.title || I18n.t("ai.compare.title", locale: recipient_locale)
      elsif AiRunCompletedNotifier::HR_KINDS.include?(ar.kind)
        ar.employee&.full_name || "—"
      elsif AiRunCompletedNotifier::ONBOARDING_KINDS.include?(ar.kind)
        ar.onboarding_process&.employee&.full_name || ar.employee&.full_name || "—"
      elsif AiRunCompletedNotifier::OFFBOARDING_KINDS.include?(ar.kind)
        ar.offboarding_process&.employee&.full_name || ar.employee&.full_name || "—"
      else
        ar.job_applicant&.full_name || "—"
      end
    end

    def ai_run
      @ai_run ||= AiRun.find_by(id: params[:ai_run_id])
    end

    def recipient_locale
      recipient&.locale.presence || I18n.default_locale
    end
  end
end
