class TestAssignmentPolicy < ApplicationPolicy
  def create?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end

  def update?
    create?
  end

  def destroy?
    user.role_superadmin? || user.role_hr? || record.created_by_id == user.id
  end
end
