module PaperTrail
  class VersionPolicy < ApplicationPolicy
    def index?  = user.role_superadmin? || user.role_hr?
    def show?   = index?
    def update? = user.role_superadmin?
    def revert? = update?

    class Scope < Scope
      def resolve
        return scope.none unless user
        return scope.all if user.role_superadmin? || user.role_hr?
        scope.none
      end
    end
  end
end
