class InterviewRoundPolicy < ApplicationPolicy
  def index?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end

  def create?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end

  def update?
    create? || record.interviewer_id == user.id
  end

  def transition?
    update?
  end

  alias_method :start?,    :transition?
  alias_method :complete?, :transition?
  alias_method :cancel?,   :transition?
  alias_method :no_show?,  :transition?
  alias_method :reopen?,   :transition?

  def destroy?
    user.role_superadmin? || user.role_hr? || record.created_by_id == user.id
  end
end
