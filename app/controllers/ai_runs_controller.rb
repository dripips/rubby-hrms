# Аудит-лог AI-задач: кто, когда, что запускал, сколько стоило, успешно ли.
# В отличие от /audit (paper_trail на изменения моделей), этот — про выполнения
# AI-задач. HR/admin only.
class AiRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr

  PER_PAGE = 30

  def index
    @scope = AiRun.where.not(kind: "ping").includes(:user, :document, :dictionary,
                                                     :job_applicant, :employee, :onboarding_process,
                                                     :offboarding_process, :job_opening)

    @scope = @scope.where(kind: params[:kind])                          if params[:kind].present?
    @scope = @scope.where(model: params[:model])                        if params[:model].present?
    @scope = @scope.where(user_id: params[:user_id])                    if params[:user_id].present?
    @scope = @scope.where(success: params[:success] == "true")          if params[:success].present?
    @scope = @scope.where(employee_id: params[:employee_id])            if params[:employee_id].present?
    @scope = @scope.where(document_id: params[:document_id])            if params[:document_id].present?
    @scope = @scope.where(dictionary_id: params[:dictionary_id])        if params[:dictionary_id].present?
    @scope = filter_by_period(@scope, params[:period])                  if params[:period].present?

    @kinds_used  = AiRun.where.not(kind: "ping").distinct.pluck(:kind).sort
    @models_used = AiRun.where.not(kind: "ping").distinct.pluck(:model).compact.sort
    @users_used  = User.where(id: AiRun.where.not(kind: "ping").distinct.pluck(:user_id)).order(:email)

    @total       = @scope.count
    @page        = (params[:page] || 1).to_i.clamp(1, 100_000)
    @runs        = @scope.recent.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

    # Aggregates для текущего фильтра — чтобы показать "вы выбрали 14 запусков на $0.012"
    @sum_cost    = @scope.sum(:cost_usd).to_f
    @sum_tokens  = @scope.sum(:total_tokens).to_i
    @success_pct = @total.zero? ? 0 : (@scope.where(success: true).count * 100.0 / @total).round
  end

  def show
    @run = AiRun.find(params[:id])
  end

  private

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def filter_by_period(scope, period)
    case period.to_s
    when "1d"  then scope.where("created_at >= ?", 1.day.ago)
    when "7d"  then scope.where("created_at >= ?", 7.days.ago)
    when "30d" then scope.where("created_at >= ?", 30.days.ago)
    when "90d" then scope.where("created_at >= ?", 90.days.ago)
    else            scope
    end
  end
end
