class AiRun < ApplicationRecord
  belongs_to :job_applicant,        optional: true
  belongs_to :interview_round,      optional: true
  belongs_to :job_opening,          optional: true
  belongs_to :employee,             optional: true
  belongs_to :onboarding_process,   optional: true
  belongs_to :offboarding_process,  optional: true
  belongs_to :document,             optional: true
  belongs_to :dictionary,           optional: true
  belongs_to :user

  KINDS = %w[
    analyze_resume recommend questions_for generate_assignment summarize_interview compare_candidates
    burnout_brief suggest_leave_window kpi_brief meeting_agenda kpi_team_brief
    onboarding_plan welcome_letter mentor_match probation_review offer_letter
    compensation_review exit_risk_brief knowledge_transfer_plan exit_interview_brief replacement_brief
    document_summary document_extract_assist
    dictionary_seed company_bootstrap
    ping
  ].freeze

  scope :for_opening,  ->(o) { where(job_opening_id: o.id) }
  scope :for_employee, ->(e) { where(employee_id: e.id) }

  # После создания: уведомление + live-обновление панели. Каждый callback
  # независимо ловит свои ошибки, чтобы один не блокировал другой.
  after_create_commit :deliver_notification,    if: -> { user_id.present? && kind != "ping" }
  after_create_commit :broadcast_to_applicant,  if: -> { job_applicant_id.present? }
  after_create_commit :broadcast_to_round,      if: -> { interview_round_id.present? && %w[questions_for summarize_interview].include?(kind) }
  after_create_commit :broadcast_to_opening,    if: -> { job_opening_id.present? && kind == "compare_candidates" }
  after_create_commit :broadcast_to_employee,   if: -> { employee_id.present? && %w[burnout_brief suggest_leave_window kpi_brief meeting_agenda compensation_review exit_risk_brief].include?(kind) }
  after_create_commit :broadcast_kpi_team,      if: -> { kind == "kpi_team_brief" && user&.id.present? }
  after_create_commit :broadcast_to_onboarding, if: -> { onboarding_process_id.present? }
  after_create_commit :broadcast_to_offboarding, if: -> { offboarding_process_id.present? }
  after_create_commit :broadcast_to_document,   if: -> { document_id.present? }
  after_create_commit :broadcast_to_dictionary, if: -> { dictionary_id.present? }
  after_create_commit :broadcast_company_bootstrap, if: -> { kind == "company_bootstrap" }

  validates :kind,  inclusion: { in: KINDS }
  validates :model, presence: true

  scope :recent,        -> { order(created_at: :desc) }
  scope :for_applicant, ->(a) { where(job_applicant_id: a.id) }
  scope :for_round,     ->(r) { where(interview_round_id: r.id) }
  scope :successful,    -> { where(success: true) }

  # Сохраняет результат вызова RecruitmentAi#analyze_resume / recommend / etc.
  # Получает hash из chat-метода: { ok:, content:, tokens:, raw:, error:,
  #                                 input_tokens:, output_tokens: }
  def self.record!(kind:, model:, user:, result:, job_applicant: nil, interview_round: nil, job_opening: nil, employee: nil, onboarding_process: nil, offboarding_process: nil, document: nil, dictionary: nil)
    in_tok  = result[:input_tokens].to_i
    out_tok = result[:output_tokens].to_i
    info    = RecruitmentAi::MODELS[model] || {}

    cost = (in_tok * (info[:input_per_1m_usd]  || 0).to_f / 1_000_000.0) +
           (out_tok * (info[:output_per_1m_usd] || 0).to_f / 1_000_000.0)

    payload = if result[:content].is_a?(Hash)
      result[:content]
    elsif result[:content].is_a?(String) && !result[:content].empty?
      { "raw" => result[:content] }
    else
      {}
    end

    create!(
      job_applicant:        job_applicant,
      interview_round:      interview_round,
      job_opening:          job_opening,
      employee:             employee,
      onboarding_process:   onboarding_process,
      offboarding_process:  offboarding_process,
      document:             document,
      dictionary:           dictionary,
      user:                 user,
      kind:                 kind,
      model:                model,
      input_tokens:         in_tok,
      output_tokens:        out_tok,
      total_tokens:         result[:tokens].to_i,
      cost_usd:             cost.round(6),
      success:              result[:ok] == true && payload.any?,
      payload:              payload,
      error:                result[:error]
    )
    # after_create_commit hooks делают всё остальное:
    # - deliver_notification (если включено в prefs)
    # - broadcast_to_applicant (live-update панели)
    # - broadcast_to_round (live-update questions если есть round)
  end

  def cost_display
    cost_usd.to_f.zero? ? "—" : "$#{format('%.4f', cost_usd)}"
  end

  private

  # Wraps Turbo::StreamsChannel calls in a uniform rescue/log harness so each
  # broadcast helper is just a description of what to send, not boilerplate.
  def safe_broadcast(label)
    yield
  rescue StandardError => e
    Rails.logger.warn("[AiRun##{label}] #{e.class}: #{e.message}")
  end

  def deliver_notification
    return unless user.notify_for?("ai_run_completed", :in_app)

    safe_broadcast("deliver_notification") do
      AiRunCompletedNotifier.with(ai_run_id: id).deliver(user)

      # Topbar bell repaint — defensive (Noticed::Notification class-reload
      # in dev может терять initializer-level callback, поэтому шлём здесь).
      Turbo::StreamsChannel.broadcast_replace_to(
        [ user, "notifications" ],
        target:  "topbar-bell",
        partial: "shared/notifications_bell",
        locals:  { user: user }
      )
    end
  end

  def broadcast_to_applicant
    safe_broadcast("broadcast_to_applicant") do
      history  = AiRun.for_applicant(job_applicant).recent.limit(20)
      stream   = [ job_applicant, "ai_panel" ]
      Turbo::StreamsChannel.broadcast_update_to(stream,
        target: "ai-loading-#{job_applicant_id}", content: "")
      Turbo::StreamsChannel.broadcast_update_to(stream,
        target:  "ai-panel-#{job_applicant_id}",
        partial: "ai/applicants/result",
        locals:  { applicant: job_applicant, run: self, history: history })
    end
  end

  def broadcast_to_round
    safe_broadcast("broadcast_to_round") do
      summary  = (kind == "summarize_interview")
      target   = "#{summary ? 'ai-summary-' : 'ai-questions-'}#{interview_round_id}"
      partial  = summary ? "ai/rounds/summary" : "ai/rounds/questions"
      Turbo::StreamsChannel.broadcast_update_to(
        [ interview_round, "ai_questions" ],
        target: target, partial: partial,
        locals: { round: interview_round, run: self }
      )
    end
  end

  def broadcast_to_employee
    safe_broadcast("broadcast_to_employee") do
      history = AiRun.for_employee(employee).where(kind: %w[burnout_brief suggest_leave_window]).recent.limit(10)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ employee, "ai_leaves" ],
        target:  "ai-leaves-panel-#{employee_id}",
        partial: "ai/leaves/result",
        locals:  { employee: employee, run: self, history: history }
      )
    end
  end

  def broadcast_to_document
    safe_broadcast("broadcast_to_document") do
      Turbo::StreamsChannel.broadcast_replace_to(
        [ document, "extraction" ],
        target:  "document-extraction-#{document_id}",
        partial: "documents/extraction_panel",
        locals:  { document: document }
      )
    end
  end

  def broadcast_to_dictionary
    safe_broadcast("broadcast_to_dictionary") do
      Turbo::StreamsChannel.broadcast_replace_to(
        [ dictionary, "ai_seed" ],
        target:  "dictionary-ai-#{dictionary_id}",
        partial: "settings/dictionaries/ai_panel",
        locals:  { dictionary: dictionary }
      )
    end
  end

  def broadcast_company_bootstrap
    safe_broadcast("broadcast_company_bootstrap") do
      company = Current.company || Company.kept.first or return
      Turbo::StreamsChannel.broadcast_replace_to(
        [ company, "company_bootstrap" ],
        target:  "company-bootstrap",
        partial: "settings/dictionaries/bootstrap_panel",
        locals:  { company: company }
      )
    end
  end

  def broadcast_to_onboarding
    broadcast_process_panel("onboarding", onboarding_process, onboarding_process_id)
  end

  def broadcast_to_offboarding
    broadcast_process_panel("offboarding", offboarding_process, offboarding_process_id)
  end

  # Общий рендер для onboarding/offboarding панелей — структура идентична.
  def broadcast_process_panel(kind_label, process, process_id)
    safe_broadcast("broadcast_to_#{kind_label}") do
      Turbo::StreamsChannel.broadcast_replace_to(
        [ process, "ai_panel" ],
        target:  "ai-#{kind_label}-panel-#{process_id}",
        partial: "ai/#{kind_label}/result",
        locals:  { process: process, run: self }
      )
    end
  end

  def broadcast_kpi_team
    safe_broadcast("broadcast_kpi_team") do
      company_id = user.employee&.company_id || Company.kept.first&.id
      next unless company_id

      history = AiRun.where(kind: "kpi_team_brief").recent.limit(5)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ "company-#{company_id}", "kpi_team" ],
        target:  "ai-kpi-team-panel",
        partial: "ai/kpi/team_result",
        locals:  { run: self, history: history }
      )
    end
  end

  def broadcast_to_opening
    safe_broadcast("broadcast_to_opening") do
      stream = [ job_opening, "ai_compare" ]
      oid    = job_opening_id

      Turbo::StreamsChannel.broadcast_update_to(stream,
        target: "ai-compare-loading-#{oid}", content: "")
      Turbo::StreamsChannel.broadcast_update_to(stream,
        target:  "ai-compare-result-#{oid}",
        partial: "ai/openings/result",
        locals:  { opening: job_opening, run: self })
      Turbo::StreamsChannel.broadcast_update_to(stream,
        target:  "ai-compare-history-#{oid}",
        partial: "ai/openings/history",
        locals:  { opening: job_opening })
    end
  end
end
