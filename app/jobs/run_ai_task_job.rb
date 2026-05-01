# Async-выполнение AI-задачи. Контроллер мгновенно возвращает скелетон,
# job вызывает RecruitmentAi на сервере, сохраняет AiRun.
# AiRun#after_create_commit бродкастит обновление UI через Turbo Streams.
class RunAiTaskJob < ApplicationJob
  queue_as :default

  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 2

  def perform(kind:, user_id:, applicant_id: nil, round_id: nil, brief: nil,
              opening_id: nil, applicant_ids: nil,
              employee_id: nil, leave_type_id: nil, days_needed: nil, system_tag: nil,
              scope_type: nil, scope_id: nil, lock_scope: nil,
              onboarding_process_id: nil, offboarding_process_id: nil,
              document_id: nil, dictionary_id: nil, hint: nil,
              user_message: nil,
              salary: nil, start_date: nil, benefits: nil, manager: nil)
    user       = User.find(user_id)
    applicant  = JobApplicant.kept.find(applicant_id) if applicant_id
    round      = InterviewRound.kept.find(round_id)   if round_id
    opening    = JobOpening.kept.find(opening_id)     if opening_id
    applicants = JobApplicant.kept.where(id: applicant_ids).to_a if applicant_ids
    employee   = Employee.kept.find_by(id: employee_id)
    leave_type = LeaveType.find_by(id: leave_type_id)
    onboarding_process  = OnboardingProcess.kept.find_by(id: onboarding_process_id)   if onboarding_process_id
    offboarding_process = OffboardingProcess.kept.find_by(id: offboarding_process_id) if offboarding_process_id
    document            = Document.kept.find_by(id: document_id)                     if document_id
    dictionary          = Dictionary.kept.find_by(id: dictionary_id)                 if dictionary_id

    # process-bound agents имеют employee через связь
    employee ||= onboarding_process&.employee || offboarding_process&.employee

    setting = AppSetting.fetch(company: Company.kept.first, category: "ai")
    ai      = RecruitmentAi.new(setting: setting, output_locale: user.locale)

    result = begin
      case kind
      when "analyze_resume"          then ai.analyze_resume(applicant)
      when "recommend"               then ai.recommend(applicant)
      when "generate_assignment"     then ai.generate_assignment(applicant, brief: brief)
      when "questions_for"           then ai.questions_for(round)
      when "summarize_interview"     then ai.summarize_interview(round)
      when "compare_candidates"      then ai.compare_candidates(applicants, opening: opening)
      when "burnout_brief"           then ai.burnout_brief(employee, system_tag: system_tag)
      when "suggest_leave_window"    then ai.suggest_leave_window(employee, leave_type: leave_type, days_needed: days_needed)
      when "kpi_brief"               then ai.kpi_brief(employee)
      when "meeting_agenda"          then ai.meeting_agenda(employee)
      when "kpi_team_brief"          then ai.kpi_team_brief(scope_type: scope_type, scope_id: scope_id, requester: user)
      when "onboarding_plan"         then ai.onboarding_plan(onboarding_process)
      when "welcome_letter"          then ai.welcome_letter(onboarding_process)
      when "mentor_match"            then ai.mentor_match(onboarding_process)
      when "probation_review"        then ai.probation_review(onboarding_process)
      when "offer_letter"            then ai.offer_letter(applicant, salary: salary, start_date: start_date, benefits: benefits, manager: manager)
      when "compensation_review"     then ai.compensation_review(employee)
      when "exit_risk_brief"         then ai.exit_risk_brief(employee)
      when "knowledge_transfer_plan" then ai.knowledge_transfer_plan(offboarding_process)
      when "exit_interview_brief"    then ai.exit_interview_brief(offboarding_process)
      when "replacement_brief"       then ai.replacement_brief(offboarding_process)
      when "document_summary"        then ai.document_summary(document)
      when "document_extract_assist" then ai.document_extract_assist(document)
      when "dictionary_seed"         then ai.dictionary_seed(dictionary, hint: hint)
      when "company_bootstrap"
        company = Company.kept.first
        history = AiRun.where(kind: "company_bootstrap").successful.order(:created_at).map do |r|
          payload = r.payload.is_a?(Hash) ? r.payload : {}
          [
            { role: "user",      content: payload["user_message"].to_s },
            { role: "assistant", content: payload["raw"].presence || payload.except("user_message").to_json }
          ]
        end.flatten.reject { |m| m[:content].blank? }
        ai.company_bootstrap(company, user_message: user_message, history: history)
      else raise "Unknown AI kind: #{kind}"
      end
    rescue StandardError => e
      Rails.logger.error("[RunAiTaskJob] #{e.class}: #{e.message}")
      { ok: false, error: e.message.first(200), tokens: 0, input_tokens: 0, output_tokens: 0 }
    end

    # Для company_bootstrap сохраняем user_message в payload — UI thread его
    # читает чтобы рендерить пузырьки (HR + AI) для каждого turn'а.
    if kind == "company_bootstrap" && result.is_a?(Hash) && result[:content].is_a?(Hash) && user_message.present?
      result[:content] = result[:content].merge("user_message" => user_message)
    end

    record = AiRun.record!(
      kind:                kind,
      model:               result[:model] || ai.model_for(kind),
      user:                user,
      result:              result,
      job_applicant:       applicant || round&.job_applicant,
      interview_round:     round,
      job_opening:         opening,
      employee:            employee,
      onboarding_process:  onboarding_process,
      offboarding_process: offboarding_process,
      document:            document,
      dictionary:          dictionary
    )

    apply_document_side_effects(document, kind, record) if document && record.success?
  ensure
    if lock_scope.present?
      AiLock.unlock!(lock_scope)
      AiLock.broadcast_controls(lock_scope)
    end
  end

  private

  # Применяем результат AI к самому документу: summary в отдельную колонку,
  # extract-assist — в extracted_data (с пометкой method=ai). Не дёргаем
  # validations: это служебные поля.
  def apply_document_side_effects(document, kind, run)
    case kind
    when "document_summary"
      summary_text = build_summary_text(run.payload)
      document.update_columns(summary: summary_text) if summary_text.present?
    when "document_extract_assist"
      fields = run.payload["fields"]
      return unless fields.is_a?(Hash) && fields.any?

      merged = document.extracted_data.to_h.reject { |k, _| k.to_s.start_with?("_") }.merge(fields)
      document.update_columns(
        extracted_data:    merged,
        extraction_method: "ai",
        extracted_at:      Time.current
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[RunAiTaskJob#apply_document_side_effects] #{e.class}: #{e.message}")
  end

  # Из structured-summary payload собирает читаемый текст для колонки summary.
  def build_summary_text(payload)
    return "" unless payload.is_a?(Hash)

    parts = []
    parts << payload["summary"].to_s.strip if payload["summary"].present?

    %w[key_points obligations risks action_items].each do |key|
      values = Array(payload[key]).map(&:to_s).reject(&:empty?)
      next if values.empty?
      header = I18n.t("documents.ai_summary_sections.#{key}", default: key.humanize)
      parts << "#{header}:\n• #{values.join("\n• ")}"
    end

    parts.join("\n\n")
  end
end
