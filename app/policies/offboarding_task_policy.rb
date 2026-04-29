class OffboardingTaskPolicy < ApplicationPolicy
  def update?  = hr_or_higher? || assignee? || direct_manager?
  def destroy? = hr_or_higher?

  private

  def hr_or_higher? = user&.role_superadmin? || user&.role_hr?
  def assignee?     = user && record.assignee_id == user.id

  def direct_manager?
    user&.employee && record.offboarding_process.employee&.manager_id == user.employee.id
  end
end
