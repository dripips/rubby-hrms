class KpiMetricPolicy < ApplicationPolicy
  def index?    = user.role_superadmin? || user.role_hr? || user.role_manager?
  def show?     = index?
  def create?   = user.role_superadmin? || user.role_hr?
  def new?      = create?
  def update?   = create?
  def edit?     = update?
  def destroy?  = create?

  class Scope < Scope
    def resolve
      return scope.none unless user
      scope.kept
    end
  end
end
