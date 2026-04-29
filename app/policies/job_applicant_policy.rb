class JobApplicantPolicy < ApplicationPolicy
  def index?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end

  def show?    = index?
  def new?     = create?
  def edit?    = update?
  def create?  = user.role_superadmin? || user.role_hr?
  def update?  = user.role_superadmin? || user.role_hr? || (user.role_manager? && record.owner_id == user.id)
  def destroy? = user.role_superadmin? || user.role_hr?
  def move_stage? = update?

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.kept if user.role_superadmin? || user.role_hr?

      scope.kept.where("owner_id = ?", user.id)
    end
  end
end
