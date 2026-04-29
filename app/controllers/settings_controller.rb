class SettingsController < ApplicationController
  before_action :ensure_admin

  layout "application"

  private

  def ensure_admin
    return if current_user&.role_superadmin? || current_user&.role_hr?

    flash[:alert] = t("pundit.not_authorized")
    redirect_to root_path
  end
end
