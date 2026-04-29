class Ai::OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_ai_enabled
  before_action :ensure_hr
  before_action :set_process, except: %i[materialize_tasks]

  def plan             = enqueue_onboarding!("onboarding_plan")
  def welcome_letter   = enqueue_onboarding!("welcome_letter")
  def mentor_match     = enqueue_onboarding!("mentor_match")
  def probation_review = enqueue_onboarding!("probation_review")

  # POST /ai/onboarding_runs/:id/materialize_tasks
  # Принимает результат onboarding_plan и создаёт OnboardingTask из payload[tasks]
  def materialize_tasks
    run = AiRun.find(params[:id])
    return redirect_to(root_path, alert: t("ai.error")) unless run.success && run.onboarding_process

    process = run.onboarding_process
    base    = process.started_on || Date.current
    Array(run.payload["tasks"]).each_with_index do |item, idx|
      next if item["title"].blank?

      offset = item["due_offset_days"].to_i
      process.tasks.create!(
        title:        item["title"],
        description:  item["description"],
        kind:         (OnboardingTask::KINDS.include?(item["kind"]) ? item["kind"] : "general"),
        position:     1000 + idx,
        ai_generated: true,
        due_on:       offset.zero? ? nil : base + offset.days
      )
    end

    redirect_to onboarding_process_path(process), notice: t("ai.onboarding.tasks_added", default: "Задачи AI добавлены")
  end

  private

  def set_process = (@process = OnboardingProcess.find(params[:id]))

  def enqueue_onboarding!(kind)
    scope = AiLock.for_onboarding(@process)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: kind)
      RunAiTaskJob.perform_later(
        kind:                  kind,
        onboarding_process_id: @process.id,
        user_id:               current_user.id,
        lock_scope:            scope
      )
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "ai-onboarding-panel-#{@process.id}",
            partial: "ai/onboarding/skeleton",
            locals:  { process: @process, kind: AiLock.kind_for(scope) || kind }
          ),
          turbo_stream.replace(
            "ai-controls-onboarding-#{@process.id}",
            partial: "ai/onboarding/controls",
            locals:  { process: @process }
          )
        ]
      end
      format.html { redirect_to onboarding_process_path(@process) }
    end
  end

  def setting = (@setting ||= AppSetting.fetch(company: Company.kept.first, category: "ai"))
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
