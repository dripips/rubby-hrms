class LeaveRequestPolicy < ApplicationPolicy
  def index?  = true
  def show?   = own? || team_lead? || hr_or_higher?
  def new?    = true
  def create? = true
  def destroy? = own_draft? || hr_or_higher?

  def submit?          = own?
  def cancel?          = own? || hr_or_higher?
  def approve?         = dynamic_approver? || hr_or_higher?
  def approve_manager? = direct_manager? || hr_or_higher? || dynamic_approver?
  def approve_hr?      = hr_or_higher? || dynamic_approver?
  def reject?          = direct_manager? || hr_or_higher? || dynamic_approver?
  def force_approve?   = user.role_superadmin?  # add :general_director here when role exists
  def quick_create?    = hr_or_higher? || direct_manager?
  def start?           = hr_or_higher?
  def complete?        = hr_or_higher?

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.kept if user.role_superadmin? || user.role_hr?

      emp = user.employee
      return scope.none unless emp

      report_ids = emp.reports.pluck(:id)
      scope.kept.where(employee_id: ([emp.id] + report_ids))
    end
  end

  private

  def own?
    user.employee.present? && record.employee_id == user.employee.id
  end

  def own_draft?
    own? && record.state.to_s == "draft"
  end

  def direct_manager?
    return false unless user.role_manager? && user.employee
    user.employee.reports.where(id: record.employee_id).exists?
  end

  def team_lead?
    direct_manager?
  end

  def hr_or_higher?
    user.role_superadmin? || user.role_hr?
  end

  # Allow approvals when the engine's currently-pending step explicitly lists
  # the current user. Lets configurable rules grant approval rights to any
  # role/specific user (CEO, department head, etc.) without hard-coding here.
  def dynamic_approver?
    return false unless record.persisted?
    step = LeaveApprovalEngine.new(record).next_step
    step.present? && step.involves_user?(user)
  end
end
