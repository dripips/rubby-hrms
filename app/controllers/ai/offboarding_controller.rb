class Ai::OffboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_ai_enabled
  before_action :ensure_hr
  before_action :set_process, except: %i[create_opening]

  def knowledge_transfer_plan = enqueue_offboarding!("knowledge_transfer_plan")
  def exit_interview_brief    = enqueue_offboarding!("exit_interview_brief")
  def replacement_brief       = enqueue_offboarding!("replacement_brief")

  # POST /ai/offboarding_runs/:id/create_opening
  # Создаёт draft JobOpening на основе replacement_brief.
  def create_opening
    run = AiRun.find(params[:id])
    return redirect_to(root_path, alert: t("ai.error")) unless run.success && run.offboarding_process

    process = run.offboarding_process
    payload = run.payload
    department = process.employee.department

    opening = JobOpening.new(
      company: current_company,
      title:         payload["title"].to_s.first(180),
      summary:       payload["summary"].to_s,
      description:   ([
        payload["summary"],
        "## #{t('ai.offboarding.responsibilities', default: 'Обязанности')}",
        Array(payload["responsibilities"]).map { |r| "- #{r}" }.join("\n"),
        "## #{t('ai.offboarding.must_have', default: 'Обязательно')}",
        Array(payload["must_have"]).map { |r| "- #{r}" }.join("\n"),
        "## #{t('ai.offboarding.nice_to_have', default: 'Будет плюсом')}",
        Array(payload["nice_to_have"]).map { |r| "- #{r}" }.join("\n")
      ].compact.join("\n\n")),
      department:    department,
      status:        "draft",
      created_by:    current_user
    )

    if opening.save
      redirect_to job_opening_path(opening), notice: t("ai.offboarding.opening_created", default: "Создана черновая вакансия из AI-бриф")
    else
      redirect_to offboarding_process_path(process), alert: opening.errors.full_messages.to_sentence
    end
  end

  private

  def set_process = (@process = OffboardingProcess.find(params[:id]))

  def enqueue_offboarding!(kind)
    scope = AiLock.for_offboarding(@process)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: kind)
      RunAiTaskJob.perform_later(
        kind:                   kind,
        offboarding_process_id: @process.id,
        user_id:                current_user.id,
        lock_scope:             scope
      )
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "ai-offboarding-panel-#{@process.id}",
            partial: "ai/offboarding/skeleton",
            locals:  { process: @process, kind: AiLock.kind_for(scope) || kind }
          ),
          turbo_stream.replace(
            "ai-controls-offboarding-#{@process.id}",
            partial: "ai/offboarding/controls",
            locals:  { process: @process }
          )
        ]
      end
      format.html { redirect_to offboarding_process_path(@process) }
    end
  end

  def setting = (@setting ||= AppSetting.fetch(company: current_company, category: "ai"))
  def ai      = (@ai ||= RecruitmentAi.new(setting: setting))

  def ensure_ai_enabled
    return if ai.enabled?
    redirect_to root_path, alert: t("ai.disabled")
  end

  def ensure_hr
    return if current_user.role_superadmin? || current_user.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end
end
