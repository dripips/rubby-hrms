class Ai::OpeningsController < ApplicationController
  before_action :set_opening
  before_action :ensure_ai_enabled

  def compare
    applicant_ids = Array(params[:applicant_ids]).map(&:to_i).reject(&:zero?)
    if applicant_ids.size < 2
      return redirect_to(job_opening_path(@opening), alert: t("ai.compare.too_few"))
    end

    scope = AiLock.for_opening(@opening)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: "compare_candidates")
      RunAiTaskJob.perform_later(
        kind:           "compare_candidates",
        opening_id:     @opening.id,
        applicant_ids:  applicant_ids,
        user_id:        current_user.id,
        lock_scope:     scope
      )
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "ai-compare-loading-#{@opening.id}",
            partial: "ai/openings/skeleton",
            locals:  { opening: @opening }
          ),
          turbo_stream.replace(
            "ai-controls-opening-#{@opening.id}",
            partial: "ai/openings/controls",
            locals:  { opening: @opening }
          )
        ]
      end
      format.html { redirect_to job_opening_path(@opening) }
    end
  end

  private

  def set_opening
    @opening = JobOpening.kept.find(params[:id])
  end

  def setting
    @setting ||= AppSetting.fetch(company: Company.kept.first, category: "ai")
  end

  def ai
    @ai ||= RecruitmentAi.new(setting: setting)
  end

  def ensure_ai_enabled
    return if ai.enabled?

    redirect_to job_opening_path(@opening), alert: t("ai.disabled")
  end
end
