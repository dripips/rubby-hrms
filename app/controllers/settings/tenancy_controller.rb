# /settings/tenancy — управление subdomain'ом текущей компании.
# Только superadmin может менять (потенциально ломает sign-in флоу).
class Settings::TenancyController < SettingsController
  before_action :require_superadmin!

  def update
    company = current_company
    raw = params.require(:company).permit(:subdomain)
    subdomain = raw[:subdomain].to_s.downcase.strip
    subdomain = nil if subdomain.empty?

    if subdomain && !subdomain.match?(/\A[a-z0-9-]{1,50}\z/)
      redirect_to settings_communications_path,
                  alert: t("settings.tenancy.invalid", default: "Subdomain: только a-z, 0-9, дефис (макс 50 символов).")
      return
    end

    if company.update(subdomain: subdomain)
      redirect_to settings_communications_path,
                  notice: t("settings.tenancy.updated", default: "Subdomain обновлён")
    else
      redirect_to settings_communications_path,
                  alert: company.errors.full_messages.to_sentence
    end
  end

  private

  def require_superadmin!
    return if current_user&.role_superadmin?
    redirect_to settings_communications_path,
                alert: t("pundit.not_authorized", default: "Доступ запрещён")
  end
end
