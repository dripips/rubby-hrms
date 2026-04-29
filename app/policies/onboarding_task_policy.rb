class OnboardingTaskPolicy < ApplicationPolicy
  def update?  = hr_or_higher? || assignee? || mentor? || own_employee?
  def destroy? = hr_or_higher?

  private

  def hr_or_higher? = user&.role_superadmin? || user&.role_hr?
  def assignee?     = user && record.assignee_id == user.id

  def mentor?
    user&.employee && record.onboarding_process.mentor_id == user.employee.id
  end

  def own_employee?
    user&.employee && record.onboarding_process.employee_id == user.employee.id
  end
end
