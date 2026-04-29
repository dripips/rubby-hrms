class Ai::ApplicantsController < ApplicationController
  before_action :set_applicant
  before_action :ensure_ai_enabled

  def analyze_resume      = enqueue!("analyze_resume")
  def recommend           = enqueue!("recommend")

  def generate_assignment
    enqueue!("generate_assignment", brief: brief_params)
  end

  def offer_letter
    enqueue!("offer_letter",
             salary:     params[:salary].presence,
             start_date: params[:start_date].presence,
             benefits:   params[:benefits].presence,
             manager:    params[:manager].presence)
  end

  private

  def set_applicant
    @applicant = JobApplicant.kept.find(params[:id])
  end

  def setting
    @setting ||= AppSetting.fetch(company: Company.kept.first, category: "ai")
  end

  def ai
    @ai ||= RecruitmentAi.new(setting: setting)
  end

  def ensure_ai_enabled
    return if ai.enabled?

    redirect_to job_applicant_path(@applicant),
                alert: t("ai.disabled", default: "AI отключён или не настроен. Включите в Настройки → AI.")
  end

  # Постановка задачи в очередь + скелетон в UI.
  # Если задача по этому кандидату уже выполняется — не запускаем дубль,
  # просто возвращаем актуальный скелетон/disabled-кнопки.
  def enqueue!(kind, brief: nil, **extra)
    scope = AiLock.for_applicant(@applicant)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: kind)
      RunAiTaskJob.perform_later(
        kind:         kind,
        applicant_id: @applicant.id,
        user_id:      current_user.id,
        brief:        brief,
        lock_scope:   scope,
        **extra
      )
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "ai-loading-#{@applicant.id}",
            partial: "ai/applicants/skeleton",
            locals:  { applicant: @applicant, kind: AiLock.kind_for(scope) || kind }
          ),
          turbo_stream.replace(
            "ai-controls-applicant-#{@applicant.id}",
            partial: "ai/applicants/controls",
            locals:  { applicant: @applicant }
          )
        ]
      end
      format.html { redirect_to job_applicant_path(@applicant, anchor: "ai") }
    end
  end

  # Brief-параметры для AI: difficulty/hours/deadline/payment/focus/delivery.
  def brief_params
    raw = params[:brief].respond_to?(:permit) ? params[:brief].permit(:difficulty, :hours, :deadline_days, :paid, :payment_amount, :focus, :delivery).to_h : {}
    {
      "difficulty"     => raw["difficulty"].presence,
      "hours"          => raw["hours"].to_i.positive?         ? raw["hours"].to_i : nil,
      "deadline_days"  => raw["deadline_days"].to_i.positive? ? raw["deadline_days"].to_i : nil,
      "paid"           => raw["paid"] == "1",
      "payment_amount" => raw["payment_amount"].to_i.positive? ? raw["payment_amount"].to_i : nil,
      "focus"          => raw["focus"].presence,
      "delivery"       => raw["delivery"].presence
    }.compact
  end
end
