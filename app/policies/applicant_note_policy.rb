class ApplicantNotePolicy < ApplicationPolicy
  def create?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end

  def destroy?
    user.role_superadmin? || record.author_id == user.id
  end
end
