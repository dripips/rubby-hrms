class DictionaryPolicy < ApplicationPolicy
  def index?              = hr_or_higher?
  def show?               = hr_or_higher?
  def create?             = hr_or_higher?
  def update?             = hr_or_higher?
  def destroy?            = hr_or_higher?
  def suggest?            = hr_or_higher?
  def apply_suggestions?  = hr_or_higher?
  def bootstrap_message?  = hr_or_higher?
  def bootstrap_apply?    = hr_or_higher?
  def bootstrap_reset?    = hr_or_higher?

  class Scope < Scope
    def resolve
      hr_or_higher? ? scope.kept : scope.none
    end

    private

    def hr_or_higher? = user&.role_superadmin? || user&.role_hr?
  end

  private

  def hr_or_higher? = user&.role_superadmin? || user&.role_hr?
end
