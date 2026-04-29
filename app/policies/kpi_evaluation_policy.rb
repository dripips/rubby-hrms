class KpiEvaluationPolicy < ApplicationPolicy
  def index?  = user.role_superadmin? || user.role_hr? || user.role_manager?
  def create? = index?

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.all if user.role_superadmin? || user.role_hr?

      report_ids = user.employee&.reports&.pluck(:id) || []
      scope.joins(:kpi_assignment).where(kpi_assignments: { employee_id: report_ids })
    end
  end
end
