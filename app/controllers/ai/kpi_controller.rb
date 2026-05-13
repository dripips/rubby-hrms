class Ai::KpiController < ApplicationController
  before_action :ensure_ai_enabled
  before_action :ensure_hr_or_manager

  # POST /ai/kpi/team_brief
  # Params: scope_type=company|department|manager_reports, scope_id=optional
  def team_brief
    scope_type = params[:scope_type].presence || "company"
    scope_id   = params[:scope_id].presence
    lock_scope = AiLock.for_kpi_team(scope_type: scope_type, scope_id: scope_id)

    unless AiLock.running?(lock_scope)
      AiLock.lock!(lock_scope, kind: "kpi_team_brief")
      RunAiTaskJob.perform_later(
        kind:       "kpi_team_brief",
        user_id:    current_user.id,
        scope_type: scope_type,
        scope_id:   scope_id,
        lock_scope: lock_scope
      )
      AiLock.broadcast_controls(lock_scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "ai-kpi-team-panel",
            partial: "ai/kpi/skeleton",
            locals:  { scope_type: scope_type }
          ),
          turbo_stream.replace(
            "ai-controls-kpi-team",
            partial: "ai/kpi/controls",
            locals:  { scope_type: scope_type, scope_id: scope_id }
          )
        ]
      end
      format.html { redirect_to kpi_dashboard_path, anchor: "ai" }
    end
  end

  private

  def setting
    @setting ||= AppSetting.fetch(company: current_company, category: "ai")
  end

  def ai
    @ai ||= RecruitmentAi.new(setting: setting)
  end

  def ensure_ai_enabled
    return if ai.enabled?
    redirect_to root_path, alert: t("ai.disabled")
  end

  def ensure_hr_or_manager
    return if current_user.role_superadmin? || current_user.role_hr? || current_user.role_manager?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end
end
