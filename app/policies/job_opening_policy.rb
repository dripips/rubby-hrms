class JobOpeningPolicy < ApplicationPolicy
  def index?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end

  def show?
    index?
  end

  def create?
    user.role_superadmin? || user.role_hr?
  end

  def new?     = create?
  def update?  = create?
  def destroy? = user.role_superadmin? || user.role_hr?

  def open?    = update?
  def close?   = update?
  def hold?    = update?

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.kept if user.role_superadmin? || user.role_hr?

      scope.kept.where("owner_id = ?", user.id)
    end
  end
end
