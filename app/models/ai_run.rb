class AiRun < ApplicationRecord
  belongs_to :job_applicant,        optional: true
  belongs_to :interview_round,      optional: true
  belongs_to :job_opening,          optional: true
  belongs_to :employee,             optional: true
  belongs_to :onboarding_process,   optional: true
  belongs_to :offboarding_process,  optional: true
  belongs_to :user

  KINDS = %w[
    analyze_resume recommend questions_for generate_assignment summarize_interview compare_candidates
    burnout_brief suggest_leave_window kpi_brief meeting_agenda kpi_team_brief
    onboarding_plan welcome_letter mentor_match probation_review offer_letter
    compensation_review exit_risk_brief knowledge_transfer_plan exit_interview_brief replacement_brief
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

  validates :kind,  inclusion: { in: KINDS }
  validates :model, presence: true

  scope :recent,        -> { order(created_at: :desc) }
  scope :for_applicant, ->(a) { where(job_applicant_id: a.id) }
  scope :for_round,     ->(r) { where(interview_round_id: r.id) }
  scope :successful,    -> { where(success: true) }

  # Сохраняет результат вызова RecruitmentAi#analyze_resume / recommend / etc.
  # Получает hash из chat-метода: { ok:, content:, tokens:, raw:, error:,
  #                                 input_tokens:, output_tokens: }
  def self.record!(kind:, model:, user:, result:, job_applicant: nil, interview_round: nil, job_opening: nil, employee: nil, onboarding_process: nil, offboarding_process: nil)
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

  def deliver_notification
    return unless user.notify_for?("ai_run_completed", :in_app)

    AiRunCompletedNotifier.with(ai_run_id: id).deliver(user)

    # Make sure the topbar bell repaints live — the Noticed::Notification
    # initializer-level callback can be lost on class reload in dev, so we
    # broadcast here defensively. Idempotent: if the initializer fires too,
    # the second replace is a no-op visually.
    Turbo::StreamsChannel.broadcast_replace_to(
      [ user, "notifications" ],
      target:  "topbar-bell",
      partial: "shared/notifications_bell",
      locals:  { user: user }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#deliver_notification] #{e.class}: #{e.message}")
  end

  def broadcast_to_applicant
    history = AiRun.for_applicant(job_applicant).recent.limit(20)
    Turbo::StreamsChannel.broadcast_update_to(
      [ job_applicant, "ai_panel" ],
      target: "ai-loading-#{job_applicant_id}",
      content: ""
    )
    Turbo::StreamsChannel.broadcast_update_to(
      [ job_applicant, "ai_panel" ],
      target: "ai-panel-#{job_applicant_id}",
      partial: "ai/applicants/result",
      locals:  { applicant: job_applicant, run: self, history: history }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_to_applicant] #{e.class}: #{e.message}")
  end

  def broadcast_to_round
    target_id = (kind == "summarize_interview" ? "ai-summary-" : "ai-questions-") + interview_round_id.to_s
    partial   = (kind == "summarize_interview" ? "ai/rounds/summary" : "ai/rounds/questions")

    Turbo::StreamsChannel.broadcast_update_to(
      [ interview_round, "ai_questions" ],
      target:  target_id,
      partial: partial,
      locals:  { round: interview_round, run: self }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_to_round] #{e.class}: #{e.message}")
  end

  def broadcast_to_employee
    history = AiRun.for_employee(employee).where(kind: %w[burnout_brief suggest_leave_window]).recent.limit(10)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ employee, "ai_leaves" ],
      target:  "ai-leaves-panel-#{employee_id}",
      partial: "ai/leaves/result",
      locals:  { employee: employee, run: self, history: history }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_to_employee] #{e.class}: #{e.message}")
  end

  def broadcast_to_onboarding
    Turbo::StreamsChannel.broadcast_replace_to(
      [ onboarding_process, "ai_panel" ],
      target:  "ai-onboarding-panel-#{onboarding_process_id}",
      partial: "ai/onboarding/result",
      locals:  { process: onboarding_process, run: self }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_to_onboarding] #{e.class}: #{e.message}")
  end

  def broadcast_to_offboarding
    Turbo::StreamsChannel.broadcast_replace_to(
      [ offboarding_process, "ai_panel" ],
      target:  "ai-offboarding-panel-#{offboarding_process_id}",
      partial: "ai/offboarding/result",
      locals:  { process: offboarding_process, run: self }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_to_offboarding] #{e.class}: #{e.message}")
  end

  def broadcast_kpi_team
    company_id = user.employee&.company_id || Company.kept.first&.id
    return unless company_id
    history = AiRun.where(kind: "kpi_team_brief").recent.limit(5)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ "company-#{company_id}", "kpi_team" ],
      target:  "ai-kpi-team-panel",
      partial: "ai/kpi/team_result",
      locals:  { run: self, history: history }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_kpi_team] #{e.class}: #{e.message}")
  end

  def broadcast_to_opening
    Turbo::StreamsChannel.broadcast_update_to(
      [ job_opening, "ai_compare" ],
      target:  "ai-compare-loading-#{job_opening_id}",
      content: ""
    )
    Turbo::StreamsChannel.broadcast_update_to(
      [ job_opening, "ai_compare" ],
      target:  "ai-compare-result-#{job_opening_id}",
      partial: "ai/openings/result",
      locals:  { opening: job_opening, run: self }
    )
    Turbo::StreamsChannel.broadcast_update_to(
      [ job_opening, "ai_compare" ],
      target:  "ai-compare-history-#{job_opening_id}",
      partial: "ai/openings/history",
      locals:  { opening: job_opening }
    )
  rescue StandardError => e
    Rails.logger.warn("[AiRun#broadcast_to_opening] #{e.class}: #{e.message}")
  end
end
