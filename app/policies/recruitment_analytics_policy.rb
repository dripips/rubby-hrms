class RecruitmentAnalyticsPolicy < Struct.new(:user, :record)
  def index?
    user.role_superadmin? || user.role_hr? || user.role_manager?
  end
end
