# 2FA setup-flow для уже залогиненного юзера.
#
# show       → пользователь зашёл на страницу 2FA.
#              Если 2FA выключен → показать QR + поле для verify-кода (setup).
#              Если включён       → показать статус, backup-codes count, disable-form.
# create     → user ввёл TOTP-код после сканирования QR. Если совпало —
#              включаем 2FA, генерим 10 backup-кодов, показываем их 1 раз.
# destroy    → выключить 2FA. Требует TOTP-кода (анти-phishing).
# regenerate → пересоздать backup-коды (требует пароль).
class TwoFactorAuthsController < ApplicationController
  before_action :authenticate_user!

  def show
    if current_user.two_factor_enabled?
      @remaining_backup_codes = current_user.remaining_backup_codes_count
      @recently_generated_codes = flash[:backup_codes]
    else
      current_user.regenerate_otp_secret! if current_user.otp_secret.blank?
      @qr_svg = build_qr_svg(current_user.otp_provisioning_uri)
    end
  end

  def create
    code = params[:otp_code].to_s
    unless current_user.verify_totp(code)
      current_user.regenerate_otp_secret! if current_user.otp_secret.blank?
      @qr_svg = build_qr_svg(current_user.otp_provisioning_uri)
      flash.now[:alert] = t("profile.two_factor.invalid_code", default: "Неверный код. Попробуй ещё раз.")
      render :show, status: :unprocessable_entity
      return
    end

    backup_codes = current_user.enable_two_factor!
    flash[:backup_codes] = backup_codes
    redirect_to two_factor_profile_path,
                notice: t("profile.two_factor.enabled", default: "2FA включена. Сохрани backup-коды!")
  end

  def destroy
    code = params[:otp_code].to_s
    unless current_user.verify_totp(code) || current_user.consume_backup_code!(code)
      redirect_to two_factor_profile_path,
                  alert: t("profile.two_factor.invalid_code", default: "Неверный код.")
      return
    end

    current_user.disable_two_factor!
    redirect_to security_profile_path,
                notice: t("profile.two_factor.disabled", default: "2FA выключена.")
  end

  def regenerate
    code = params[:otp_code].to_s
    unless current_user.verify_totp(code)
      redirect_to two_factor_profile_path,
                  alert: t("profile.two_factor.invalid_code", default: "Неверный код.")
      return
    end

    new_codes = current_user.regenerate_backup_codes!
    flash[:backup_codes] = new_codes
    redirect_to two_factor_profile_path,
                notice: t("profile.two_factor.codes_regenerated", default: "Новые backup-коды выпущены.")
  end

  private

  def build_qr_svg(uri)
    return nil if uri.blank?
    qr = RQRCode::QRCode.new(uri, level: :m)
    qr.as_svg(
      offset: 0, color: "000",
      shape_rendering: "crispEdges",
      module_size: 5,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: { width: "240", height: "240", role: "img", "aria-label": "TOTP QR-code" }
    ).html_safe
  end
end
