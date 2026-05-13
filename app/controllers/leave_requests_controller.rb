class LeaveRequestsController < ApplicationController
  include TabulatorFilterable

  before_action :set_company
  before_action :set_request, only: %i[show destroy submit approve approve_manager approve_hr force_approve start complete reject cancel]
  before_action :load_form_data, only: %i[index new]

  def index
    load_form_data
    @view = (params[:view].presence || default_view).to_s

    @my_employee = current_employee
    @my_quota    = @my_employee ? EmployeeLeaveQuota.new(employee: @my_employee).rows : []
    @my_requests = @my_employee ? LeaveRequest.kept.where(employee: @my_employee).order(applied_at: :desc, created_at: :desc).limit(30) : []

    if @view == "all" && (current_user.role_hr? || current_user.role_superadmin?)
      @analytics = LeaveAnalytics.new(company: @company)
    end

    if current_user.role_manager? || current_user.role_hr? || current_user.role_superadmin?
      report_ids = @my_employee&.reports&.pluck(:id) || []
      visible_ids = if current_user.role_hr? || current_user.role_superadmin?
                      Employee.kept.where(company: @company).pluck(:id)
      else
                      report_ids
      end
      @team_pending = LeaveRequest.kept.includes(:employee, :leave_type)
                                    .where(employee_id: visible_ids)
                                    .where(state: %w[submitted manager_approved])
                                    .order(applied_at: :asc).limit(30)
      @team_on_leave = LeaveRequest.kept.includes(:employee, :leave_type)
                                    .where(employee_id: visible_ids)
                                    .where(state: %w[hr_approved active])
                                    .where("started_on <= ? AND ended_on >= ?", Date.current + 14.days, Date.current)
                                    .order(:started_on).limit(30)
    end

    respond_to do |format|
      format.html
      format.json { render json: tabulator_payload }
    end
  end

  def show
    @approvals = @leave_request.leave_approvals.includes(:approver).order(:step)
  end

  def new
    @leave_request = LeaveRequest.new(employee: current_employee, started_on: Date.current, ended_on: Date.current + 7.days)
  end

  def create
    @leave_request = LeaveRequest.new(leave_request_params)
    @leave_request.employee ||= current_employee
    @leave_request.days = (@leave_request.ended_on - @leave_request.started_on + 1).to_i if @leave_request.started_on && @leave_request.ended_on
    apply_custom_fields(@leave_request, params[:custom_fields])

    if @leave_request.save
      @leave_request.submit! if params[:submit]
      redirect_to leave_request_path(@leave_request), notice: t("leaves.created", default: "Заявка создана")
    else
      load_form_data
      redirect_to leave_requests_path, alert: @leave_request.errors.full_messages.to_sentence
    end
  end

  def apply_custom_fields(leave_request, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    leave_request.custom_fields = (leave_request.custom_fields.to_h || {}).merge(cleaned)
  end

  def destroy
    @leave_request.discard
    redirect_to leave_requests_path, notice: t("leaves.deleted", default: "Заявка удалена")
  end

  # Returns quota + history panel for a given employee. Used by the leave-form
  # to live-update the right rail when HR/manager changes the employee select.
  def employee_panel
    employee = Employee.kept.where(company: @company).find_by(id: params[:employee_id])
    if employee.nil?
      head :not_found and return
    end

    @panel_employee = employee
    @panel_quota    = EmployeeLeaveQuota.new(employee: employee).rows
    @panel_history  = LeaveRequest.kept.where(employee: employee)
                                    .includes(:leave_type)
                                    .order(applied_at: :desc, created_at: :desc)
                                    .limit(8)
    render partial: "leave_requests/employee_panel",
           locals:  { employee: @panel_employee, quota: @panel_quota, history: @panel_history }
  end

  # One-click leave creation by HR / superadmin / manager-of-reports.
  # Skips the whole approval chain: created already in :hr_approved state
  # with both manager + hr approval rows logged against the acting user.
  def quick_create
    @leave_request = LeaveRequest.new(quick_params)
    @leave_request.days = (@leave_request.ended_on - @leave_request.started_on + 1).to_i if @leave_request.started_on && @leave_request.ended_on
    @leave_request.applied_at = Time.current

    authorize @leave_request, :quick_create?

    if @leave_request.save
      @leave_request.update_column(:state, "hr_approved")
      @leave_request.leave_approvals.create!(approver: current_user, step: :manager, decision: :approved, comment: t("leaves.quick.auto_approval"), decided_at: Time.current)
      @leave_request.leave_approvals.create!(approver: current_user, step: :hr,      decision: :approved, comment: t("leaves.quick.auto_approval"), decided_at: Time.current)
      redirect_back fallback_location: leave_request_path(@leave_request), notice: t("leaves.quick.created")
    else
      redirect_back fallback_location: leave_requests_path, alert: @leave_request.errors.full_messages.to_sentence
    end
  end

  # ── Workflow actions ──────────────────────────────────────────────────────
  def submit
    authorize @leave_request, :submit?
    workflow!(:submit, :submitted)
  end

  def approve_manager
    authorize @leave_request, :approve_manager?
    workflow!(:approve_by_manager, :manager_approved, log_step: :manager)
  end

  def approve_hr
    authorize @leave_request, :approve_hr?
    workflow!(:approve_by_hr, :hr_approved, log_step: :hr)
  end

  # Universal "Approve" action — figures out which step the current user is
  # approving based on the engine's chain and the count of existing approvals.
  # Records the approval, then either advances to the next intermediate state
  # or finalizes (state=hr_approved) when the whole chain is satisfied.
  def approve
    authorize @leave_request, :approve?

    engine = LeaveApprovalEngine.new(@leave_request)
    result = engine.call
    steps  = result[:steps]

    approved_count = @leave_request.leave_approvals.where(decision: :approved).count
    current_step   = steps[approved_count]

    if current_step.nil?
      redirect_to leave_request_path(@leave_request), alert: t("leaves.no_next_step") and return
    end

    unless current_step.involves_user?(current_user)
      redirect_to leave_request_path(@leave_request), alert: t("leaves.not_your_step") and return
    end

    @leave_request.leave_approvals.create!(
      approver:   current_user,
      step:       step_kind(current_step),
      decision:   :approved,
      comment:    params[:comment],
      decided_at: Time.current
    )

    new_count = approved_count + 1
    if new_count >= steps.size
      @leave_request.update_column(:state, "hr_approved")
      redirect_to leave_request_path(@leave_request), notice: t("leaves.transitions.hr_approved")
    else
      # First approve from `submitted` flips visual to "manager_approved"
      # so the existing AASM transitions for activate/complete still work.
      if @leave_request.state == "submitted"
        @leave_request.update_column(:state, "manager_approved")
      end
      redirect_to leave_request_path(@leave_request), notice: t("leaves.approved_step", n: new_count, total: steps.size)
    end
  end

  def force_approve
    authorize @leave_request, :force_approve?
    if @leave_request.state == "submitted"
      @leave_request.leave_approvals.create!(approver: current_user, step: :manager, decision: :approved, comment: params[:comment], decided_at: Time.current)
    end
    @leave_request.leave_approvals.create!(approver: current_user, step: :hr, decision: :approved, comment: params[:comment], decided_at: Time.current)
    workflow!(:force_approve, :hr_approved)
  end

  def start
    authorize @leave_request, :start?
    workflow!(:start, :started)
  end

  def complete
    authorize @leave_request, :complete?
    workflow!(:complete, :completed)
  end

  def reject
    authorize @leave_request, :reject?
    @leave_request.leave_approvals.create!(approver: current_user, step: :hr, decision: :rejected, comment: params[:comment], decided_at: Time.current) if params[:comment].present?
    workflow!(:reject, :rejected)
  end

  def cancel
    authorize @leave_request, :cancel?
    workflow!(:cancel, :cancelled)
  end

  private

  def set_company
    @company = current_company
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end

  def set_request
    @leave_request = LeaveRequest.kept.includes(:employee, :leave_type).find(params[:id])
  end

  def load_form_data
    @leave_types = LeaveType.active.where(company: @company)
    @employees   = Employee.kept.where(company: @company).order(:last_name).limit(200)
    @departments = Department.kept.where(company: @company).order(:name)
  end

  def current_employee
    current_user.employee || Employee.kept.where(company: @company).find_by(user: current_user)
  end

  def default_view
    return "all" if current_user.role_hr? || current_user.role_superadmin?
    return "team" if current_user.role_manager? && current_employee&.reports&.any?
    "me"
  end

  def leave_request_params
    params.require(:leave_request).permit(:employee_id, :leave_type_id, :started_on, :ended_on, :reason)
  end

  def quick_params
    params.require(:leave_request).permit(:employee_id, :leave_type_id, :started_on, :ended_on, :reason)
  end

  # Map an engine step into a value safe for LeaveApproval.step enum.
  # The current `leave_approvals.step` column accepts manager/hr — for
  # other roles or specific users we fall back to "hr" so persistence works
  # while the audit trail still shows who approved.
  def step_kind(step)
    return step.value.to_s if step.role? && %w[manager hr].include?(step.value.to_s)
    "hr"
  end

  def workflow!(event, target_state, log_step: nil)
    @leave_request.public_send("#{event}!")

    if log_step
      @leave_request.leave_approvals.create!(
        approver:   current_user,
        step:       log_step,
        decision:   :approved,
        comment:    params[:comment],
        decided_at: Time.current
      )
    end

    redirect_to leave_request_path(@leave_request), notice: t("leaves.transitions.#{target_state}", default: "Статус обновлён")
  rescue AASM::InvalidTransition => e
    redirect_to leave_request_path(@leave_request), alert: e.message
  end

  # ── Tabulator JSON ────────────────────────────────────────────────────────
  def tabulator_payload
    scope = visible_scope
              .left_joins(employee: %i[department position])
              .left_joins(:leave_type)
              .includes(:employee, :leave_type)

    grid_array(params[:filter]).each do |f|
      field = f["field"].to_s
      value = f["value"].to_s.strip
      next if value.empty?

      like = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
      case field
      when "state", "state_label"
        scope = scope.where(leave_requests: { state: value })
      when "employee_name"
        scope = scope.where("employees.last_name ILIKE :v OR employees.first_name ILIKE :v", v: like)
      when "department"
        scope = value.match?(/\A\d+\z/) ? scope.where(employees: { department_id: value }) : scope.where("departments.name ILIKE ?", like)
      when "leave_type"
        scope = value.match?(/\A\d+\z/) ? scope.where(leave_requests: { leave_type_id: value }) : scope.where("leave_types.name ILIKE ?", like)
      when "days"
        scope = apply_numeric_compare(scope, "leave_requests.days", value)
      end
    end

    if (sorts = params[:sort])
      sorts = sorts.respond_to?(:values) ? sorts.values : sorts
      sorts.each do |s|
        s = s.permit!.to_h if s.respond_to?(:permit!)
        dir = s["dir"] == "desc" ? "desc" : "asc"
        clause = case s["field"]
        when "started_on"    then "leave_requests.started_on #{dir}"
        when "days"          then "leave_requests.days #{dir}"
        when "state"         then "leave_requests.state #{dir}"
        when "employee_name" then "employees.last_name #{dir}, employees.first_name #{dir}"
        when "leave_type"    then "leave_types.name #{dir}"
        end
        scope = scope.order(Arel.sql(clause)) if clause
      end
    else
      scope = scope.order(applied_at: :desc, created_at: :desc)
    end

    page = (params[:page] || 1).to_i.clamp(1, 100_000)
    size = (params[:size] || 50).to_i.clamp(1, 500)
    total = scope.count
    pages = [ (total.to_f / size).ceil, 1 ].max
    rows  = scope.offset((page - 1) * size).limit(size)

    {
      last_page: pages,
      data: rows.map { |r| leave_json(r) }
    }
  end

  def visible_scope
    base = LeaveRequest.kept

    return base if current_user.role_superadmin? || current_user.role_hr?

    return base if current_user.role_manager? && current_employee&.reports&.any?

    base.where(employee_id: current_employee&.id)
  end

  def leave_json(req)
    emp = req.employee
    {
      id:             req.id,
      employee_name:  emp&.full_name,
      employee_initials: emp&.initials,
      department:     emp&.department&.name,
      leave_type:     req.leave_type&.name,
      leave_type_color: req.leave_type&.color,
      started_on:     req.started_on&.strftime("%d.%m.%Y"),
      ended_on:       req.ended_on&.strftime("%d.%m.%Y"),
      days:           req.days.to_f,
      state:          req.state,
      state_label:    I18n.t("leaves.states.#{req.state}", default: req.state.humanize),
      applied_at:     req.applied_at&.strftime("%d.%m.%Y %H:%M")
    }
  end
end
