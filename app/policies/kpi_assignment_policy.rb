class KpiAssignmentPolicy < ApplicationPolicy
  def index?    = user.role_superadmin? || user.role_hr? || user.role_manager?
  def show?     = index?
  def create?   = index?
  def new?      = create?
  def update?   = manageable?
  def edit?     = update?
  def destroy?  = manageable?

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.all if user.role_superadmin? || user.role_hr?

      report_ids = user.employee&.reports&.pluck(:id) || []
      report_ids << user.employee.id if user.employee
      scope.where(employee_id: report_ids.compact.uniq)
    end
  end

  private

  def manageable?
    return true if user.role_superadmin? || user.role_hr?
    return false unless user.role_manager? && user.employee

    user.employee.reports.pluck(:id).include?(record.employee_id)
  end
end
