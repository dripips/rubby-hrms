class Ai::LeavesController < ApplicationController
  before_action :ensure_ai_enabled
  before_action :ensure_hr

  # POST /ai/employees/:id/burnout_brief
  def burnout_brief
    @employee = Employee.kept.find(params[:id])
    enqueue_employee_task("burnout_brief", system_tag: params[:system_tag])
    render_skeleton(@employee, "burnout_brief")
  end

  # POST /ai/employees/:id/suggest_leave_window
  def suggest_leave_window
    @employee  = Employee.kept.find(params[:id])
    leave_type = LeaveType.find_by(id: params[:leave_type_id]) || LeaveType.active.first
    days       = [ params[:days_needed].to_i, 1 ].max

    enqueue_employee_task(
      "suggest_leave_window",
      leave_type_id: leave_type&.id,
      days_needed:   days
    )
    render_skeleton(@employee, "suggest_leave_window")
  end

  # POST /ai/employees/:id/kpi_brief — performance brief for a manager.
  def kpi_brief
    @employee = Employee.kept.find(params[:id])
    enqueue_employee_task("kpi_brief")
    render_skeleton(@employee, "kpi_brief")
  end

  # POST /ai/employees/:id/meeting_agenda — 1:1 prep agenda.
  def meeting_agenda
    @employee = Employee.kept.find(params[:id])
    enqueue_employee_task("meeting_agenda")
    render_skeleton(@employee, "meeting_agenda")
  end

  # POST /ai/employees/:id/compensation_review
  def compensation_review
    @employee = Employee.kept.find(params[:id])
    enqueue_employee_task("compensation_review")
    render_skeleton(@employee, "compensation_review")
  end

  # POST /ai/employees/:id/exit_risk_brief
  def exit_risk_brief
    @employee = Employee.kept.find(params[:id])
    enqueue_employee_task("exit_risk_brief")
    render_skeleton(@employee, "exit_risk_brief")
  end

  # POST /ai/leaves/bulk_burnout_brief — runs burnout brief on a list of employees.
  # Каждый запуск независимо лочится по своему employee — если у кого-то
  # уже идёт AI-задача, мы её не дублируем.
  def bulk_burnout_brief
    ids = Array(params[:employee_ids]).map(&:to_i).reject(&:zero?)
    employees = Employee.kept.where(id: ids).to_a
    employees.each do |emp|
      scope = AiLock.for_employee(emp)
      next if AiLock.running?(scope)

      AiLock.lock!(scope, kind: "burnout_brief")
      RunAiTaskJob.perform_later(
        kind:        "burnout_brief",
        employee_id: emp.id,
        system_tag:  params[:system_tag].presence,
        user_id:     current_user.id,
        lock_scope:  scope
      )
      AiLock.broadcast_controls(scope)
    end

    analytics    = LeaveAnalytics.new(company: current_company)
    burnout_rows = analytics.burnout_at_risk(limit: 100).index_by { |r| r[:employee].id }

    streams = employees.map do |emp|
      row = burnout_rows[emp.id] || { employee: emp, reason: :both, days_since_leave: nil, avg_kpi: nil }
      turbo_stream.replace(
        "burnout-row-#{emp.id}",
        partial: "leave_requests/burnout_row",
        locals:  { row: row, pending: true }
      )
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
      format.html         { redirect_back fallback_location: leave_requests_path(view: "all") }
    end
  end

  private

  # Общая логика lock-aware enqueue: если по сотруднику уже идёт AI-задача —
  # тихо игнорируем, скелетон всё равно вернётся (он отражает текущий kind).
  def enqueue_employee_task(kind, **extra)
    scope = AiLock.for_employee(@employee)
    return if AiLock.running?(scope)

    AiLock.lock!(scope, kind: kind)
    RunAiTaskJob.perform_later(
      kind:        kind,
      employee_id: @employee.id,
      user_id:     current_user.id,
      lock_scope:  scope,
      **extra
    )
    AiLock.broadcast_controls(scope)
  end

  def render_skeleton(employee, kind)
    scope         = AiLock.for_employee(employee)
    effective_kind = AiLock.kind_for(scope) || kind

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "ai-leaves-panel-#{employee.id}",
            partial: "ai/leaves/skeleton",
            locals:  { employee: employee, kind: effective_kind }
          ),
          turbo_stream.replace(
            "ai-controls-employee-#{employee.id}",
            partial: "ai/leaves/controls",
            locals:  { employee: employee }
          )
        ]
      end
      format.html { redirect_to employee_path(employee, anchor: "ai") }
    end
  end

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

  def ensure_hr
    return if current_user.role_superadmin? || current_user.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end
end
