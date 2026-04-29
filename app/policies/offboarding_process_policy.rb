class OffboardingProcessPolicy < ApplicationPolicy
  def index?    = hr_or_manager?
  def show?     = hr_or_higher? || direct_manager?
  def create?   = hr_or_higher?
  def update?   = hr_or_higher?
  def destroy?  = hr_or_higher?
  def activate? = hr_or_higher?
  def complete? = hr_or_higher?
  def cancel?   = hr_or_higher?

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.kept if user.role_superadmin? || user.role_hr?

      emp = user.employee
      return scope.none unless emp

      ids = emp.reports.pluck(:id)
      scope.kept.where(employee_id: ids)
    end
  end

  private

  def hr_or_higher?  = user&.role_superadmin? || user&.role_hr?
  def hr_or_manager? = hr_or_higher? || user&.role_manager?

  def direct_manager?
    user&.employee && record.employee&.manager_id == user.employee.id
  end
end
