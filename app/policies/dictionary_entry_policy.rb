class DictionaryEntryPolicy < ApplicationPolicy
  def create?  = hr_or_higher?
  def update?  = hr_or_higher?
  def destroy? = hr_or_higher?

  private

  def hr_or_higher? = user&.role_superadmin? || user&.role_hr?
end
