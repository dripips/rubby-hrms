class Ai::RoundsController < ApplicationController
  before_action :set_round
  before_action :ensure_ai_enabled

  def questions = enqueue_round!("questions_for", target: "ai-questions-#{@round.id}")
  def summarize = enqueue_round!("summarize_interview", target: "ai-summary-#{@round.id}")

  private

  def set_round
    @round = InterviewRound.kept.find(params[:id])
  end

  def setting
    @setting ||= AppSetting.fetch(company: current_company, category: "ai")
  end

  def ai
    @ai ||= RecruitmentAi.new(setting: setting)
  end

  def ensure_ai_enabled
    return if ai.enabled?

    redirect_to job_applicant_path(@round.job_applicant_id),
                alert: t("ai.disabled", default: "AI отключён или не настроен.")
  end

  def enqueue_round!(kind, target:)
    scope = AiLock.for_round(@round)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: kind)
      RunAiTaskJob.perform_later(
        kind:       kind,
        round_id:   @round.id,
        user_id:    current_user.id,
        lock_scope: scope
      )
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            target,
            partial: "ai/rounds/skeleton",
            locals:  { round: @round, kind: AiLock.kind_for(scope) || kind }
          ),
          turbo_stream.replace(
            "ai-controls-round-#{@round.id}",
            partial: "ai/rounds/controls",
            locals:  { round: @round }
          )
        ]
      end
      format.html { redirect_to job_applicant_path(@round.job_applicant_id, anchor: "interviews") }
    end
  end
end
